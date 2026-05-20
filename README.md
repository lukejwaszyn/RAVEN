# RAVEN
## Reconnaissance Autonomous Vehicle with Electronic iNtelligence

**Luke J. Waszyn II | Penn State Engineering Science | May 2026**

UNCLASSIFIED // FOR TRAINING PURPOSES ONLY

---

## Overview

RAVEN is a low-cost autonomous reconnaissance UAV platform integrating a software-defined radio payload and LIDAR sensor, commanded from a MacBook ground control station. The system demonstrates end-to-end SDR deployment in a constrained mobile environment and produces georeferenced RF and terrain data as primary outputs.

This is not purely a UAV build. The contribution is the architecture: a reusable autonomous daemon framework, a sensor fusion pipeline, a DoD-standard ground control interface, and a model-based systems engineering baseline derived from a verified satellite ground station codebase. The UAV is the platform. The system is the deliverable.

RAVEN is chapter two of a three-part research arc:

- **Chapter 1:** Autonomous Satellite Ground Station (ASGS) -- end-to-end SDR signal chain, autonomous operation, custom decoders, 3D HMI
- **Chapter 2:** RAVEN -- SDR architecture deployed on a mobile airborne platform, LIDAR sensor fusion, georeferenced data collection, autonomous flight
- **Chapter 3:** Senior Thesis -- SDR Lunar Penetrating Radar (2026-27)

---

## System Architecture

RAVEN is a two-segment system with a defined data link interface between them.

```
Ground Control Segment (GCS)          Data Link          Aerial Vehicle Segment (AVS)
MacBook Air M4                        WiFi primary       Raspberry Pi 5 4GB
  GCS Daemon (Python)           <-------------------->     UAV Daemon (Python)
  MAVLink Module                      RFD900x            MAVLink Bridge (UART)
  SDR Module                          contingency        rtl_tcp Server
  FM Audio Demodulator                                   LIDAR Driver (RPLidar A1M8)
  Post-Processing Pipeline                               GPSd Client
  Three.js HMI (DoD standard)                            RTL-SDR Blog V4
```

### RF Chain

```
Antenna -> RTL-SDR v4 -> USB -> Pi -> rtl_tcp -> WiFi -> GCS -> FFT -> HMI waterfall
```

### LIDAR Chain

```
RPLidar A1M8 -> USB -> Pi -> timestamped point cloud -> GPSd tag -> post-process on Mac
```

### MAVLink Chain

```
Pixhawk 6C Mini <-> UART <-> Pi MAVLink Bridge <-> WiFi <-> GCS MAVLink Module <-> HMI
```

---

## MBSE Approach

RAVEN is developed under a model-based systems engineering methodology following the V-shaped life cycle model.

### Requirements (MATLAB Requirements Toolbox)

71 formally traced requirements across 12 subsystems with full ID scheme, custom attributes, and parent-child traceability. Requirements are authored programmatically and stored as `.slreqx` for version control.

ID structure: `[SEGMENT]-[SUBSYSTEM]-[TYPE]-[NUMBER]`

Example: `AVS-LI-PR-002` -- The LIDAR subsystem shall operate at a minimum scan frequency of 5.5 Hz.

Types: Functional (FR), Performance (PR), Interface (IR)

Segments: SYS, GCS-MC, GCS-FT, GCS-DP, AVS-ST, AVS-PR, AVS-FC, AVS-CP, AVS-RF, AVS-LI, AVS-PW, DL

### Architecture (MATLAB System Composer)

Full L0 to L2 system architecture model in CamelCase naming convention.

- **L0:** RAVEN system boundary -- GroundControlSegment, AerialVehicleSegment, DataLink
- **L1:** Segment decomposition -- MissionControl, FlightTelemetry, DataProcessing, FlightControl, FlightComputer, RfSdr, Lidar, Power, Structures, Propulsion
- **L2:** Component level -- RaspberryPi5, UavDaemon, RtlTcpServer, LidarDriver, GpsDaemon, MavlinkBridge, Pixhawk6cMini, ArduPilot, RtlSdrV4, RplidarA1M8, LipoBattery4S, F450Frame, and more

### Simulation (MATLAB Simulink + UAV Toolbox)

Simulink digital twin of the F450 quadrotor using UAV Toolbox native blocks:

