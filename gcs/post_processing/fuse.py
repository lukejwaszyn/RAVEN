"""
RAVEN Post-Processing — Data Fusion Pipeline
Reconnaissance Autonomous Vehicle with Electronic iNtelligence

Fuses georeferenced RF and LIDAR data into the primary mission deliverable:
    RF signal strength map overlaid on terrain profile

Pipeline:
    1. Load RF map (NPZ) and LIDAR terrain (NPZ)
    2. Spatially align by GPS coordinates
    3. Generate fused visualization:
        - Top view: RF heatmap overlaid on flight path
        - Side view: terrain profile with RF intensity coloring
        - 3D scatter: georeferenced point cloud colored by RF power
    4. Export publication-quality figures

Output: data/processed/fused_YYYYMMDDTHHMMSSZ.png (and .pdf)

Requirement: GCS-DP-FR-003 — fused RF + LIDAR data product
Requirement: SYS-FR-002   — georeferenced fused data product as primary output

Author: Luke J. Waszyn II | Penn State Engineering Science
"""

import os
import sys
import numpy as np
import argparse
from datetime import datetime

import matplotlib
matplotlib.use("Agg")  # Non-interactive backend for headless execution
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.colors import Normalize
from matplotlib.cm import ScalarMappable
from scipy.interpolate import griddata


# ── Plot Style ────────────────────────────────────────────────────────────────
plt.rcParams.update({
    "figure.facecolor":  "#080c0f",
    "axes.facecolor":    "#0d1318",
    "axes.edgecolor":    "#1a2d3d",
    "axes.labelcolor":   "#c8dce8",
    "axes.titlecolor":   "#c8dce8",
    "xtick.color":       "#4a6272",
    "ytick.color":       "#4a6272",
    "text.color":        "#c8dce8",
    "grid.color":        "#1a2d3d",
    "grid.alpha":        0.5,
    "font.family":       "monospace",
    "font.size":         9,
})


def load_rf(path: str) -> dict:
    data = np.load(path)
    print(f"RF map loaded: {len(data['lat'])} points")
    return dict(data)


def load_lidar(path: str) -> dict:
    data = np.load(path)
    print(f"LIDAR map loaded: {len(data['lat'])} scans")
    return dict(data)


def spatial_align(rf: dict, lidar: dict) -> dict:
    """
    Align RF and LIDAR data by interpolating onto common GPS positions.
    Uses LIDAR scan positions as the reference grid.
    Interpolates RF signal strength to each LIDAR scan position.
    """
    if len(rf["lat"]) < 4 or len(lidar["lat"]) < 4:
        print("Insufficient data for spatial alignment")
        return None

    # Interpolate RF peak_db to LIDAR positions
    rf_points  = np.column_stack([rf["lon"], rf["lat"]])
    li_points  = np.column_stack([lidar["lon"], lidar["lat"]])

    rf_at_lidar = griddata(
        rf_points, rf["peak_db"],
        li_points, method="linear"
    )

    # Fill NaN with nearest neighbor for edge points
    nan_mask = np.isnan(rf_at_lidar)
    if nan_mask.any():
        rf_nearest = griddata(
            rf_points, rf["peak_db"],
            li_points[nan_mask], method="nearest"
        )
        rf_at_lidar[nan_mask] = rf_nearest

    print(f"Spatial alignment: {np.sum(~np.isnan(rf_at_lidar))}/{len(lidar['lat'])} points fused")

    return {
        "lat":          lidar["lat"],
        "lon":          lidar["lon"],
        "alt":          lidar["alt"],
        "ground_elev":  lidar["ground_elev"],
        "mean_dist":    lidar["mean_dist"],
        "rf_peak_db":   rf_at_lidar,
    }


