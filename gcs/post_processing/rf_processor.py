"""
RAVEN Post-Processing — RF Processor
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Loads georeferenced RF log (JSONL) from a flight and produces:
    - Signal strength map (lat/lon → peak_db)
    - Frequency coverage summary
    - Interpolated RF heatmap grid

Input:  data/rf_logs/rf_log_YYYYMMDDTHHMMSSZ.jsonl
Output: data/processed/rf_map_YYYYMMDDTHHMMSSZ.npz

Requirement: GCS-DP-FR-001 — georeferenced RF spectrum snapshots
Requirement: GCS-DP-FR-003 — fused RF + LIDAR data product

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import json
import os
import sys
import numpy as np
import argparse
from datetime import datetime


def load_rf_log(path: str) -> list:
    """Load RF JSONL log file into list of records."""
    records = []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    # Filter records with valid GPS
    valid = [r for r in records if r.get("lat") and r.get("lon")]
    print(f"RF log: {len(records)} total records, {len(valid)} with GPS")
    return valid


def build_rf_map(records: list) -> dict:
    """
    Build signal strength map from RF records.
    Returns dict with arrays for lat, lon, alt, peak_db, mean_db, noise_floor.
    """
    lats        = np.array([r["lat"]         for r in records])
    lons        = np.array([r["lon"]         for r in records])
    alts        = np.array([r.get("alt", 0) or 0 for r in records])
    peak_dbs    = np.array([r.get("peak_db",  -100) for r in records])
    mean_dbs    = np.array([r.get("mean_db",  -100) for r in records])
    noise_floors= np.array([r.get("noise_floor", -100) for r in records])
    timestamps  = [r["timestamp"] for r in records]
    frequencies = np.array([r.get("frequency", 0) for r in records])

    # SNR estimate: peak above noise floor
    snr = peak_dbs - noise_floors

    print(f"RF coverage:")
    print(f"  Points:      {len(lats)}")
    print(f"  Lat range:   {lats.min():.5f} → {lats.max():.5f}")
    print(f"  Lon range:   {lons.min():.5f} → {lons.max():.5f}")
    print(f"  Alt range:   {alts.min():.1f} → {alts.max():.1f} m")
    print(f"  Peak dB:     {peak_dbs.max():.1f} dBm (max)")
    print(f"  Noise floor: {noise_floors.mean():.1f} dBm (avg)")
    print(f"  Max SNR:     {snr.max():.1f} dB")
    print(f"  Frequencies: {np.unique(frequencies / 1e6)} MHz")

    return {
        "lat":         lats,
        "lon":         lons,
        "alt":         alts,
        "peak_db":     peak_dbs,
        "mean_db":     mean_dbs,
        "noise_floor": noise_floors,
        "snr":         snr,
        "timestamps":  timestamps,
        "frequencies": frequencies,
    }


def interpolate_grid(rf_map: dict, grid_size: int = 100) -> dict:
    """
    Interpolate scattered RF measurements onto a regular grid.
    Uses scipy griddata for natural neighbor interpolation.
    Returns grid arrays for plotting as a heatmap.
    """
    from scipy.interpolate import griddata

    lats     = rf_map["lat"]
    lons     = rf_map["lon"]
    peak_dbs = rf_map["peak_db"]

    if len(lats) < 4:
        print("Too few points for interpolation — need at least 4")
        return None

    # Create regular grid
    lat_grid = np.linspace(lats.min(), lats.max(), grid_size)
    lon_grid = np.linspace(lons.min(), lons.max(), grid_size)
    lon_mesh, lat_mesh = np.meshgrid(lon_grid, lat_grid)

    # Interpolate
    points  = np.column_stack([lons, lats])
    grid_db = griddata(points, peak_dbs, (lon_mesh, lat_mesh), method="linear")

    print(f"RF grid: {grid_size}x{grid_size} interpolated")

    return {
        "lat_grid":  lat_grid,
        "lon_grid":  lon_grid,
        "lat_mesh":  lat_mesh,
        "lon_mesh":  lon_mesh,
        "grid_db":   grid_db,
    }


def save_rf_map(rf_map: dict, grid: dict, output_path: str):
    """Save processed RF map to NPZ file."""
    save_dict = {
        "lat":         rf_map["lat"],
        "lon":         rf_map["lon"],
        "alt":         rf_map["alt"],
        "peak_db":     rf_map["peak_db"],
        "mean_db":     rf_map["mean_db"],
        "noise_floor": rf_map["noise_floor"],
        "snr":         rf_map["snr"],
        "frequencies": rf_map["frequencies"],
    }

    if grid:
        save_dict.update({
            "lat_grid":  grid["lat_grid"],
            "lon_grid":  grid["lon_grid"],
            "grid_db":   grid["grid_db"],
        })

    np.savez(output_path, **save_dict)
    print(f"RF map saved: {output_path}.npz")


def process(input_path: str, output_dir: str) -> dict:
    """Full RF processing pipeline."""
    print(f"\n── RF Processor ─────────────────────────────")
    print(f"Input:  {input_path}")

    records = load_rf_log(input_path)
    if not records:
        print("No valid records — aborting")
        return None

    rf_map = build_rf_map(records)
    grid   = interpolate_grid(rf_map)

    # Output filename from input
    base = os.path.splitext(os.path.basename(input_path))[0]
    base = base.replace("rf_log_", "rf_map_")
    output_path = os.path.join(output_dir, base)

    os.makedirs(output_dir, exist_ok=True)
    save_rf_map(rf_map, grid, output_path)

    return {"rf_map": rf_map, "grid": grid, "output_path": output_path + ".npz"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RAVEN RF Post-Processor")
    parser.add_argument("input",  help="RF log JSONL file")
    parser.add_argument("--output-dir", default="data/processed",
                        help="Output directory")
    args = parser.parse_args()
    process(args.input, args.output_dir)