- UAV Scenario Configuration -- 3D environment setup
- Waypoint Follower + Path Manager -- autonomous mission execution
- GPS, INS, Barometer -- sensor simulation with realistic noise models
- UAV Scenario Lidar -- full 3D pointcloud simulation
- UAV Scenario Scope -- 3D visualization (Unreal Engine integration)
- Data Logger -- outputs match real flight log format for post-processing pipeline

V&V pre-check results against requirements:

| Requirement | Description | Value | Threshold | Status |
|---|---|---|---|---|
| SYS-PR-001 | Flight endurance | 13.2 min | >= 10 min | PASS |
| AVS-PR-PR-001 | T/W ratio | 29.40 | >= 2.0 | PASS |
| AVS-LI-PR-002 | LIDAR scan rate | 5.5 Hz | >= 5.5 Hz | PASS |
| SYS-PR-002 | Link latency | 20 ms | <= 500 ms | PASS |

---

## Hardware

| Component | Part | Status |
|---|---|---|
| Frame | F450 quadcopter frame | To order |
| Motors x4 | 2212 920KV brushless | To order |
| ESCs x4 | 30A BLHeli | To order |
| Flight Controller | Pixhawk 6C Mini | To order |
| Companion Computer | CanaKit Pi 5 4GB | Owned |
| LIDAR | RPLidar A1M8 | To order |
| Battery | 4S 3300mAh LiPo | To order |
| Charger | iSDT Q6 Plus | To order |
| Travel Router | GL.iNet GL-MT300N-V2 | To order |
| SDR | RTL-SDR Blog V4 | Owned |

---

## Software Stack

| Layer | Tools |
|---|---|
| MBSE | MATLAB System Composer, Requirements Toolbox, Simulink, UAV Toolbox |
| Flight control | ArduPilot, QGroundControl, MAVLink |
| SDR | rtl_tcp, RTL-SDR Blog fork, GNU Radio |
| LIDAR | RPLidar SDK (Python) |
| GPS | GPSd |
| GCS | Python (aiohttp, pymavlink, numpy, scipy) |
| HMI | JavaScript, Three.js, Leaflet.js, Web Audio API |
| Post-processing | Python, NumPy, SciPy, matplotlib |
| Dev environment | macOS M4, cross-compile to Pi via SSH |

---

## Repository Structure

```
RAVEN/
├── matlab/
│   ├── requirements/       # MATLAB Requirements Toolbox (.slreqx + build script)
│   ├── architecture/       # System Composer architecture model (.slx)
│   └── simulink/           # UAV flight dynamics simulation (.slx)
├── gcs/
│   ├── src/                # GCS daemon, MAVLink module, SDR module, audio stream
│   ├── hmi/                # Three.js ground control display (index.html)
│   ├── config/             # GCS configuration (config.json)
│   └── post_processing/    # RF processor, LIDAR processor, fusion pipeline
├── pi/
│   ├── src/                # AVS daemon (uav_daemon.py)
│   └── config/             # Pi configuration (pi_config.json)
├── data/
│   ├── rf_logs/            # Georeferenced RF JSONL logs (gitignored)
│   ├── lidar_logs/         # Timestamped LIDAR JSONL logs (gitignored)
│   └── processed/          # Fused data products (PNG, PDF, NPZ)
└── docs/
    ├── conops/             # Concept of Operations
    ├── requirements/       # Requirements documentation
    ├── architecture/       # Architecture diagrams
    └── verification/       # V&V results
```

---

## Ground Control Station

The GCS is a single-operator interface designed to MIL-STD-1472 human factors principles.

Features:
- Classification banner (top and bottom) per DoD standard
- Red/amber/green alert hierarchy per MIL-STD-1472
- Live MAVLink telemetry -- position, altitude, heading, battery, GPS fix, flight mode, armed state
- OpenStreetMap mission map with user geolocation -- centers on operator position automatically
- Click-to-place waypoint planner with altitude control per waypoint
- Live RF spectrum waterfall -- 1024-point FFT from RTL-SDR
- FM audio demodulation -- server-side IQ to PCM, streamed to browser via Web Audio API
- Frequency tuning and gain control from HMI
- Band presets -- FM, VHF Air, Marine, ISM 433, ISM 915
- Abort/RTL command with confirmation dialog
- Uptime, mission status, alert ticker

To run:

```bash
cd ~/RAVEN
source venv/bin/activate
python gcs/src/gcs_daemon.py
# Open http://localhost:8080
```

