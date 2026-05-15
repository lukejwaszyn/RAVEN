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
import sys
sys.path.insert(0, os.path.dirname(__file__))
from datetime import datetime, timezone

from aiohttp import web

# ── Logging ───────────────────────────────────────────────────────────────────
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
state = {
    "system": {
        "mode":      "STANDBY",
        "timestamp": None,
        "uptime":    0,
    },
    "telemetry": {
        "connected":     False,
        "lat":           None,
        "lon":           None,
        "alt":           None,
        "heading":       None,
        "airspeed":      None,
        "groundspeed":   None,
        "battery_v":     None,
        "battery_pct":   None,
        "gps_fix":       None,
        "flight_mode":   None,
        "armed":         False,
        "heartbeat_age": None,
    },
    "mission": {
        "active":         False,
        "waypoint_count": 0,
        "current_wp":     None,
        "mission_time":   None,
    },
    "sdr": {
        "connected":   False,
        "frequency":   None,
        "sample_rate": None,
        "gain":        None,
        "spectrum":    [],
    },
    "link": {
        "wifi_active":  False,
        "latency_ms":   None,
        "link_quality": None,
    },
    "alerts": []
}

def push_alert(level: str, message: str):
    state["alerts"].append({
        "level":     level,
        "message":   message,
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    state["alerts"] = state["alerts"][-50:]
    log.warning(f"ALERT [{level}] {message}")

# ── REST API Handlers ─────────────────────────────────────────────────────────

async def handle_health(request):
    return web.json_response({
        "status":    "OK",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "mode":      state["system"]["mode"]
    })

async def handle_status(request):
    return web.json_response(state)

async def handle_telemetry(request):
    return web.json_response(state["telemetry"])

async def handle_mission(request):
    return web.json_response(state["mission"])

async def handle_sdr(request):
    return web.json_response(state["sdr"])

async def handle_alerts(request):
    return web.json_response(state["alerts"])

async def handle_abort(request):
    log.warning("ABORT COMMAND RECEIVED — triggering RTL")
    state["system"]["mode"] = "RTL"
    push_alert("RED", "ABORT commanded by operator — RTL initiated")
    return web.json_response({"status": "RTL_COMMANDED"})

async def handle_arm(request):
    log.info("ARM command received")
    return web.json_response({"status": "ARM_COMMANDED"})

async def handle_disarm(request):
    log.info("DISARM command received")
    return web.json_response({"status": "DISARM_COMMANDED"})

async def handle_upload_mission(request):
    data = await request.json()
    waypoints = data.get("waypoints", [])
    log.info(f"Mission upload received: {len(waypoints)} waypoints")
    state["mission"]["waypoint_count"] = len(waypoints)
    return web.json_response({"status": "UPLOAD_RECEIVED", "waypoints": len(waypoints)})

async def handle_sdr_tune(request):
    """POST /api/sdr/tune — retune SDR frequency"""
    data = await request.json()
    freq = data.get("frequency")
    if freq:
        state["sdr"]["frequency"] = freq
        log.info(f"SDR retune commanded: {freq / 1e6:.3f} MHz")
    return web.json_response({"status": "TUNED", "frequency": freq})

async def handle_sdr_gain(request):
    """POST /api/sdr/gain — adjust SDR gain"""
    data = await request.json()
    gain = data.get("gain")
    if gain is not None:
        state["sdr"]["gain"] = gain
        log.info(f"SDR gain commanded: {gain} dB")
    return web.json_response({"status": "GAIN_SET", "gain": gain})


# SDR module reference for audio streaming (set in main)
_sdr_module = None

async def handle_sdr_audio(request):
    """GET /api/sdr/audio — chunked raw PCM audio stream (48kHz mono int16)"""
    global _sdr_module
    if _sdr_module is None:
        return web.Response(status=503, text='SDR not ready')
    response = web.StreamResponse()
    response.headers['Content-Type']  = 'audio/raw'
    response.headers['X-Sample-Rate'] = '48000'
    response.headers['X-Channels']    = '1'
    response.headers['X-Bit-Depth']   = '16'
    await response.prepare(request)
    await _sdr_module.stream_audio(response)
    return response

# ── Background Tasks ──────────────────────────────────────────────────────────

async def heartbeat_watchdog(config):
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
    start = datetime.now(timezone.utc)
    while True:
        await asyncio.sleep(1)
        now = datetime.now(timezone.utc)
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

    app.router.add_get( "/api/health",         handle_health)
    app.router.add_get( "/api/status",         handle_status)
    app.router.add_get( "/api/telemetry",      handle_telemetry)
    app.router.add_get( "/api/mission",        handle_mission)
    app.router.add_get( "/api/sdr",            handle_sdr)
    app.router.add_get( "/api/alerts",         handle_alerts)
    app.router.add_post("/api/abort",          handle_abort)
    app.router.add_post("/api/arm",            handle_arm)
    app.router.add_post("/api/disarm",         handle_disarm)
    app.router.add_post("/api/mission/upload", handle_upload_mission)
    app.router.add_post("/api/sdr/tune",       handle_sdr_tune)
    app.router.add_post("/api/sdr/gain",       handle_sdr_gain)
    app.router.add_get( "/api/sdr/audio",      handle_sdr_audio)

    async def handle_index(request):
        hmi_path = os.path.join(os.path.dirname(__file__), "../hmi/index.html")
        return web.FileResponse(hmi_path)

    app.router.add_get("/", handle_index)

    hmi_path = os.path.join(os.path.dirname(__file__), "../hmi")
    if os.path.exists(hmi_path):
        app.router.add_static("/static", hmi_path, name="hmi")

    return app

# ── Main ──────────────────────────────────────────────────────────────────────

async def main():
    config = load_config()
    host   = config.get("server", {}).get("host", "0.0.0.0")
    port   = config.get("server", {}).get("port", 8080)

    log.info("=" * 60)
    log.info("RAVEN GCS Daemon — Starting")
    log.info(f"Server:  {host}:{port}")
    log.info(f"MAVLink: {config.get('mavlink', {}).get('host')}:{config.get('mavlink', {}).get('port')}")
    log.info(f"SDR:     {config.get('sdr', {}).get('host')}:{config.get('sdr', {}).get('port')}")
    log.info("=" * 60)

    app = build_app(config)

    asyncio.create_task(system_clock(config))
    asyncio.create_task(heartbeat_watchdog(config))

    from mavlink_module import MAVLinkModule
    mav = MAVLinkModule(config, state)
    asyncio.create_task(mav.run())

    global _sdr_module
    from sdr_module import SDRModule
    sdr = SDRModule(config, state)
    _sdr_module = sdr
    asyncio.create_task(sdr.run())

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, host, port)
    await site.start()

    log.info(f"RAVEN GCS online at http://{host}:{port}")
    log.info("Awaiting HMI connection...")

    try:
        await asyncio.Event().wait()
    except (KeyboardInterrupt, SystemExit):
        log.info("RAVEN GCS Daemon shutting down")
        await runner.cleanup()

if __name__ == "__main__":
    asyncio.run(main())