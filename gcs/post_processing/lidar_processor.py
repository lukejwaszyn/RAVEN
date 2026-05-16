"""
RAVEN Post-Processing — LIDAR Processor
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Loads georeferenced LIDAR log (JSONL) from a flight and produces:
    - Terrain profile (2D cross-section per scan)
    - Georeferenced point cloud (lat/lon/alt → relative distance)
    - Ground elevation estimate per GPS position

Input:  data/lidar_logs/lidar_YYYYMMDDTHHMMSSZ.jsonl
Output: data/processed/lidar_map_YYYYMMDDTHHMMSSZ.npz

Requirement: GCS-DP-FR-002 — georeferenced terrain map
Requirement: AVS-LI-PR-001 — minimum 6m scan range
Requirement: AVS-LI-PR-002 — minimum 5.5 Hz scan frequency

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import json
import os
import numpy as np
import argparse
import math


def load_lidar_log(path: str) -> list:
    """Load LIDAR JSONL log into list of scan records."""
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

    valid = [r for r in records if r.get("lat") and r.get("lon") and r.get("points")]
    print(f"LIDAR log: {len(records)} total scans, {len(valid)} with GPS")
    return valid


def polar_to_cartesian(points: list) -> np.ndarray:
    """
    Convert RPLidar polar scan points to Cartesian (x, y) in mm.
    Input: [[quality, angle_deg, distance_mm], ...]
    Output: Nx2 array of (x, y) in mm, filtered by quality
    """
    result = []
    for point in points:
        if len(point) < 3:
            continue
        q, angle, dist = point[0], point[1], point[2]
        if dist < 100 or dist > 40000:
            continue
        rad = math.radians(angle)
        x = dist * math.cos(rad)
        y = dist * math.sin(rad)
        result.append([x, y])
    return np.array(result) if result else np.empty((0, 2))


def build_terrain_profile(records: list) -> dict:
    """
    Build terrain profile from LIDAR scans.
    For each scan, compute:
        - Mean ground distance (downward-facing points)
        - Min distance (closest obstacle)
        - Point cloud in UAV body frame
    """
    lats       = []
    lons       = []
    alts       = []
    mean_dists = []
    min_dists  = []
    timestamps = []
    all_points = []  # For full point cloud export

    for rec in records:
        points = rec.get("points", [])
        xy     = polar_to_cartesian(points)

        if len(xy) == 0:
            continue

        dists = np.sqrt(xy[:, 0]**2 + xy[:, 1]**2)

        lats.append(rec["lat"])
        lons.append(rec["lon"])
        alts.append(rec.get("alt") or 0)
        mean_dists.append(float(np.mean(dists)))
        min_dists.append(float(np.min(dists)))
        timestamps.append(rec["timestamp"])

        # Store decimated point cloud (every 5th point to keep size manageable)
        if len(xy) > 0:
            all_points.append({
                "lat":    rec["lat"],
                "lon":    rec["lon"],
                "alt":    rec.get("alt") or 0,
                "points": xy[::5].tolist()
            })

    lats       = np.array(lats)
    lons       = np.array(lons)
    alts       = np.array(alts)
    mean_dists = np.array(mean_dists) / 1000.0  # mm → m
    min_dists  = np.array(min_dists)  / 1000.0

    # Estimated ground elevation = UAV altitude - mean LIDAR distance
    ground_elev = alts - mean_dists

    print(f"LIDAR terrain profile:")
    print(f"  Scans:         {len(lats)}")
    print(f"  Lat range:     {lats.min():.5f} → {lats.max():.5f}")
    print(f"  Lon range:     {lons.min():.5f} → {lons.max():.5f}")
    print(f"  Alt range:     {alts.min():.1f} → {alts.max():.1f} m AGL")
    print(f"  Mean dist:     {mean_dists.mean():.2f} m")
    print(f"  Min dist:      {min_dists.min():.2f} m")
    print(f"  Ground elev:   {ground_elev.mean():.2f} m (est.)")

    return {
        "lat":        lats,
        "lon":        lons,
        "alt":        alts,
        "mean_dist":  mean_dists,
        "min_dist":   min_dists,
        "ground_elev":ground_elev,
        "timestamps": timestamps,
        "all_points": all_points,
    }


def save_lidar_map(terrain: dict, output_path: str):
    """Save processed LIDAR terrain data to NPZ."""
    np.savez(
        output_path,
        lat         = terrain["lat"],
        lon         = terrain["lon"],
        alt         = terrain["alt"],
        mean_dist   = terrain["mean_dist"],
        min_dist    = terrain["min_dist"],
        ground_elev = terrain["ground_elev"],
    )
    print(f"LIDAR map saved: {output_path}.npz")


def process(input_path: str, output_dir: str) -> dict:
    """Full LIDAR processing pipeline."""
    print(f"\n── LIDAR Processor ───────────────────────────")
    print(f"Input:  {input_path}")

    records = load_lidar_log(input_path)
    if not records:
        print("No valid records — aborting")
        return None

    terrain = build_terrain_profile(records)

    base = os.path.splitext(os.path.basename(input_path))[0]
    base = base.replace("lidar_", "lidar_map_")
    output_path = os.path.join(output_dir, base)

    os.makedirs(output_dir, exist_ok=True)
    save_lidar_map(terrain, output_path)

    return {"terrain": terrain, "output_path": output_path + ".npz"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RAVEN LIDAR Post-Processor")
    parser.add_argument("input", help="LIDAR log JSONL file")
    parser.add_argument("--output-dir", default="data/processed",
                        help="Output directory")
    args = parser.parse_args()
    process(args.input, args.output_dir)
