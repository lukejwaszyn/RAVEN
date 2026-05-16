"""
RAVEN Post-Processing — Synthetic Test Data Generator
Generates realistic RF and LIDAR logs for pipeline testing
without requiring a real flight.

Simulates a rectangular survey mission over Aliquippa, PA.
Output matches exact format of real flight logs.

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import json
import os
import math
import random
import numpy as np
from datetime import datetime, timezone, timedelta

# Mission parameters
CENTER_LAT  = 40.6144
CENTER_LON  = -80.2007
ALT_AGL     = 30.0       # meters
SPEED       = 5.0        # m/s
DURATION_S  = 120        # 2 minute simulated flight
RF_FREQ     = 100_000_000
SAMPLE_RATE = 2_400_000

# Simulate an FM transmitter nearby
TX_LAT = 40.6200
TX_LON = -80.1950
TX_POWER = 30.0  # dBm EIRP

def path_generator():
    """Generate a rectangular lawnmower survey path."""
    # 4 legs of a rectangle, ~200m x 150m
    waypoints = [
        (CENTER_LAT - 0.0009, CENTER_LON - 0.0012),
        (CENTER_LAT - 0.0009, CENTER_LON + 0.0012),
        (CENTER_LAT + 0.0009, CENTER_LON + 0.0012),
        (CENTER_LAT + 0.0009, CENTER_LON - 0.0012),
        (CENTER_LAT - 0.0009, CENTER_LON - 0.0012),
    ]

    points = []
    for i in range(len(waypoints) - 1):
        lat1, lon1 = waypoints[i]
        lat2, lon2 = waypoints[i + 1]
        steps = 30
        for s in range(steps):
            t = s / steps
            points.append((
                lat1 + t * (lat2 - lat1),
                lon1 + t * (lon2 - lon1)
            ))
    return points

def rf_signal_at(lat, lon):
    """Estimate RF signal strength based on distance to simulated transmitter."""
    dlat = (lat - TX_LAT) * 111320
    dlon = (lon - TX_LON) * 111320 * math.cos(math.radians(lat))
    dist = math.sqrt(dlat**2 + dlon**2)
    dist = max(dist, 10)

    # Free space path loss simplified
    path_loss = 20 * math.log10(dist) + random.gauss(0, 2)
    peak_db   = TX_POWER - path_loss
    noise     = random.gauss(-85, 3)
    mean_db   = peak_db - random.uniform(5, 15)

    return peak_db, mean_db, noise

def generate_rf_log(path, output_path):
    """Generate synthetic RF log JSONL."""
    start_time = datetime.now(timezone.utc) - timedelta(hours=1)
    records = []

    for i, (lat, lon) in enumerate(path):
        t = start_time + timedelta(seconds=i * DURATION_S / len(path))
        peak, mean, noise = rf_signal_at(lat, lon)

        record = {
            "timestamp":   t.isoformat(),
            "frequency":   RF_FREQ,
            "sample_rate": SAMPLE_RATE,
            "gain":        40,
            "lat":         lat + random.gauss(0, 0.00001),
            "lon":         lon + random.gauss(0, 0.00001),
            "alt":         ALT_AGL + random.gauss(0, 0.5),
            "heading":     random.uniform(0, 360),
            "peak_db":     round(peak, 2),
            "mean_db":     round(mean, 2),
            "noise_floor": round(noise, 2)
        }
        records.append(record)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

    print(f"RF log generated: {output_path} ({len(records)} records)")

def generate_lidar_log(path, output_path):
    """Generate synthetic LIDAR log JSONL."""
    start_time = datetime.now(timezone.utc) - timedelta(hours=1)
    records = []

    for i, (lat, lon) in enumerate(path):
        t = start_time + timedelta(seconds=i * DURATION_S / len(path))

        # Synthetic terrain — slight variation
        terrain_dist = 30.0 + 5 * math.sin(lat * 1000) + random.gauss(0, 0.5)
        terrain_mm   = terrain_dist * 1000

        # Generate 180 point scan
        points = []
        for angle in range(0, 360, 2):
            rad  = math.radians(angle)
            dist = terrain_mm + random.gauss(0, 50)
            dist = max(100, dist)
            q    = random.randint(10, 47)
            points.append([q, angle, round(dist, 1)])

        record = {
            "timestamp":  t.isoformat(),
            "lat":        lat + random.gauss(0, 0.00001),
            "lon":        lon + random.gauss(0, 0.00001),
            "alt":        ALT_AGL + random.gauss(0, 0.5),
            "gps_fix":    3,
            "scan_count": i,
            "points":     points
        }
        records.append(record)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

    print(f"LIDAR log generated: {output_path} ({len(records)} records)")

if __name__ == "__main__":
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = path_generator()

    rf_out    = f"data/rf_logs/rf_log_{ts}.jsonl"
    lidar_out = f"data/lidar_logs/lidar_{ts}.jsonl"

    generate_rf_log(path, rf_out)
    generate_lidar_log(path, lidar_out)

    print(f"\nTest data ready. Run:")
    print(f"  python gcs/post_processing/process_flight.py --latest")