def generate_fused_figure(rf: dict, lidar: dict, fused: dict,
                           output_path: str, mission_ts: str):
    """
    Generate the primary fused data product figure.
    Four panel layout:
        [0] RF signal map (top view, heatmap)
        [1] Terrain profile (side view, elevation)
        [2] Fused RF+terrain (color = RF, height = terrain)
        [3] Mission summary stats
    """
    fig = plt.figure(figsize=(16, 10), facecolor="#080c0f")
    fig.suptitle(
        f"RAVEN — Fused RF + Terrain Data Product\n"
        f"Mission: {mission_ts}  |  UNCLASSIFIED // FOR TRAINING PURPOSES ONLY",
        color="#c8dce8", fontsize=10, fontfamily="monospace", y=0.98
    )

    gs = gridspec.GridSpec(2, 3, figure=fig, hspace=0.35, wspace=0.3,
                           left=0.07, right=0.95, top=0.92, bottom=0.06)

    # ── Panel 0: RF Signal Map (top view) ────────────────────────────────────
    ax0 = fig.add_subplot(gs[0, 0])
    ax0.set_title("RF SIGNAL MAP", fontsize=8, color="#00b0ff")

    if "grid_db" in rf and rf["grid_db"] is not None:
        im = ax0.imshow(
            rf["grid_db"],
            extent=[rf["lon_grid"].min(), rf["lon_grid"].max(),
                    rf["lat_grid"].min(), rf["lat_grid"].max()],
            origin="lower", aspect="auto",
            cmap="plasma", vmin=-60, vmax=40
        )
        plt.colorbar(im, ax=ax0, label="dBm", shrink=0.8)
    else:
        sc = ax0.scatter(rf["lon"], rf["lat"], c=rf["peak_db"],
                         cmap="plasma", s=8, vmin=-60, vmax=40)
        plt.colorbar(sc, ax=ax0, label="dBm", shrink=0.8)

    # Flight path overlay
    ax0.plot(rf["lon"], rf["lat"], "w-", linewidth=0.5, alpha=0.4, label="Flight path")
    ax0.set_xlabel("Longitude")
    ax0.set_ylabel("Latitude")
    ax0.grid(True)

    # ── Panel 1: Terrain Profile (side view) ─────────────────────────────────
    ax1 = fig.add_subplot(gs[0, 1])
    ax1.set_title("TERRAIN PROFILE", fontsize=8, color="#00e676")

    # Distance along track
    lats = lidar["lat"]
    lons = lidar["lon"]
    if len(lats) > 1:
        dlat = np.diff(lats) * 111320  # degrees to meters
        dlon = np.diff(lons) * 111320 * np.cos(np.radians(lats[:-1]))
        dist = np.concatenate([[0], np.cumsum(np.sqrt(dlat**2 + dlon**2))])
    else:
        dist = np.zeros(len(lats))

    ax1.fill_between(dist, lidar["ground_elev"], alpha=0.4,
                     color="#00e676", label="Ground estimate")
    ax1.plot(dist, lidar["alt"], color="#00b0ff",
             linewidth=1.5, label="UAV altitude")
    ax1.plot(dist, lidar["ground_elev"], color="#00e676", linewidth=1)
    ax1.set_xlabel("Distance along track (m)")
    ax1.set_ylabel("Elevation (m AGL)")
    ax1.legend(fontsize=7)
    ax1.grid(True)

    # ── Panel 2: Fused RF + Terrain ───────────────────────────────────────────
    ax2 = fig.add_subplot(gs[0, 2])
    ax2.set_title("FUSED RF + TERRAIN", fontsize=8, color="#ffc107")

    if fused is not None:
        valid = ~np.isnan(fused["rf_peak_db"])
        if valid.any():
            # Color by RF power, size by terrain distance
            norm    = Normalize(vmin=-60, vmax=40)
            cmap    = plt.cm.plasma
            colors  = cmap(norm(fused["rf_peak_db"][valid]))
            sizes   = np.clip(20 / (fused["mean_dist"][valid] + 1), 2, 20)

            sc2 = ax2.scatter(
                fused["lon"][valid], fused["lat"][valid],
                c=fused["rf_peak_db"][valid],
                s=sizes, cmap="plasma", vmin=-60, vmax=40, alpha=0.8
            )
            plt.colorbar(sc2, ax=ax2, label="RF (dBm)", shrink=0.8)
            ax2.set_xlabel("Longitude")
            ax2.set_ylabel("Latitude")
            ax2.set_title("FUSED RF + TERRAIN\n(size = terrain proximity)",
                          fontsize=7, color="#ffc107")
    ax2.grid(True)

    # ── Panel 3: RF time series ───────────────────────────────────────────────
    ax3 = fig.add_subplot(gs[1, 0])
    ax3.set_title("RF SIGNAL vs DISTANCE", fontsize=8, color="#00b0ff")

    if len(rf["lat"]) > 1:
        dlat_rf = np.diff(rf["lat"]) * 111320
        dlon_rf = np.diff(rf["lon"]) * 111320 * np.cos(np.radians(rf["lat"][:-1]))
        dist_rf = np.concatenate([[0], np.cumsum(np.sqrt(dlat_rf**2 + dlon_rf**2))])
        ax3.plot(dist_rf, rf["peak_db"],   color="#00b0ff", linewidth=1, label="Peak")
        ax3.plot(dist_rf, rf["mean_db"],   color="#00e676", linewidth=0.8,
                 alpha=0.7, label="Mean")
        ax3.plot(dist_rf, rf["noise_floor"], color="#ff1744", linewidth=0.8,
                 alpha=0.5, label="Noise floor")
        ax3.fill_between(dist_rf, rf["noise_floor"], rf["peak_db"],
                         alpha=0.15, color="#00b0ff")
        ax3.set_xlabel("Distance along track (m)")
        ax3.set_ylabel("Power (dBm)")
        ax3.legend(fontsize=7)
        ax3.grid(True)

    # ── Panel 4: Terrain distance vs altitude ─────────────────────────────────
    ax4 = fig.add_subplot(gs[1, 1])
    ax4.set_title("LIDAR DISTANCE vs ALTITUDE", fontsize=8, color="#00e676")

    if len(lidar["alt"]) > 0:
        sc4 = ax4.scatter(lidar["alt"], lidar["mean_dist"],
                          c=lidar["alt"], cmap="viridis", s=6, alpha=0.7)
        plt.colorbar(sc4, ax=ax4, label="Altitude (m)", shrink=0.8)
        ax4.set_xlabel("UAV Altitude AGL (m)")
        ax4.set_ylabel("Mean LIDAR distance (m)")
        ax4.grid(True)

    # ── Panel 5: Mission summary ───────────────────────────────────────────────
    ax5 = fig.add_subplot(gs[1, 2])
    ax5.set_title("MISSION SUMMARY", fontsize=8, color="#c8dce8")
    ax5.axis("off")

    summary_lines = [
        ("PROGRAM",         "RAVEN"),
        ("MISSION DATE",    mission_ts[:10]),
        ("RF POINTS",       str(len(rf["lat"]))),
        ("LIDAR SCANS",     str(len(lidar["lat"]))),
        ("PEAK SIGNAL",     f"{rf['peak_db'].max():.1f} dBm"),
        ("NOISE FLOOR",     f"{rf['noise_floor'].mean():.1f} dBm"),
        ("MAX SNR",         f"{rf['snr'].max():.1f} dB"),
        ("UAV ALT (avg)",   f"{lidar['alt'].mean():.1f} m"),
        ("TERRAIN DIST",    f"{lidar['mean_dist'].mean():.1f} m"),
        ("CLASSIFICATION",  "UNCLASSIFIED"),
    ]

    y = 0.95
    for label, value in summary_lines:
        ax5.text(0.02, y, f"{label}:", color="#4a6272",
                 fontsize=8, transform=ax5.transAxes)
        ax5.text(0.52, y, value, color="#c8dce8",
                 fontsize=8, transform=ax5.transAxes)
        y -= 0.09

    # Save
    png_path = output_path + ".png"
    pdf_path = output_path + ".pdf"
    fig.savefig(png_path, dpi=150, bbox_inches="tight", facecolor="#080c0f")
    fig.savefig(pdf_path, bbox_inches="tight", facecolor="#080c0f")
    plt.close(fig)

    print(f"Fused figure saved: {png_path}")
    print(f"Fused figure saved: {pdf_path}")
    return png_path


