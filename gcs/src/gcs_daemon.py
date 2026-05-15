"""
RAVEN GCS Daemon
Reconnaissance Autonomous Vehicle with Electronic iNtelligence
Ground Control Segment — Main Daemon Process

Architecture:
    - Async HTTP server (aiohttp) exposing REST API to HMI
    - MAVLink module: bidirectional telemetry with SITL/Pixhawk
    - SDR module: IQ stream ingestion from rtl_tcp on Pi
    - Config: loaded from gcs/config/config.json

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import asyncio
import json
import logging
import os
import signal
import sys
from datetime import datetime

from aiohttp import web

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S"
)
log = logging.getLogger("RAVEN.GCS")

# ── Config ────────────────────────────────────────────────────────────────────
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "../config/config.json")

def load_config():
    with open(CONFIG_PATH, "r") as f:
        return json.load(f)

# ── System State ──────────────────────────────────────────────────────────────
# Single shared state object — all modules read/write here
# HMI polls this via REST API
state = {
    "system": {
        "mode":         "STANDBY",   # STANDBY | PREFLIGHT | MISSION | RTL | FAULT
        "timestamp":    None,
        "uptime":       0,
    },
    "telemetry": {
        "connected":    False,
        "lat":          None,
        "lon":          None,
        "alt":          None,
        "heading":      None,
        "airspeed":     None,
        "groundspeed":  None,
        "battery_v":    None,
        "battery_pct":  None,
        "gps_fix":      None,
        "flight_mode":  None,
        "armed":        False,
        "heartbeat_age":None,        # seconds since last heartbeat
    },
    "mission": {
        "active":       False,
        "waypoint_count": 0,
        "current_wp":   None,
        "mission_time": None,
    },
    "sdr": {
        "connected":    False,
        "frequency":    None,
        "sample_rate":  None,
        "gain":         None,
        "spectrum":     [],          # latest FFT bins for HMI waterfall
    },
    "link": {
        "wifi_active":  False,
        "latency_ms":   None,
        "link_quality": None,
    },
    "alerts": []                     # list of {level, message, timestamp}
}

def push_alert(level: str, message: str):
    """Add an alert to the state. level: INFO | AMBER | RED"""
    state["alerts"].append({
        "level":     level,
        "message":   message,
        "timestamp": datetime.utcnow().isoformat()
    })
    # Keep last 50 alerts
    state["alerts"] = state["alerts"][-50:]
    log.warning(f"ALERT [{level}] {message}")

# ── REST API Handlers ─────────────────────────────────────────────────────────

async def handle_status(request):
    """GET /api/status — full system state"""
    return web.json_response(state)

async def handle_telemetry(request):
    """GET /api/telemetry — AVS telemetry only"""
    return web.json_response(state["telemetry"])

async def handle_mission(request):
    """GET /api/mission — mission state"""
    return web.json_response(state["mission"])

async def handle_sdr(request):
    """GET /api/sdr — SDR state and latest spectrum"""
    return web.json_response(state["sdr"])

async def handle_alerts(request):
    """GET /api/alerts — alert annunciator list"""
    return web.json_response(state["alerts"])

async def handle_abort(request):
    """POST /api/abort — trigger RTL on AVS"""
    log.warning("ABORT COMMAND RECEIVED — triggering RTL")
    state["system"]["mode"] = "RTL"
    push_alert("RED", "ABORT commanded by operator — RTL initiated")
    # MAVLink RTL command sent by mavlink_module (hooked in Phase 2)
    return web.json_response({"status": "RTL_COMMANDED"})

async def handle_arm(request):
    """POST /api/arm — arm the vehicle"""
    log.info("ARM command received")
    # MAVLink arm command sent by mavlink_module (hooked in Phase 2)
    return web.json_response({"status": "ARM_COMMANDED"})

async def handle_disarm(request):
    """POST /api/disarm — disarm the vehicle"""
    log.info("DISARM command received")
    return web.json_response({"status": "DISARM_COMMANDED"})

async def handle_upload_mission(request):
    """POST /api/mission/upload — upload waypoint list to AVS"""
    data = await request.json()
    waypoints = data.get("waypoints", [])
    log.info(f"Mission upload received: {len(waypoints)} waypoints")
    state["mission"]["waypoint_count"] = len(waypoints)
    # MAVLink waypoint upload sent by mavlink_module (hooked in Phase 2)
    return web.json_response({"status": "UPLOAD_RECEIVED", "waypoints": len(waypoints)})

async def handle_health(request):
    """GET /api/health — daemon health check"""
    return web.json_response({
        "status":    "OK",
        "timestamp": datetime.utcnow().isoformat(),
        "mode":      state["system"]["mode"]
    })

# ── Background Tasks ──────────────────────────────────────────────────────────

async def heartbeat_watchdog(config):
    """
    Monitor MAVLink heartbeat age.
    If no heartbeat received within threshold, push AMBER alert.
    Requirement: GCS-FT-FR-002 — detect link loss within 1 second.
    """
    threshold = config.get("mavlink", {}).get("heartbeat_timeout_s", 3)
    log.info(f"Heartbeat watchdog started — timeout: {threshold}s")
    while True:
        await asyncio.sleep(1)
        age = state["telemetry"]["heartbeat_age"]
        if age is not None and age > threshold:
            if state["telemetry"]["connected"]:
                state["telemetry"]["connected"] = False
                state["link"]["wifi_active"]    = False
                state["system"]["mode"]         = "FAULT"
                push_alert("RED", f"MAVLink link loss — no heartbeat for {age:.1f}s")
        elif age is not None and age <= threshold:
            if not state["telemetry"]["connected"]:
                state["telemetry"]["connected"] = True
                state["link"]["wifi_active"]    = True
                state["system"]["mode"]         = "STANDBY"
                push_alert("INFO", "MAVLink link restored")

async def system_clock(config):
    """Update system timestamp and uptime every second."""
    start = datetime.utcnow()
    while True:
        await asyncio.sleep(1)
        now = datetime.utcnow()
        state["system"]["timestamp"] = now.isoformat()
        state["system"]["uptime"]    = int((now - start).total_seconds())

# ── App Factory ───────────────────────────────────────────────────────────────

def build_app(config):
    app = web.Application()

    @web.middleware
    async def cors_middleware(request, handler):
        response = await handler(request)
        response.headers["Access-Control-Allow-Origin"]  = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type"
        return response

    app.middlewares.append(cors_middleware)

    # Routes
    app.router.add_get( "/api/health",          handle_health)
    app.router.add_get( "/api/status",          handle_status)
    app.router.add_get( "/api/telemetry",       handle_telemetry)
    app.router.add_get( "/api/mission",         handle_mission)
    app.router.add_get( "/api/sdr",             handle_sdr)
    app.router.add_get( "/api/alerts",          handle_alerts)
    app.router.add_post("/api/abort",           handle_abort)
    app.router.add_post("/api/arm",             handle_arm)
    app.router.add_post("/api/disarm",          handle_disarm)
    app.router.add_post("/api/mission/upload",  handle_upload_mission)

    # Static HMI files
    hmi_path = os.path.join(os.path.dirname(__file__), "../hmi")
    if os.path.exists(hmi_path):
        app.router.add_static("/", hmi_path, name="hmi")

    return app

# ── Main ──────────────────────────────────────────────────────────────────────

async def main():
    config = load_config()
    host   = config.get("server", {}).get("host", "0.0.0.0")
    port   = config.get("server", {}).get("port", 8080)

    log.info("=" * 60)
    log.info("RAVEN GCS Daemon — Starting")
    log.info(f"Server: {host}:{port}")
    log.info(f"MAVLink: {config.get('mavlink', {}).get('host')}:{config.get('mavlink', {}).get('port')}")
    log.info(f"SDR:     {config.get('sdr', {}).get('host')}:{config.get('sdr', {}).get('port')}")
    log.info("=" * 60)

    # Build app
    app = build_app(config)

    # Start background tasks
    asyncio.create_task(system_clock(config))
    asyncio.create_task(heartbeat_watchdog(config))

    # MAVLink and SDR modules imported and started in Phase 2
    # asyncio.create_task(mavlink_module.run(config, state))
    # asyncio.create_task(sdr_module.run(config, state))

    # Start server
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, host, port)
    await site.start()

    log.info(f"RAVEN GCS online at http://{host}:{port}")
    log.info("Awaiting HMI connection...")

    # Run forever
    try:
        await asyncio.Event().wait()
    except (KeyboardInterrupt, SystemExit):
        log.info("RAVEN GCS Daemon shutting down")
        await runner.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
