"""
RAVEN GCS — SDR Module
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Responsibilities:
    - Connect to rtl_tcp server on AVS (Pi) over WiFi
    - Receive raw IQ samples from RTL-SDR Blog V4
    - Compute FFT spectrum snapshots for HMI waterfall display
    - Demodulate FM audio for live HMI audio stream
    - Tag spectrum snapshots with GPS position and timestamp
    - Log georeferenced RF summary data (mission-only, 1Hz, no raw bins)

Requirements:
    GCS-DP-FR-001 — ingest IQ data, produce georeferenced RF snapshots
    GCS-DP-FR-004 — display live RF spectrum during flight
    AVS-RF-PR-001 — minimum 2.4 MHz instantaneous bandwidth
    AVS-RF-PR-002 — 500 kHz to 1.766 GHz tunable range

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import asyncio
import json
import logging
import numpy as np
import socket
import struct
import time
import os
from collections import deque
from datetime import datetime, timezone

from audio_stream import FMDemodulator

log = logging.getLogger("RAVEN.SDR")

# rtl_tcp protocol constants
RTLTCP_SET_FREQ        = 0x01
RTLTCP_SET_SAMPLE_RATE = 0x02
RTLTCP_SET_GAIN_MODE   = 0x03
RTLTCP_SET_GAIN        = 0x04
RTLTCP_SET_AGC_MODE    = 0x08

# IQ block size — larger blocks = better audio quality, more latency
# 2400000 samples/sec / 50 decimation = 48000 Hz audio
# 48000 samples/block / 48000 Hz = 1 second of audio per block
# Use 0.1s blocks for low latency
IQ_BLOCK_SIZE = 240_000   # 0.1s of IQ at 2.4MSPS
FFT_SIZE      = 1024

# Audio buffer — holds ~2 seconds of PCM for streaming
AUDIO_BUFFER_MAXLEN = 96_000   # 2s at 48kHz


class SDRModule:
    def __init__(self, config: dict, state: dict):
        self.config      = config
        self.state       = state
        self.sdr_config  = config.get("sdr", {})
        self.host        = self.sdr_config.get("host", "uav-pi.local")
        self.port        = self.sdr_config.get("port", 1234)
        self.frequency   = self.sdr_config.get("frequency",   100_000_000)
        self.sample_rate = self.sdr_config.get("sample_rate", 2_400_000)
        self.gain        = self.sdr_config.get("gain", 40)
        self.running     = False
        self.sock        = None
        self._last_log_time = 0

        # FM demodulator
        self._demod = FMDemodulator(self.sample_rate)

        # Audio buffer — shared with HTTP stream handler
        self.audio_buffer = deque(maxlen=AUDIO_BUFFER_MAXLEN)
        self.audio_lock   = asyncio.Lock()
        self._audio_event = asyncio.Event()

        # Sync initial values into state
        self.state["sdr"]["frequency"]   = self.frequency
        self.state["sdr"]["sample_rate"] = self.sample_rate
        self.state["sdr"]["gain"]        = self.gain

        self.log_dir  = os.path.join(os.path.dirname(__file__), "../../data/rf_logs")
        os.makedirs(self.log_dir, exist_ok=True)
        self.log_file = None

    # ── Connection ────────────────────────────────────────────────────────────

    def _connect(self):
        log.info(f"Connecting to rtl_tcp at {self.host}:{self.port}")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect((self.host, self.port))
        sock.settimeout(None)

        header = sock.recv(12)
        if len(header) < 12:
            raise ConnectionError("rtl_tcp header not received")

        magic      = header[0:4]
        tuner      = struct.unpack(">I", header[4:8])[0]
        gain_count = struct.unpack(">I", header[8:12])[0]
        log.info(f"rtl_tcp magic: {magic} tuner: {tuner} gains: {gain_count}")
        return sock

    def _send_command(self, cmd: int, param: int):
        if self.sock:
            self.sock.send(struct.pack(">BI", cmd, param))

    def _configure_sdr(self):
        log.info(f"Configuring SDR: freq={self.frequency}Hz rate={self.sample_rate}Hz gain={self.gain}dB")
        self._send_command(RTLTCP_SET_SAMPLE_RATE, self.sample_rate)
        self._send_command(RTLTCP_SET_FREQ,        self.frequency)
        self._send_command(RTLTCP_SET_GAIN_MODE,   1)
        self._send_command(RTLTCP_SET_GAIN,        self.gain * 10)
        self._send_command(RTLTCP_SET_AGC_MODE,    0)

        self.state["sdr"]["connected"]   = True
        self.state["sdr"]["frequency"]   = self.frequency
        self.state["sdr"]["sample_rate"] = self.sample_rate
        self.state["sdr"]["gain"]        = self.gain

    # ── IQ Reading ────────────────────────────────────────────────────────────

    def _read_samples(self, num_samples: int) -> np.ndarray:
        num_bytes = num_samples * 2
        buf = bytearray()
        while len(buf) < num_bytes:
            chunk = self.sock.recv(min(65536, num_bytes - len(buf)))
            if not chunk:
                raise ConnectionError("rtl_tcp socket closed")
            buf.extend(chunk)

        raw = np.frombuffer(buf, dtype=np.uint8).astype(np.float32)
        raw = (raw - 127.5) / 127.5
        return raw[0::2] + 1j * raw[1::2]

    # ── FFT ───────────────────────────────────────────────────────────────────

    def _compute_spectrum(self, iq: np.ndarray) -> list:
        # Use first FFT_SIZE samples for spectrum
        chunk    = iq[:FFT_SIZE] if len(iq) >= FFT_SIZE else iq
        window   = np.blackman(len(chunk))
        fft_out  = np.fft.fftshift(np.fft.fft(chunk * window, n=FFT_SIZE))
        power_db = 20 * np.log10(np.abs(fft_out) + 1e-10)
        return power_db.tolist()

    # ── Audio ─────────────────────────────────────────────────────────────────

    def _process_audio(self, iq: np.ndarray):
        """Demodulate IQ to PCM and push to audio buffer."""
        pcm = self._demod.demodulate(iq)
        if len(pcm) > 0:
            self.audio_buffer.extend(pcm.tolist())
            self._audio_event.set()

    async def stream_audio(self, response):
        """
        Async generator for chunked PCM audio streaming.
        Called by the HTTP handler for /api/sdr/audio.
        Streams raw 48kHz mono int16 PCM.
        Browser uses Web Audio API to decode and play.
        """
        CHUNK_SAMPLES = 4800  # 100ms chunks at 48kHz
        log.info("Audio stream client connected")

        try:
            while True:
                # Wait for audio data
                await asyncio.wait_for(self._audio_event.wait(), timeout=2.0)
                self._audio_event.clear()

                # Drain available samples
                while len(self.audio_buffer) >= CHUNK_SAMPLES:
                    chunk = []
                    for _ in range(CHUNK_SAMPLES):
                        if self.audio_buffer:
                            chunk.append(self.audio_buffer.popleft())
                    pcm = np.array(chunk, dtype=np.int16)
                    await response.write(pcm.tobytes())

        except asyncio.TimeoutError:
            log.info("Audio stream timeout — no data")
        except Exception as e:
            log.info(f"Audio stream ended: {e}")

    # ── Georeferenced Logging ─────────────────────────────────────────────────

    def _log_snapshot(self, spectrum: list):
        """Mission-only, 1Hz, summary stats — no raw bins."""
        if not self.state["mission"]["active"]:
            return
        now = time.time()
        if now - self._last_log_time < 1.0:
            return
        self._last_log_time = now
        if not self.log_file:
            return

        arr = np.array(spectrum)
        tlm = self.state["telemetry"]
        snapshot = {
            "timestamp":   datetime.now(timezone.utc).isoformat(),
            "frequency":   self.frequency,
            "sample_rate": self.sample_rate,
            "gain":        self.gain,
            "lat":         tlm.get("lat"),
            "lon":         tlm.get("lon"),
            "alt":         tlm.get("alt"),
            "heading":     tlm.get("heading"),
            "peak_db":     float(np.max(arr)),
            "mean_db":     float(np.mean(arr)),
            "noise_floor": float(np.percentile(arr, 10))
        }
        self.log_file.write(json.dumps(snapshot) + "\n")
        self.log_file.flush()

    # ── Retune / Gain ─────────────────────────────────────────────────────────

    def _check_commands(self):
        state_freq = self.state["sdr"]["frequency"]
        state_gain = self.state["sdr"]["gain"]

        if state_freq and state_freq != self.frequency:
            self.frequency = state_freq
            self._send_command(RTLTCP_SET_FREQ, self.frequency)
            self._demod.reset()
            self.audio_buffer.clear()
            log.info(f"Retuned to {self.frequency / 1e6:.3f} MHz")

        if state_gain is not None and state_gain != self.gain:
            self.gain = state_gain
            self._send_command(RTLTCP_SET_GAIN, self.gain * 10)
            log.info(f"Gain set to {self.gain} dB")

    # ── Main Run Loop ─────────────────────────────────────────────────────────

    async def run(self):
        self.running = True
        loop = asyncio.get_event_loop()

        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        log_path = os.path.join(self.log_dir, f"rf_log_{ts}.jsonl")
        self.log_file = open(log_path, "w")
        log.info(f"RF log: {log_path}")

        while self.running:
            try:
                self.sock = await loop.run_in_executor(None, self._connect)
                self._configure_sdr()
                self._push_alert("INFO", f"SDR connected — {self.frequency / 1e6:.1f} MHz")

                while self.running:
                    # Read larger block for better audio quality
                    iq = await loop.run_in_executor(
                        None, self._read_samples, IQ_BLOCK_SIZE
                    )

                    # Spectrum from first FFT_SIZE samples
                    spectrum = self._compute_spectrum(iq)
                    self.state["sdr"]["spectrum"] = spectrum

                    # FM demodulation — runs on full block
                    self._process_audio(iq)

                    # Logging and command check
                    self._log_snapshot(spectrum)
                    self._check_commands()

                    await asyncio.sleep(0)

            except ConnectionError as e:
                log.warning(f"SDR connection lost: {e}")
                self.state["sdr"]["connected"] = False
                self.audio_buffer.clear()
                self._push_alert("AMBER", f"SDR disconnected: {e}")
                if self.sock:
                    self.sock.close()
                    self.sock = None
                await asyncio.sleep(5)

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

    def _push_alert(self, level: str, message: str):
        self.state["alerts"].append({
            "level":     level,
            "message":   message,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        self.state["alerts"] = self.state["alerts"][-50:]