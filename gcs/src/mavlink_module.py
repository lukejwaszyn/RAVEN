"""
RAVEN GCS — MAVLink Module
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Responsibilities:
    - Maintain bidirectional MAVLink connection to AVS (SITL or Pixhawk)
    - Parse incoming MAVLink messages and update shared state
    - Send commands: arm, disarm, RTL, mode change
    - Full MAVLink mission upload protocol (request/response handshake)
    - Heartbeat watchdog — detect link loss within 1s (GCS-FT-FR-002)
    - Message rate target: 4 Hz minimum (GCS-FT-PR-001)

Connection: TCP to 127.0.0.1:5760 (SITL) or Pi MAVLink bridge (flight)

Waypoint format (per item):
    {
        "lat": float,       # degrees
        "lon": float,       # degrees
        "alt": float,       # meters AGL
        "command": int      # MAVLink command (default NAV_WAYPOINT = 16)
    }

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import asyncio
import logging
import math
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
        msg_type = msg.get_type()

        if msg_type == "HEARTBEAT":
            self._last_heartbeat = time.monotonic()
            self.state["telemetry"]["connected"]   = True
            self.state["telemetry"]["flight_mode"] = mavutil.mode_string_v10(msg)
            self.state["telemetry"]["armed"]       = bool(
                msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED
            )

        elif msg_type == "GLOBAL_POSITION_INT":
            self.state["telemetry"]["lat"]     = msg.lat / 1e7
            self.state["telemetry"]["lon"]     = msg.lon / 1e7
            self.state["telemetry"]["alt"]     = msg.relative_alt / 1000.0
            self.state["telemetry"]["heading"] = msg.hdg / 100.0

        elif msg_type == "ATTITUDE":
            self.state["telemetry"]["roll"]  = math.degrees(msg.roll)
            self.state["telemetry"]["pitch"] = math.degrees(msg.pitch)
            self.state["telemetry"]["yaw"]   = math.degrees(msg.yaw)

        elif msg_type == "VFR_HUD":
            self.state["telemetry"]["airspeed"]    = msg.airspeed
            self.state["telemetry"]["groundspeed"] = msg.groundspeed

        elif msg_type == "SYS_STATUS":
            voltage = msg.voltage_battery / 1000.0
            self.state["telemetry"]["battery_v"]   = round(voltage, 2)
            self.state["telemetry"]["battery_pct"] = msg.battery_remaining
            if msg.battery_remaining < 20 and msg.battery_remaining >= 0:
                self._push_alert("RED",   f"LOW BATTERY: {msg.battery_remaining}%")
            elif msg.battery_remaining < 30 and msg.battery_remaining >= 0:
                self._push_alert("AMBER", f"Battery warning: {msg.battery_remaining}%")

        elif msg_type == "GPS_RAW_INT":
            self.state["telemetry"]["gps_fix"] = msg.fix_type
            if msg.fix_type < 3:
                self._push_alert("AMBER", f"GPS fix degraded: type {msg.fix_type}")

        elif msg_type == "MISSION_CURRENT":
            self.state["mission"]["current_wp"] = msg.seq
            self.state["mission"]["active"]     = True

        elif msg_type == "MISSION_COUNT":
            self.state["mission"]["waypoint_count"] = msg.count
            log.info(f"Mission confirmed: {msg.count} waypoints")

        elif msg_type == "MISSION_ACK":
            if msg.type == 0:
                log.info("Mission upload acknowledged — ACCEPTED")
                self._push_alert("INFO", f"Mission uploaded — {self.state['mission']['waypoint_count']} waypoints accepted")
                self.state["system"]["mode"] = "PREFLIGHT"
            else:
                log.error(f"Mission upload REJECTED — type {msg.type}")
                self._push_alert("RED", f"Mission upload rejected by FC — error {msg.type}")

    # ── Heartbeat Age ─────────────────────────────────────────────────────────

    def _update_heartbeat_age(self):
        if self._last_heartbeat is not None:
            age = time.monotonic() - self._last_heartbeat
            self.state["telemetry"]["heartbeat_age"] = round(age, 2)
            timeout = self.mav_config.get("heartbeat_timeout_s", 3)
            if age > timeout and self.state["telemetry"]["connected"]:
                self.state["telemetry"]["connected"] = False
                self.state["link"]["wifi_active"]    = False
                self.state["system"]["mode"]         = "FAULT"
                self._push_alert("RED", f"LINK LOSS — no heartbeat for {age:.1f}s")
                log.error(f"MAVLink link loss — heartbeat age {age:.1f}s")

    # ── Commands ──────────────────────────────────────────────────────────────

    async def send_arm(self):
        await self._command_queue.put(("ARM", None))

    async def send_disarm(self):
        await self._command_queue.put(("DISARM", None))

    async def send_rtl(self):
        await self._command_queue.put(("RTL", None))

    async def send_waypoints(self, waypoints: list):
        await self._command_queue.put(("WAYPOINTS", waypoints))

    async def send_takeoff(self, altitude: float = 20.0):
        await self._command_queue.put(("TAKEOFF", altitude))

    async def send_mode(self, mode: str):
        await self._command_queue.put(("MODE", mode))

    def _execute_command(self, cmd, data):
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

        elif cmd == "MODE":
            self.connection.set_mode(data)
            log.info(f"Mode change: {data}")

        elif cmd == "TAKEOFF":
            alt = data if data else 20.0
            self.connection.mav.command_long_send(
                self.connection.target_system,
                self.connection.target_component,
                mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
                0, 0, 0, 0, 0, 0, 0, alt
            )
            log.info(f"TAKEOFF command sent — altitude {alt}m")

        elif cmd == "WAYPOINTS":
            self._upload_mission(data)

    def _upload_mission(self, waypoints: list):
        """
        Full MAVLink mission upload protocol.
        Handles the request/response handshake with the flight controller.

        Protocol:
            GCS -> MISSION_COUNT
            FC  -> MISSION_REQUEST_INT (item 0)
            GCS -> MISSION_ITEM_INT (item 0)
            FC  -> MISSION_REQUEST_INT (item 1)
            ...repeat...
            FC  -> MISSION_ACK
        """
        if not waypoints:
            log.warning("Empty waypoint list — upload aborted")
            return

        conn  = self.connection
        n_wps = len(waypoints) + 1
        log.info(f"Uploading mission: {len(waypoints)} waypoints ({n_wps} total with home)")

        self.state["mission"]["waypoint_count"] = len(waypoints)

        conn.mav.mission_count_send(
            conn.target_system,
            conn.target_component,
            n_wps,
            mavutil.mavlink.MAV_MISSION_TYPE_MISSION
        )

        items_sent = 0
        timeout    = 10
        start      = time.time()

        while items_sent < n_wps:
            if time.time() - start > timeout:
                log.error("Mission upload timeout")
                self._push_alert("RED", "Mission upload timed out")
                return

            msg = conn.recv_match(
                type=["MISSION_REQUEST", "MISSION_REQUEST_INT", "MISSION_ACK"],
                blocking=True,
                timeout=5
            )

            if msg is None:
                log.warning("No response from FC during mission upload")
                continue

            msg_type = msg.get_type()

            if msg_type in ("MISSION_REQUEST", "MISSION_REQUEST_INT"):
                seq = msg.seq
                log.info(f"FC requested item {seq}")

                if seq == 0:
                    conn.mav.mission_item_int_send(
                        conn.target_system,
                        conn.target_component,
                        0,
                        mavutil.mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT,
                        mavutil.mavlink.MAV_CMD_NAV_WAYPOINT,
                        1, 1,
                        0, 0, 0, 0,
                        0, 0, 0,
                        mavutil.mavlink.MAV_MISSION_TYPE_MISSION
                    )
                else:
                    wp  = waypoints[seq - 1]
                    lat = int(wp["lat"] * 1e7)
                    lon = int(wp["lon"] * 1e7)
                    alt = float(wp.get("alt", 30.0))
                    cmd = wp.get("command", mavutil.mavlink.MAV_CMD_NAV_WAYPOINT)

                    conn.mav.mission_item_int_send(
                        conn.target_system,
                        conn.target_component,
                        seq,
                        mavutil.mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT,
                        cmd,
                        0, 1,
                        0, 0, 0, float("nan"),
                        lat, lon, alt,
                        mavutil.mavlink.MAV_MISSION_TYPE_MISSION
                    )

                items_sent = seq + 1

            elif msg_type == "MISSION_ACK":
                if msg.type == 0:
                    log.info("Mission upload complete — ACCEPTED")
                else:
                    log.error(f"Mission upload REJECTED — error {msg.type}")
                return

        log.info("Mission upload loop complete")

    # ── Main Run Loop ─────────────────────────────────────────────────────────

    async def run(self):
        self.running = True
        await self.connect()

        loop = asyncio.get_event_loop()

        while self.running:
            try:
                msg = await loop.run_in_executor(
                    None,
                    lambda: self.connection.recv_match(blocking=False) if self.connection else None
                )

                if msg and msg.get_type() != "BAD_DATA":
                    self._parse_message(msg)

                self._update_heartbeat_age()

                if not self._command_queue.empty():
                    cmd, data = await self._command_queue.get()
                    await loop.run_in_executor(None, self._execute_command, cmd, data)

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

    def _push_alert(self, level: str, message: str):
        self.state["alerts"].append({
            "level":     level,
            "message":   message,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        self.state["alerts"] = self.state["alerts"][-50:]