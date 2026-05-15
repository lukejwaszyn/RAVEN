"""
RAVEN GCS — SDR Module
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Responsibilities:
    - Connect to rtl_tcp server on AVS (Pi) over WiFi
    - Receive raw IQ samples from RTL-SDR Blog V4
    - Compute FFT spectrum snapshots for HMI waterfall display
    - Tag spectrum snapshots with GPS position and timestamp
    - Log georeferenced RF data to file for post-flight processing
    - Stream live spectrum to state object for HMI consumption

Connection: TCP to uav-pi.local:1234 (rtl_tcp server)

Requirements:
    GCS-DP-FR-001 — ingest IQ data, produce georeferenced RF snapshots
    GCS-DP-FR-004 — display live RF spectrum during flight
    AVS-RF-PR-001 — minimum 2.4 MHz instantaneous bandwidth
    AVS-RF-PR-002 — 500 kHz to 1.766 GHz tunable range

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import asyncio
import logging
import numpy as np
import socket
import struct
import time
import os
from datetime import datetime, timezone

log = logging.getLogger("RAVEN.SDR")

# RTL-TCP protocol constants
RTLTCP_SET_FREQ         = 0x01
RTLTCP_SET_SAMPLE_RATE  = 0x02
RTLTCP_SET_GAIN_MODE    = 0x03
RTLTCP_SET_GAIN         = 0x04
RTLTCP_SET_AGC_MODE     = 0x08

# FFT config
FFT_SIZE = 1024


class SDRModule:
    """
    Async SDR IQ stream manager.
    Connects to rtl_tcp on the Pi, reads IQ samples, computes spectrum.
    Runs as a background task inside the GCS daemon event loop.
    """

    def __init__(self, config: dict, state: dict):
        self.config     = config
        self.state      = state
        self.sdr_config = config.get("sdr", {})
        self.host       = self.sdr_config.get("host", "uav-pi.local")
        self.port       = self.sdr_config.get("port", 1234)
        self.frequency  = self.sdr_config.get("frequency",   100_000_000)
        self.sample_rate = self.sdr_config.get("sample_rate", 2_400_000)
        self.gain       = self.sdr_config.get("gain", 40)
        self.running    = False
        self.sock       = None

        # Log path for georeferenced RF data
        self.log_dir    = os.path.join(
            os.path.dirname(__file__), "../../data/rf_logs"
        )
        os.makedirs(self.log_dir, exist_ok=True)
        self.log_file   = None

    # ── Connection ────────────────────────────────────────────────────────────

    def _connect(self):
        """Blocking TCP connect to rtl_tcp — called in executor."""
        log.info(f"Connecting to rtl_tcp at {self.host}:{self.port}")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect((self.host, self.port))
        sock.settimeout(None)

        # Read rtl_tcp magic header (12 bytes)
        header = sock.recv(12)
        if len(header) < 12:
            raise ConnectionError("rtl_tcp header not received")

        magic   = header[0:4]
        tuner   = struct.unpack(">I", header[4:8])[0]
        gain_count = struct.unpack(">I", header[8:12])[0]
        log.info(f"rtl_tcp magic: {magic} tuner: {tuner} gains: {gain_count}")

        return sock

    def _send_command(self, cmd: int, param: int):
        """Send a 5-byte rtl_tcp command."""
        if self.sock:
            data = struct.pack(">BI", cmd, param)
            self.sock.send(data)

    def _configure_sdr(self):
        """Send initial configuration commands to rtl_tcp."""
        log.info(f"Configuring SDR: freq={self.frequency}Hz rate={self.sample_rate}Hz gain={self.gain}dB")
        self._send_command(RTLTCP_SET_SAMPLE_RATE, self.sample_rate)
        self._send_command(RTLTCP_SET_FREQ,        self.frequency)
        self._send_command(RTLTCP_SET_GAIN_MODE,   1)           # manual gain
        self._send_command(RTLTCP_SET_GAIN,        self.gain * 10)  # gain in 0.1dB units
        self._send_command(RTLTCP_SET_AGC_MODE,    0)           # AGC off

        # Update state
        self.state["sdr"]["connected"]   = True
        self.state["sdr"]["frequency"]   = self.frequency
        self.state["sdr"]["sample_rate"] = self.sample_rate
        self.state["sdr"]["gain"]        = self.gain

    # ── IQ Reading ────────────────────────────────────────────────────────────

    def _read_samples(self, num_samples: int) -> np.ndarray:
        """
        Read raw IQ bytes from rtl_tcp socket.
        RTL-SDR sends interleaved uint8 I/Q pairs.
        Returns complex64 array normalized to [-1, 1].
        """
        num_bytes = num_samples * 2  # I + Q bytes
        buf = bytearray()
        while len(buf) < num_bytes:
            chunk = self.sock.recv(num_bytes - len(buf))
            if not chunk:
                raise ConnectionError("rtl_tcp socket closed")
            buf.extend(chunk)

        # Convert uint8 IQ to complex float
        raw = np.frombuffer(buf, dtype=np.uint8).astype(np.float32)
        raw = (raw - 127.5) / 127.5  # normalize to [-1, 1]
        iq  = raw[0::2] + 1j * raw[1::2]
        return iq

    # ── FFT / Spectrum ────────────────────────────────────────────────────────

    def _compute_spectrum(self, iq_samples: np.ndarray) -> list:
        """
        Compute power spectrum from IQ samples via FFT.
        Returns list of dB values for HMI waterfall.
        """
        window    = np.blackman(len(iq_samples))
        windowed  = iq_samples * window
        fft_out   = np.fft.fftshift(np.fft.fft(windowed, n=FFT_SIZE))
        power_db  = 20 * np.log10(np.abs(fft_out) + 1e-10)
        return power_db.tolist()

    # ── Georeferencing ────────────────────────────────────────────────────────

    def _geotag_snapshot(self, spectrum: list) -> dict:
        """
        Tag spectrum snapshot with current GPS position from telemetry state.
        Requirement: GCS-DP-FR-001 — georeferenced RF snapshots.
        """
        tlm = self.state["telemetry"]
        return {
            "timestamp":   datetime.now(timezone.utc).isoformat(),
            "frequency":   self.frequency,
            "sample_rate": self.sample_rate,
            "gain":        self.gain,
            "lat":         tlm.get("lat"),
            "lon":         tlm.get("lon"),
            "alt":         tlm.get("alt"),
            "heading":     tlm.get("heading"),
            "spectrum_db": spectrum
        }

    def _log_snapshot(self, snapshot: dict):
        """Append georeferenced snapshot to the RF log file."""
        if self.log_file:
            import json
            self.log_file.write(json.dumps(snapshot) + "\n")
            self.log_file.flush()

    # ── Tune ─────────────────────────────────────────────────────────────────

    async def tune(self, frequency: int):
        """Retune the SDR to a new frequency in Hz."""
        self.frequency = frequency
        self._send_command(RTLTCP_SET_FREQ, frequency)
        self.state["sdr"]["frequency"] = frequency
        log.info(f"Retuned to {frequency / 1e6:.3f} MHz")

    # ── Main Run Loop ─────────────────────────────────────────────────────────

    async def run(self):
        """
        Main async SDR loop.
        Connects to rtl_tcp, reads IQ blocks, computes spectrum,
        geotags snapshots, logs to file, updates HMI state.
        """
        self.running = True
        loop = asyncio.get_event_loop()

        # Open RF log file
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        log_path = os.path.join(self.log_dir, f"rf_log_{ts}.jsonl")
        self.log_file = open(log_path, "w")
        log.info(f"RF log: {log_path}")

        while self.running:
            try:
                # Connect
                self.sock = await loop.run_in_executor(None, self._connect)
                self._configure_sdr()
                self._push_alert("INFO", f"SDR connected — {self.frequency / 1e6:.1f} MHz")

                # Read loop
                while self.running:
                    # Read one FFT block of samples
                    iq = await loop.run_in_executor(
                        None, self._read_samples, FFT_SIZE
                    )

                    # Compute spectrum
                    spectrum = self._compute_spectrum(iq)

                    # Update HMI state — live waterfall
                    self.state["sdr"]["spectrum"] = spectrum

                    # Geotag and log
                    snapshot = self._geotag_snapshot(spectrum)
                    self._log_snapshot(snapshot)

                    # Yield to event loop
                    await asyncio.sleep(0)

            except ConnectionError as e:
                log.warning(f"SDR connection lost: {e}")
                self.state["sdr"]["connected"] = False
                self._push_alert("AMBER", f"SDR disconnected: {e}")
                if self.sock:
                    self.sock.close()
                    self.sock = None
                await asyncio.sleep(5)  # retry delay

            except Exception as e:
                log.error(f"SDR module error: {e}")
                self.state["sdr"]["connected"] = False
                self._push_alert("RED", f"SDR error: {e}")
                if self.sock:
                    self.sock.close()
                    self.sock = None
                await asyncio.sleep(5)

    def stop(self):
        self.running = False
        if self.sock:
            self.sock.close()
        if self.log_file:
            self.log_file.close()
        log.info("SDR module stopped")

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _push_alert(self, level: str, message: str):
        self.state["alerts"].append({
            "level":     level,
            "message":   message,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        self.state["alerts"] = self.state["alerts"][-50:]