def process(rf_path: str, lidar_path: str, output_dir: str):
    """Full fusion pipeline."""
    print(f"\n── RAVEN Data Fusion Pipeline ────────────────")
    print(f"RF:    {rf_path}")
    print(f"LIDAR: {lidar_path}")
    print(f"Output: {output_dir}")

    rf    = load_rf(rf_path)
    lidar = load_lidar(lidar_path)
    fused = spatial_align(rf, lidar)

    # Output filename
    ts = datetime.now().strftime("%Y%m%dT%H%M%S")
    output_path = os.path.join(output_dir, f"fused_{ts}")
    os.makedirs(output_dir, exist_ok=True)

    # Extract mission timestamp from RF path
    base = os.path.basename(rf_path)
    mission_ts = base.replace("rf_map_", "").replace(".npz", "")

    png = generate_fused_figure(rf, lidar, fused, output_path, mission_ts)
    print(f"\n✓ Fusion complete — {png}")
    return png


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RAVEN Data Fusion Pipeline")
    parser.add_argument("rf_map",    help="Processed RF map NPZ file")
    parser.add_argument("lidar_map", help="Processed LIDAR map NPZ file")
    parser.add_argument("--output-dir", default="data/processed",
                        help="Output directory for fused product")
    args = parser.parse_args()
    process(args.rf_map, args.lidar_map, args.output_dir)