---

## AVS Daemon

Runs headless on the Raspberry Pi 5. Four concurrent async tasks:

- **MAVLink Bridge** -- forwards MAVLink between Pixhawk UART and GCS WiFi. Configurable for serial (flight) or TCP (SITL bench testing).
- **rtl_tcp Manager** -- launches and monitors the rtl_tcp SDR server process. Auto-restarts on failure.
- **LIDAR Driver** -- RPLidar A1M8 SDK integration. Falls back to synthetic stub mode when hardware is absent for software testing.
- **GPSd Client** -- reads GPS coordinates from GPSd, tags all sensor data with position.

To run on Pi:

```bash
python3 ~/RAVEN/pi/src/uav_daemon.py
```

For SITL bench testing, set `mavlink.connection = "tcp"` and `mavlink.sitl_host` to the GCS Mac IP in `pi_config.json`.

---

## Post-Processing Pipeline

Runs on the Mac after each flight. Produces the primary research deliverable.

```bash
# Process most recent flight logs
python gcs/post_processing/process_flight.py --latest

# Process specific logs
python gcs/post_processing/process_flight.py \
    --rf data/rf_logs/rf_log_TIMESTAMP.jsonl \
    --lidar data/lidar_logs/lidar_TIMESTAMP.jsonl
```

Output: Six-panel fused data product (PNG + PDF) showing RF signal map, terrain profile, fused RF+terrain overlay, RF signal vs distance, LIDAR distance vs altitude, and mission summary.

---

## Verification Milestones

| Milestone | Description | Pass Criterion | Status |
|---|---|---|---|
| V0 | Pi + RTL-SDR bench | rtl_tcp streams IQ to MacBook | PASS |
| V1 | Pi + LIDAR bench | Point cloud logged with timestamps | Pending hardware |
| V1.5 | Pi + GPS bench | GPSd outputs valid coordinates | PASS (GPSd installed) |
| V2 | GCS daemon running | MacBook commands Pi, telemetry returns | PASS |
| V2.5 | Frame + FC + motors bench | ArduPilot arms, all motors spin | Pending hardware |
| V3 | First untethered hover | Stable hover, RC control confirmed | Pending hardware |
| V3.5 | Payload integration | All sensors active during hover | Pending hardware |
| V4 | First autonomous waypoint flight | UAV executes path, returns home | Pending hardware |
| V5 | First data flight | Georeferenced RF + LIDAR logged | Pending hardware |
| V6 | Fused data product | RF map overlaid on terrain | PASS (synthetic data) |

---

## MATLAB Dependencies

Developed on MATLAB R2025b.

- System Composer 25.2
- Requirements Toolbox 25.2
- Simulink 25.2
- UAV Toolbox 25.2
- Aerospace Blockset 25.2
- Navigation Toolbox 25.2

---

## Python Dependencies

```bash
pip install pymavlink aiohttp numpy scipy matplotlib
```

Pi additional:

```bash
pip3 install pymavlink rplidar-roboticia --break-system-packages
```

---

## Research Context

RAVEN demonstrates reusable system architecture across a coherent research program. The through-line is explicit: mobile platform, downward sensor, georeferenced collection, post-processed data product. Each chapter adds interface complexity and instrument sophistication. The senior thesis on SDR Lunar Penetrating Radar applies the same architecture to a scientific instrument on a moving platform -- the UAV is the terrestrial analog.

The MBSE treatment -- formal requirements, System Composer architecture, Simulink simulation with UAV Toolbox -- elevates this from a student build to a junior defense contractor workflow, validated simultaneously through MBSE work with a General Atomics principal systems engineer.

---

## Deliverables

- [x] Working autonomous UAV GCS with DoD-standard HMI
- [x] Live MAVLink telemetry pipeline
- [x] Live SDR spectrum + FM audio demodulation
- [x] Waypoint mission planning and upload
- [x] AVS companion computer daemon
- [x] Post-processing fusion pipeline
- [x] Fused RF + terrain data product
- [x] 71 formally traced requirements (MATLAB Requirements Toolbox)
- [x] L0-L2 System Composer architecture
- [x] Simulink digital twin
- [ ] Physical UAV build (hardware pending)
- [ ] Verified autonomous data flight (V4-V6)
- [ ] Published technical report

---

*UNCLASSIFIED // FOR TRAINING PURPOSES ONLY*
