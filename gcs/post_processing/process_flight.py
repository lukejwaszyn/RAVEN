"""
RAVEN Post-Processing — Master Flight Processor
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Master script that runs the full post-processing pipeline
on a completed flight's data logs.

Usage:
    python process_flight.py --rf data/rf_logs/rf_log_20260601T120000Z.jsonl \
                             --lidar data/lidar_logs/lidar_20260601T120000Z.jsonl

Or auto-detect most recent logs:
    python process_flight.py --latest

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import os
import sys
import argparse
import glob
from datetime import datetime

# Add src to path
sys.path.insert(0, os.path.dirname(__file__))

import rf_processor
import lidar_processor
import fuse


def find_latest(log_dir: str, prefix: str) -> str:
    """Find the most recently modified log file matching prefix."""
    pattern = os.path.join(log_dir, f"{prefix}*.jsonl")
    files   = glob.glob(pattern)
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def run_pipeline(rf_log: str, lidar_log: str, output_dir: str):
    print("=" * 60)
    print("RAVEN POST-PROCESSING PIPELINE")
    print(f"Started: {datetime.now().strftime('%Y-%m-%dT%H:%M:%S')}")
    print("=" * 60)

    # Step 1 — RF processing
    rf_result = rf_processor.process(rf_log, output_dir)
    if rf_result is None:
        print("RF processing failed — aborting")
        sys.exit(1)

    # Step 2 — LIDAR processing
    li_result = lidar_processor.process(lidar_log, output_dir)
    if li_result is None:
        print("LIDAR processing failed — aborting")
        sys.exit(1)

    # Step 3 — Fusion
    png = fuse.process(
        rf_result["output_path"],
        li_result["output_path"],
        output_dir
    )

    print("\n" + "=" * 60)
    print("PIPELINE COMPLETE")
    print(f"Primary deliverable: {png}")
    print("=" * 60)
    return png


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="RAVEN Flight Post-Processing Pipeline"
    )
    parser.add_argument("--rf",     help="RF log JSONL file")
    parser.add_argument("--lidar",  help="LIDAR log JSONL file")
    parser.add_argument("--latest", action="store_true",
                        help="Auto-detect most recent log files")
    parser.add_argument("--output-dir", default="data/processed",
                        help="Output directory")
    args = parser.parse_args()

    if args.latest:
        rf_log    = find_latest("data/rf_logs",    "rf_log_")
        lidar_log = find_latest("data/lidar_logs", "lidar_")
        if not rf_log:
            print("No RF log found in data/rf_logs/")
            sys.exit(1)
        if not lidar_log:
            print("No LIDAR log found in data/lidar_logs/")
            sys.exit(1)
        print(f"Auto-detected RF log:    {rf_log}")
        print(f"Auto-detected LIDAR log: {lidar_log}")
    elif args.rf and args.lidar:
        rf_log    = args.rf
        lidar_log = args.lidar
    else:
        parser.print_help()
        sys.exit(1)

    run_pipeline(rf_log, lidar_log, args.output_dir)
