"""
RAVEN GCS — Audio Stream Module
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Responsibilities:
    - Demodulate FM audio from IQ samples in real time
    - Stream PCM audio to HMI via chunked HTTP response
    - Operates on the same IQ pipeline as the SDR module
    - No second RTL-SDR required — shares the existing IQ stream

Demodulation chain:
    IQ samples → FM discriminator → LPF → decimate → de-emphasis → PCM int16 → HTTP stream

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import numpy as np
from scipy import signal as sig
import logging

log = logging.getLogger("RAVEN.Audio")

# Audio config
SAMPLE_RATE  = 2_400_000   # IQ sample rate from RTL-SDR
AUDIO_RATE   = 48_000      # Output audio sample rate
DECIMATE     = SAMPLE_RATE // AUDIO_RATE  # 50x decimation
DEEMPH_TC    = 75e-6       # 75us de-emphasis (North American FM standard)
LPF_CUTOFF   = 15_000      # FM audio bandwidth Hz
LPF_ORDER    = 5           # Butterworth filter order


class FMDemodulator:
    """
    Real-time FM demodulator with proper anti-aliasing LPF.
    Takes complex IQ samples, outputs PCM audio samples.

    Chain:
        IQ → FM discriminator (angle of conjugate product)
           → 5th order Butterworth LPF at 15kHz
           → 50x decimation
           → 75us de-emphasis IIR
           → normalize → int16 PCM
    """

    def __init__(self, sample_rate: int = SAMPLE_RATE, audio_rate: int = AUDIO_RATE):
        self.sample_rate = sample_rate
        self.audio_rate  = audio_rate
        self.decimate    = sample_rate // audio_rate
        self._prev_sample = 0 + 0j

        # ── Low pass filter — anti-aliasing before decimation ──────────────
        # Cutoff at FM audio bandwidth (15kHz), normalized to Nyquist
        nyq            = sample_rate / 2.0
        cutoff_norm    = LPF_CUTOFF / nyq
        self._lpf_b, self._lpf_a = sig.butter(LPF_ORDER, cutoff_norm, btype='low')
        self._lpf_zi   = sig.lfilter_zi(self._lpf_b, self._lpf_a)

        # ── De-emphasis filter — single pole IIR ───────────────────────────
        # 75us time constant, applied at audio rate after decimation
        dt                   = 1.0 / audio_rate
        rc                   = DEEMPH_TC
        self._deemph_alpha   = dt / (rc + dt)
        self._deemph_state   = 0.0

    def demodulate(self, iq: np.ndarray) -> np.ndarray:
        """
        FM discriminator → LPF → decimate → de-emphasis → PCM int16.
        """
        # Prepend previous sample for phase continuity across blocks
        iq_full = np.concatenate([[self._prev_sample], iq])
        self._prev_sample = iq[-1]

        # FM discriminator — instantaneous frequency via conjugate product
        conj_product = iq_full[1:] * np.conj(iq_full[:-1])
        demod = np.angle(conj_product)

        # Low pass filter — remove out-of-band noise before decimation
        # Prevents aliasing of high-frequency noise into audio band
        demod, self._lpf_zi = sig.lfilter(
            self._lpf_b, self._lpf_a, demod, zi=self._lpf_zi
        )

        # Decimate to audio rate
        n_out = len(demod) // self.decimate
        if n_out == 0:
            return np.array([], dtype=np.int16)

        trimmed = demod[:n_out * self.decimate]
        audio   = trimmed.reshape(n_out, self.decimate).mean(axis=1)

        # De-emphasis — boost high frequencies attenuated by FM pre-emphasis
        # 75us time constant is North American broadcast standard
        alpha = self._deemph_alpha
        for i in range(len(audio)):
            self._deemph_state = alpha * audio[i] + (1 - alpha) * self._deemph_state
            audio[i] = self._deemph_state

        # Normalize to [-1, 1] and convert to int16 PCM
        peak = np.max(np.abs(audio))
        if peak > 0:
            audio = audio / peak

        return (audio * 32767).astype(np.int16)

    def to_bytes(self, pcm: np.ndarray) -> bytes:
        return pcm.tobytes()

    def reset(self):
        """Reset filter states — call on retune."""
        self._prev_sample  = 0 + 0j
        self._lpf_zi       = sig.lfilter_zi(self._lpf_b, self._lpf_a)
        self._deemph_state = 0.0