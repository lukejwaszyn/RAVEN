"""
RAVEN GCS — MAVLink Module
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Responsibilities:
    - Maintain bidirectional MAVLink connection to AVS (SITL or Pixhawk)
    - Parse incoming MAVLink messages and update shared state
    - Send commands: arm, disarm, RTL, waypoint upload, mode change
    - Run heartbeat watchdog — detect link loss within 1s (GCS-FT-FR-002)
    - Message rate target: 4 Hz minimum (GCS-FT-PR-001)

Connection: TCP to 127.0.0.1:5760 (SITL) or Pi MAVLink bridge (flight)

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import asyncio
import logging
import time
from datetime import datetime, timezone

from pymavlink import mavutil

log = logging.getLogger("RAVEN.MAVLink")


class MAVLinkModule:
    """
    Async MAVLink connection manager.
    Runs as a background task inside the GCS daemon event loop.
    """

    def __init__(self, config: dict, state: dict):
        self.config     = config
        self.state      = state
        self.mav_config = config.get("mavlink", {})
        self.host       = self.mav_config.get("host", "127.0.0.1")
        self.port       = self.mav_config.get("port", 5760)
        self.conn_str   = f"tcp:{self.host}:{self.port}"
        self.connection = None
        self.running    = False
        self._last_heartbeat = None
        self._command_queue  = asyncio.Queue()

    # ── Connection ────────────────────────────────────────────────────────────

    def _connect(self):
        """Blocking MAVLink connection — called in executor to avoid blocking loop."""
        log.info(f"Connecting to MAVLink at {self.conn_str}")
        conn = mavutil.mavlink_connection(
            self.conn_str,
            autoreconnect=True,
            source_system=255,
            source_component=0
        )
        log.info("Waiting for heartbeat...")
        conn.wait_heartbeat(timeout=10)
        log.info(f"Heartbeat received — system {conn.target_system} component {conn.target_component}")
        return conn

    async def connect(self):
        """Async wrapper around blocking connect."""
        loop = asyncio.get_event_loop()
        try:
            self.connection = await loop.run_in_executor(None, self._connect)
            self._last_heartbeat = time.monotonic()
            self.state["telemetry"]["connected"] = True
            self.state["link"]["wifi_active"]    = True
            self.state["system"]["mode"]         = "STANDBY"
            log.info("MAVLink connection established")
            self._push_alert("INFO", "MAVLink link established")
        except Exception as e:
            log.error(f"MAVLink connection failed: {e}")
            self.state["telemetry"]["connected"] = False
            self._push_alert("RED", f"MAVLink connection failed: {e}")

    # ── Message Parsing ───────────────────────────────────────────────────────

    def _parse_message(self, msg):
        """Parse a single MAVLink message and update state."""
        msg_type = msg.get_type()

        if msg_type == "HEARTBEAT":
            self._last_heartbeat = time.monotonic()
            self.state["telemetry"]["connected"]   = True
            self.state["telemetry"]["flight_mode"] = mavutil.mode_string_v10(msg)
            self.state["telemetry"]["armed"]       = bool(msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED)

        elif msg_type == "GLOBAL_POSITION_INT":
            self.state["telemetry"]["lat"]         = msg.lat / 1e7
            self.state["telemetry"]["lon"]         = msg.lon / 1e7
            self.state["telemetry"]["alt"]         = msg.relative_alt / 1000.0  # mm → m
            self.state["telemetry"]["heading"]     = msg.hdg / 100.0            # cdeg → deg

        elif msg_type == "VFR_HUD":
            self.state["telemetry"]["airspeed"]    = msg.airspeed
            self.state["telemetry"]["groundspeed"] = msg.groundspeed

        elif msg_type == "SYS_STATUS":
            voltage = msg.voltage_battery / 1000.0  # mV → V
            self.state["telemetry"]["battery_v"]   = round(voltage, 2)
            self.state["telemetry"]["battery_pct"] = msg.battery_remaining

            # Low battery alert
            if msg.battery_remaining < 20 and msg.battery_remaining >= 0:
                self._push_alert("RED", f"LOW BATTERY: {msg.battery_remaining}%")
            elif msg.battery_remaining < 30 and msg.battery_remaining >= 0:
                self._push_alert("AMBER", f"Battery warning: {msg.battery_remaining}%")

        elif msg_type == "GPS_RAW_INT":
            self.state["telemetry"]["gps_fix"]     = msg.fix_type
            if msg.fix_type < 3:
                self._push_alert("AMBER", f"GPS fix degraded: type {msg.fix_type}")

        elif msg_type == "MISSION_CURRENT":
            self.state["mission"]["current_wp"]    = msg.seq
            self.state["mission"]["active"]        = True

        elif msg_type == "MISSION_COUNT":
            self.state["mission"]["waypoint_count"] = msg.count
            log.info(f"Mission uploaded: {msg.count} waypoints")

    # ── Heartbeat Age ─────────────────────────────────────────────────────────

    def _update_heartbeat_age(self):
        """Update heartbeat age in state. Called every loop tick."""
        if self._last_heartbeat is not None:
            age = time.monotonic() - self._last_heartbeat
            self.state["telemetry"]["heartbeat_age"] = round(age, 2)

            # Link loss detection — GCS-FT-FR-002
            timeout = self.mav_config.get("heartbeat_timeout_s", 3)
            if age > timeout and self.state["telemetry"]["connected"]:
                self.state["telemetry"]["connected"] = False
                self.state["link"]["wifi_active"]    = False
                self.state["system"]["mode"]         = "FAULT"
                self._push_alert("RED", f"LINK LOSS — no heartbeat for {age:.1f}s")
                log.error(f"MAVLink link loss — heartbeat age {age:.1f}s")

    # ── Commands ──────────────────────────────────────────────────────────────

    async def send_arm(self):
        """Arm the vehicle."""
        await self._command_queue.put(("ARM", None))

    async def send_disarm(self):
        """Disarm the vehicle."""
        await self._command_queue.put(("DISARM", None))

    async def send_rtl(self):
        """Command Return to Launch."""
        await self._command_queue.put(("RTL", None))

    async def send_waypoints(self, waypoints: list):
        """Upload waypoint list to vehicle."""
        await self._command_queue.put(("WAYPOINTS", waypoints))

    def _execute_command(self, cmd, data):
        """Execute a MAVLink command — blocking, called in executor."""
        if self.connection is None:
            log.warning("Cannot send command — no MAVLink connection")
            return

        if cmd == "ARM":
            self.connection.arducopter_arm()
            log.info("ARM command sent")

        elif cmd == "DISARM":
            self.connection.arducopter_disarm()
            log.info("DISARM command sent")

        elif cmd == "RTL":
            self.connection.set_mode("RTL")
            log.warning("RTL command sent")

        elif cmd == "WAYPOINTS":
            log.info(f"Uploading {len(data)} waypoints")
            self.connection.waypoint_count_send(len(data))

    # ── Main Run Loop ─────────────────────────────────────────────────────────

    async def run(self):
        """
        Main async run loop.
        Connects to MAVLink, then spins reading messages and processing commands.
        Requirement: GCS-FT-PR-001 — sustain MAVLink at 4 Hz minimum.
        """
        self.running = True
        await self.connect()

        loop = asyncio.get_event_loop()

        while self.running:
            try:
                # Non-blocking message read — run in executor to not block event loop
                msg = await loop.run_in_executor(
                    None,
                    lambda: self.connection.recv_match(blocking=False) if self.connection else None
                )

                if msg and msg.get_type() != "BAD_DATA":
                    self._parse_message(msg)

                # Update heartbeat age every tick
                self._update_heartbeat_age()

                # Process any queued commands
                if not self._command_queue.empty():
                    cmd, data = await self._command_queue.get()
                    await loop.run_in_executor(None, self._execute_command, cmd, data)

                # 4 Hz poll rate — GCS-FT-PR-001
                await asyncio.sleep(0.25)

            except Exception as e:
                log.error(f"MAVLink loop error: {e}")
                self.state["telemetry"]["connected"] = False
                self.state["system"]["mode"]         = "FAULT"
                self._push_alert("RED", f"MAVLink error: {e}")
                await asyncio.sleep(2)

    def stop(self):
        self.running = False
        if self.connection:
            self.connection.close()
        log.info("MAVLink module stopped")

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _push_alert(self, level: str, message: str):
        self.state["alerts"].append({
            "level":     level,
            "message":   message,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        self.state["alerts"] = self.state["alerts"][-50:]
