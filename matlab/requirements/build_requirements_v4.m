% RAVEN Requirements — Programmatic Author Script
% Reconnaissance Autonomous Vehicle with Electronic iNtelligence
% Generated May 2026 | 71 requirements
% Run from /Users/lukewaszyn/RAVEN/ with MATLAB project open

slreq.clear

rs = slreq.new('RAVEN_Requirements');
save(rs, '/Users/lukewaszyn/RAVEN/matlab/requirements/RAVEN_Requirements.slreqx');

addAttribute(rs, 'Scope',     'Edit');
addAttribute(rs, 'Status',    'Edit');
addAttribute(rs, 'ReqParent', 'Edit');
addAttribute(rs, 'Section',   'Edit');

% ── SYS — Top Level ──
sec01 = add(rs, 'Type', 'Container', 'Summary', 'System Requirements');

% SYS-FR-001
req001 = add(sec01, ...
    'Summary',     'RAVEN shall autonomously execute a predefined reconnaissance mission along a programmable waypoint path without continuous operator input.', ...
    'Description', 'RAVEN shall autonomously execute a predefined reconnaissance mission along a programmable waypoint path without continuous operator input.');
setAttribute(req001, 'Scope',     '[SYSTEM]');
setAttribute(req001, 'Status',    'APPROVED');
setAttribute(req001, 'ReqParent', 'MISSION');
setAttribute(req001, 'Section',   'System Requirements');
req001.Id = 'SYS-FR-001';

% SYS-FR-002
req002 = add(sec01, ...
    'Summary',     'RAVEN shall produce a georeferenced fused data product combining RF spectrum data and LIDAR terrain mapping as the primary mission output.', ...
    'Description', 'RAVEN shall produce a georeferenced fused data product combining RF spectrum data and LIDAR terrain mapping as the primary mission output.');
setAttribute(req002, 'Scope',     '[SYSTEM]');
setAttribute(req002, 'Status',    'APPROVED');
setAttribute(req002, 'ReqParent', 'MISSION');
setAttribute(req002, 'Section',   'System Requirements');
req002.Id = 'SYS-FR-002';

% SYS-FR-003
req003 = add(sec01, ...
    'Summary',     'RAVEN shall operate as a two-segment system consisting of a Ground Control Segment and an Aerial Vehicle Segment communicating over a defined data link.', ...
    'Description', 'RAVEN shall operate as a two-segment system consisting of a Ground Control Segment and an Aerial Vehicle Segment communicating over a defined data link.');
setAttribute(req003, 'Scope',     '[SYSTEM]');
setAttribute(req003, 'Status',    'APPROVED');
setAttribute(req003, 'ReqParent', 'MISSION');
setAttribute(req003, 'Section',   'System Requirements');
req003.Id = 'SYS-FR-003';

% SYS-PR-001
req004 = add(sec01, ...
    'Summary',     'RAVEN shall sustain autonomous flight for a minimum of 10 minutes under nominal operating conditions, with an objective of 20 minutes.', ...
    'Description', 'RAVEN shall sustain autonomous flight for a minimum of 10 minutes under nominal operating conditions, with an objective of 20 minutes.');
setAttribute(req004, 'Scope',     '[SYSTEM]');
setAttribute(req004, 'Status',    'APPROVED');
setAttribute(req004, 'ReqParent', 'MISSION');
setAttribute(req004, 'Section',   'System Requirements');
req004.Id = 'SYS-PR-001';

% SYS-PR-002
req005 = add(sec01, ...
    'Summary',     'RAVEN shall maintain end-to-end command and telemetry latency not exceeding 500ms under nominal link conditions.', ...
    'Description', 'RAVEN shall maintain end-to-end command and telemetry latency not exceeding 500ms under nominal link conditions.');
setAttribute(req005, 'Scope',     '[SYSTEM]');
setAttribute(req005, 'Status',    'APPROVED');
setAttribute(req005, 'ReqParent', 'MISSION');
setAttribute(req005, 'Section',   'System Requirements');
req005.Id = 'SYS-PR-002';

% SYS-IR-001
req006 = add(sec01, ...
    'Summary',     'RAVEN shall provide a single-operator ground control interface capable of commanding, monitoring, and terminating a mission from one workstation.', ...
    'Description', 'RAVEN shall provide a single-operator ground control interface capable of commanding, monitoring, and terminating a mission from one workstation.');
setAttribute(req006, 'Scope',     '[SYSTEM]');
setAttribute(req006, 'Status',    'APPROVED');
setAttribute(req006, 'ReqParent', 'MISSION');
setAttribute(req006, 'Section',   'System Requirements');
req006.Id = 'SYS-IR-001';


% ── GCS-MC — Mission Control ──
sec02 = add(rs, 'Type', 'Container', 'Summary', 'GCS Mission Control');

% GCS-MC-FR-001
req007 = add(sec02, ...
    'Summary',     'The Mission Control subsystem shall provide a mission planning interface enabling the operator to define, modify, and upload waypoint paths to the AVS prior to flight.', ...
    'Description', 'The Mission Control subsystem shall provide a mission planning interface enabling the operator to define, modify, and upload waypoint paths to the AVS prior to flight.');
setAttribute(req007, 'Scope',     '[GCS]');
setAttribute(req007, 'Status',    'APPROVED');
setAttribute(req007, 'ReqParent', 'SYS-FR-001');
setAttribute(req007, 'Section',   'GCS Mission Control');
req007.Id = 'GCS-MC-FR-001';

% GCS-MC-FR-002
req008 = add(sec02, ...
    'Summary',     'The Mission Control subsystem shall execute autonomous mission logic including waypoint sequencing, loiter commands, and return-to-launch without continuous operator input.', ...
    'Description', 'The Mission Control subsystem shall execute autonomous mission logic including waypoint sequencing, loiter commands, and return-to-launch without continuous operator input.');
setAttribute(req008, 'Scope',     '[GCS]');
setAttribute(req008, 'Status',    'APPROVED');
setAttribute(req008, 'ReqParent', 'SYS-FR-001');
setAttribute(req008, 'Section',   'GCS Mission Control');
req008.Id = 'GCS-MC-FR-002';

% GCS-MC-FR-003
req009 = add(sec02, ...
    'Summary',     'The Mission Control subsystem shall monitor AVS system state and alert the operator to any off-nominal condition during flight.', ...
    'Description', 'The Mission Control subsystem shall monitor AVS system state and alert the operator to any off-nominal condition during flight.');
setAttribute(req009, 'Scope',     '[GCS]');
setAttribute(req009, 'Status',    'APPROVED');
setAttribute(req009, 'ReqParent', 'SYS-IR-001');
setAttribute(req009, 'Section',   'GCS Mission Control');
req009.Id = 'GCS-MC-FR-003';

% GCS-MC-FR-004
req010 = add(sec02, ...
    'Summary',     'The Mission Control subsystem shall provide a mission abort command that triggers immediate return-to-launch on the AVS.', ...
    'Description', 'The Mission Control subsystem shall provide a mission abort command that triggers immediate return-to-launch on the AVS.');
setAttribute(req010, 'Scope',     '[GCS]');
setAttribute(req010, 'Status',    'APPROVED');
setAttribute(req010, 'ReqParent', 'SYS-IR-001');
setAttribute(req010, 'Section',   'GCS Mission Control');
req010.Id = 'GCS-MC-FR-004';

% GCS-MC-PR-001
req011 = add(sec02, ...
    'Summary',     'The Mission Control subsystem shall display real-time AVS position, altitude, heading, and battery state at a minimum refresh rate of 2 Hz.', ...
    'Description', 'The Mission Control subsystem shall display real-time AVS position, altitude, heading, and battery state at a minimum refresh rate of 2 Hz.');
setAttribute(req011, 'Scope',     '[GCS]');
setAttribute(req011, 'Status',    'APPROVED');
setAttribute(req011, 'ReqParent', 'SYS-PR-002');
setAttribute(req011, 'Section',   'GCS Mission Control');
req011.Id = 'GCS-MC-PR-001';

% GCS-MC-IR-001
req012 = add(sec02, ...
    'Summary',     'The Mission Control subsystem shall interface with the Flight Telemetry subsystem via MAVLink protocol to send commands and receive AVS state data.', ...
    'Description', 'The Mission Control subsystem shall interface with the Flight Telemetry subsystem via MAVLink protocol to send commands and receive AVS state data.');
setAttribute(req012, 'Scope',     '[GCS]');
setAttribute(req012, 'Status',    'APPROVED');
setAttribute(req012, 'ReqParent', 'SYS-FR-003');
setAttribute(req012, 'Section',   'GCS Mission Control');
req012.Id = 'GCS-MC-IR-001';


% ── GCS-FT — Flight Telemetry ──
sec03 = add(rs, 'Type', 'Container', 'Summary', 'GCS Flight Telemetry');

% GCS-FT-FR-001
req013 = add(sec03, ...
    'Summary',     'The Flight Telemetry subsystem shall maintain a bidirectional data link with the AVS for the duration of each mission.', ...
    'Description', 'The Flight Telemetry subsystem shall maintain a bidirectional data link with the AVS for the duration of each mission.');
setAttribute(req013, 'Scope',     '[GCS]');
setAttribute(req013, 'Status',    'APPROVED');
setAttribute(req013, 'ReqParent', 'SYS-FR-003');
setAttribute(req013, 'Section',   'GCS Flight Telemetry');
req013.Id = 'GCS-FT-FR-001';

% GCS-FT-FR-002
req014 = add(sec03, ...
    'Summary',     'The Flight Telemetry subsystem shall detect and annunciate data link loss to the Mission Control subsystem within 1 second of link failure.', ...
    'Description', 'The Flight Telemetry subsystem shall detect and annunciate data link loss to the Mission Control subsystem within 1 second of link failure.');
setAttribute(req014, 'Scope',     '[GCS]');
setAttribute(req014, 'Status',    'APPROVED');
setAttribute(req014, 'ReqParent', 'SYS-FR-003');
setAttribute(req014, 'Section',   'GCS Flight Telemetry');
req014.Id = 'GCS-FT-FR-002';

% GCS-FT-PR-001
req015 = add(sec03, ...
    'Summary',     'The Flight Telemetry subsystem shall sustain command and telemetry throughput sufficient to support MAVLink message rates at no less than 4 Hz.', ...
    'Description', 'The Flight Telemetry subsystem shall sustain command and telemetry throughput sufficient to support MAVLink message rates at no less than 4 Hz.');
setAttribute(req015, 'Scope',     '[GCS]');
setAttribute(req015, 'Status',    'APPROVED');
setAttribute(req015, 'ReqParent', 'SYS-PR-002');
setAttribute(req015, 'Section',   'GCS Flight Telemetry');
req015.Id = 'GCS-FT-PR-001';

% GCS-FT-IR-001
req016 = add(sec03, ...
    'Summary',     'The Flight Telemetry subsystem shall support WiFi as the primary link and shall be configurable to operate over RFD900x radio as a contingency link.', ...
    'Description', 'The Flight Telemetry subsystem shall support WiFi as the primary link and shall be configurable to operate over RFD900x radio as a contingency link.');
setAttribute(req016, 'Scope',     '[GCS]');
setAttribute(req016, 'Status',    'APPROVED');
setAttribute(req016, 'ReqParent', 'SYS-FR-003');
setAttribute(req016, 'Section',   'GCS Flight Telemetry');
req016.Id = 'GCS-FT-IR-001';


% ── GCS-DP — Data Processing ──
sec04 = add(rs, 'Type', 'Container', 'Summary', 'GCS Data Processing');

% GCS-DP-FR-001
req017 = add(sec04, ...
    'Summary',     'The Data Processing subsystem shall ingest RTL-SDR IQ data streamed from the AVS and produce georeferenced RF spectrum snapshots tagged with position and timestamp.', ...
    'Description', 'The Data Processing subsystem shall ingest RTL-SDR IQ data streamed from the AVS and produce georeferenced RF spectrum snapshots tagged with position and timestamp.');
setAttribute(req017, 'Scope',     '[GCS]');
setAttribute(req017, 'Status',    'APPROVED');
setAttribute(req017, 'ReqParent', 'SYS-FR-002');
setAttribute(req017, 'Section',   'GCS Data Processing');
req017.Id = 'GCS-DP-FR-001';

% GCS-DP-FR-002
req018 = add(sec04, ...
    'Summary',     'The Data Processing subsystem shall ingest LIDAR point cloud data from the AVS and produce a georeferenced terrain map.', ...
    'Description', 'The Data Processing subsystem shall ingest LIDAR point cloud data from the AVS and produce a georeferenced terrain map.');
setAttribute(req018, 'Scope',     '[GCS]');
setAttribute(req018, 'Status',    'APPROVED');
setAttribute(req018, 'ReqParent', 'SYS-FR-002');
setAttribute(req018, 'Section',   'GCS Data Processing');
req018.Id = 'GCS-DP-FR-002';

% GCS-DP-FR-003
req019 = add(sec04, ...
    'Summary',     'The Data Processing subsystem shall fuse georeferenced RF data and LIDAR terrain data into a single overlaid data product.', ...
    'Description', 'The Data Processing subsystem shall fuse georeferenced RF data and LIDAR terrain data into a single overlaid data product.');
setAttribute(req019, 'Scope',     '[GCS]');
setAttribute(req019, 'Status',    'APPROVED');
setAttribute(req019, 'ReqParent', 'SYS-FR-002');
setAttribute(req019, 'Section',   'GCS Data Processing');
req019.Id = 'GCS-DP-FR-003';

% GCS-DP-FR-004
req020 = add(sec04, ...
    'Summary',     'The Data Processing subsystem shall display live RF spectrum data received from the AVS during flight.', ...
    'Description', 'The Data Processing subsystem shall display live RF spectrum data received from the AVS during flight.');
setAttribute(req020, 'Scope',     '[GCS]');
setAttribute(req020, 'Status',    'APPROVED');
setAttribute(req020, 'ReqParent', 'SYS-IR-001');
setAttribute(req020, 'Section',   'GCS Data Processing');
req020.Id = 'GCS-DP-FR-004';

% GCS-DP-PR-001
req021 = add(sec04, ...
    'Summary',     'The Data Processing subsystem shall georeference all RF and LIDAR data to within a positional accuracy consistent with the onboard GPS solution.', ...
    'Description', 'The Data Processing subsystem shall georeference all RF and LIDAR data to within a positional accuracy consistent with the onboard GPS solution.');
setAttribute(req021, 'Scope',     '[GCS]');
setAttribute(req021, 'Status',    'APPROVED');
setAttribute(req021, 'ReqParent', 'SYS-FR-002');
setAttribute(req021, 'Section',   'GCS Data Processing');
req021.Id = 'GCS-DP-PR-001';

% GCS-DP-IR-001
req022 = add(sec04, ...
    'Summary',     'The Data Processing subsystem shall receive IQ data via rtl_tcp stream from the AVS Flight Computer over the active data link.', ...
    'Description', 'The Data Processing subsystem shall receive IQ data via rtl_tcp stream from the AVS Flight Computer over the active data link.');
setAttribute(req022, 'Scope',     '[GCS]');
setAttribute(req022, 'Status',    'APPROVED');
setAttribute(req022, 'ReqParent', 'SYS-FR-003');
setAttribute(req022, 'Section',   'GCS Data Processing');
req022.Id = 'GCS-DP-IR-001';

% GCS-DP-IR-002
req023 = add(sec04, ...
    'Summary',     'The Data Processing subsystem shall receive LIDAR point cloud logs from the AVS Flight Computer via post-flight file transfer or live stream over the data link.', ...
    'Description', 'The Data Processing subsystem shall receive LIDAR point cloud logs from the AVS Flight Computer via post-flight file transfer or live stream over the data link.');
setAttribute(req023, 'Scope',     '[GCS]');
setAttribute(req023, 'Status',    'APPROVED');
setAttribute(req023, 'ReqParent', 'SYS-FR-003');
setAttribute(req023, 'Section',   'GCS Data Processing');
req023.Id = 'GCS-DP-IR-002';


% ── AVS-ST — Structures ──
sec05 = add(rs, 'Type', 'Container', 'Summary', 'AVS Structures');

% AVS-ST-FR-001
req024 = add(sec05, ...
    'Summary',     'The Structures subsystem shall provide a rigid airframe capable of supporting all AVS subsystems including flight controller, flight computer, RF payload, and LIDAR payload during flight.', ...
    'Description', 'The Structures subsystem shall provide a rigid airframe capable of supporting all AVS subsystems including flight controller, flight computer, RF payload, and LIDAR payload during flight.');
setAttribute(req024, 'Scope',     '[AVS]');
setAttribute(req024, 'Status',    'APPROVED');
setAttribute(req024, 'ReqParent', 'SYS-FR-003');
setAttribute(req024, 'Section',   'AVS Structures');
req024.Id = 'AVS-ST-FR-001';

% AVS-ST-FR-002
req025 = add(sec05, ...
    'Summary',     'The Structures subsystem shall provide dedicated mounting points for the LIDAR sensor with unobstructed downward field of view.', ...
    'Description', 'The Structures subsystem shall provide dedicated mounting points for the LIDAR sensor with unobstructed downward field of view.');
setAttribute(req025, 'Scope',     '[AVS]');
setAttribute(req025, 'Status',    'APPROVED');
setAttribute(req025, 'ReqParent', 'AVS-LI-FR-001');
setAttribute(req025, 'Section',   'AVS Structures');
req025.Id = 'AVS-ST-FR-002';

% AVS-ST-FR-003
req026 = add(sec05, ...
    'Summary',     'The Structures subsystem shall provide dedicated mounting for the RTL-SDR and antenna with RF line-of-sight clearance from the airframe.', ...
    'Description', 'The Structures subsystem shall provide dedicated mounting for the RTL-SDR and antenna with RF line-of-sight clearance from the airframe.');
setAttribute(req026, 'Scope',     '[AVS]');
setAttribute(req026, 'Status',    'APPROVED');
setAttribute(req026, 'ReqParent', 'AVS-RF-FR-001');
setAttribute(req026, 'Section',   'AVS Structures');
req026.Id = 'AVS-ST-FR-003';

% AVS-ST-IR-001
req027 = add(sec05, ...
    'Summary',     'The Structures subsystem shall conform to the F450 quadcopter frame form factor as the baseline airframe platform.', ...
    'Description', 'The Structures subsystem shall conform to the F450 quadcopter frame form factor as the baseline airframe platform.');
setAttribute(req027, 'Scope',     '[AVS]');
setAttribute(req027, 'Status',    'APPROVED');
setAttribute(req027, 'ReqParent', 'SYS-FR-003');
setAttribute(req027, 'Section',   'AVS Structures');
req027.Id = 'AVS-ST-IR-001';


% ── AVS-PR — Propulsion ──
sec06 = add(rs, 'Type', 'Container', 'Summary', 'AVS Propulsion');

% AVS-PR-FR-001
req028 = add(sec06, ...
    'Summary',     'The Propulsion subsystem shall provide sufficient thrust to lift the fully loaded AVS including all payload and power systems.', ...
    'Description', 'The Propulsion subsystem shall provide sufficient thrust to lift the fully loaded AVS including all payload and power systems.');
setAttribute(req028, 'Scope',     '[AVS]');
setAttribute(req028, 'Status',    'APPROVED');
setAttribute(req028, 'ReqParent', 'SYS-PR-001');
setAttribute(req028, 'Section',   'AVS Propulsion');
req028.Id = 'AVS-PR-FR-001';

% AVS-PR-FR-002
req029 = add(sec06, ...
    'Summary',     'The Propulsion subsystem shall accept motor commands from the Flight Control subsystem via the flight controller ESC interface.', ...
    'Description', 'The Propulsion subsystem shall accept motor commands from the Flight Control subsystem via the flight controller ESC interface.');
setAttribute(req029, 'Scope',     '[AVS]');
setAttribute(req029, 'Status',    'APPROVED');
setAttribute(req029, 'ReqParent', 'AVS-FC-IR-002');
setAttribute(req029, 'Section',   'AVS Propulsion');
req029.Id = 'AVS-PR-FR-002';

% AVS-PR-PR-001
req030 = add(sec06, ...
    'Summary',     'The Propulsion subsystem shall provide a thrust-to-weight ratio of not less than 2:1 at hover under full payload configuration.', ...
    'Description', 'The Propulsion subsystem shall provide a thrust-to-weight ratio of not less than 2:1 at hover under full payload configuration.');
setAttribute(req030, 'Scope',     '[AVS]');
setAttribute(req030, 'Status',    'APPROVED');
setAttribute(req030, 'ReqParent', 'SYS-PR-001');
setAttribute(req030, 'Section',   'AVS Propulsion');
req030.Id = 'AVS-PR-PR-001';

% AVS-PR-PR-002
req031 = add(sec06, ...
    'Summary',     'The Propulsion subsystem shall sustain nominal flight operations for the duration of SYS-PR-001 minimum flight time on a single battery charge.', ...
    'Description', 'The Propulsion subsystem shall sustain nominal flight operations for the duration of SYS-PR-001 minimum flight time on a single battery charge.');
setAttribute(req031, 'Scope',     '[AVS]');
setAttribute(req031, 'Status',    'APPROVED');
setAttribute(req031, 'ReqParent', 'SYS-PR-001');
setAttribute(req031, 'Section',   'AVS Propulsion');
req031.Id = 'AVS-PR-PR-002';

% AVS-PR-IR-001
req032 = add(sec06, ...
    'Summary',     'The Propulsion subsystem shall accept 4S LiPo power input from the Power subsystem via the power distribution board.', ...
    'Description', 'The Propulsion subsystem shall accept 4S LiPo power input from the Power subsystem via the power distribution board.');
setAttribute(req032, 'Scope',     '[AVS]');
setAttribute(req032, 'Status',    'APPROVED');
setAttribute(req032, 'ReqParent', 'AVS-PW-FR-001');
setAttribute(req032, 'Section',   'AVS Propulsion');
req032.Id = 'AVS-PR-IR-001';


% ── AVS-FC — Flight Control ──
sec07 = add(rs, 'Type', 'Container', 'Summary', 'AVS Flight Control');

% AVS-FC-FR-001
req033 = add(sec07, ...
    'Summary',     'The Flight Control subsystem shall execute autonomous waypoint navigation using ArduPilot firmware.', ...
    'Description', 'The Flight Control subsystem shall execute autonomous waypoint navigation using ArduPilot firmware.');
setAttribute(req033, 'Scope',     '[AVS]');
setAttribute(req033, 'Status',    'APPROVED');
setAttribute(req033, 'ReqParent', 'SYS-FR-001');
setAttribute(req033, 'Section',   'AVS Flight Control');
req033.Id = 'AVS-FC-FR-001';

% AVS-FC-FR-002
req034 = add(sec07, ...
    'Summary',     'The Flight Control subsystem shall execute a return-to-launch command upon receipt of an abort command from the GCS or upon data link loss exceeding the defined failsafe threshold.', ...
    'Description', 'The Flight Control subsystem shall execute a return-to-launch command upon receipt of an abort command from the GCS or upon data link loss exceeding the defined failsafe threshold.');
setAttribute(req034, 'Scope',     '[AVS]');
setAttribute(req034, 'Status',    'APPROVED');
setAttribute(req034, 'ReqParent', 'GCS-MC-FR-004');
setAttribute(req034, 'Section',   'AVS Flight Control');
req034.Id = 'AVS-FC-FR-002';

% AVS-FC-FR-003
req035 = add(sec07, ...
    'Summary',     'The Flight Control subsystem shall perform attitude stabilization, altitude hold, and position hold using onboard IMU, barometer, and GPS inputs.', ...
    'Description', 'The Flight Control subsystem shall perform attitude stabilization, altitude hold, and position hold using onboard IMU, barometer, and GPS inputs.');
setAttribute(req035, 'Scope',     '[AVS]');
setAttribute(req035, 'Status',    'APPROVED');
setAttribute(req035, 'ReqParent', 'SYS-FR-001');
setAttribute(req035, 'Section',   'AVS Flight Control');
req035.Id = 'AVS-FC-FR-003';

% AVS-FC-FR-004
req036 = add(sec07, ...
    'Summary',     'The Flight Control subsystem shall accept mission waypoint uploads from the GCS via MAVLink.', ...
    'Description', 'The Flight Control subsystem shall accept mission waypoint uploads from the GCS via MAVLink.');
setAttribute(req036, 'Scope',     '[AVS]');
setAttribute(req036, 'Status',    'APPROVED');
setAttribute(req036, 'ReqParent', 'GCS-MC-FR-001');
setAttribute(req036, 'Section',   'AVS Flight Control');
req036.Id = 'AVS-FC-FR-004';

% AVS-FC-PR-001
req037 = add(sec07, ...
    'Summary',     'The Flight Control subsystem shall maintain position hold within 2 meters of commanded position under nominal wind conditions.', ...
    'Description', 'The Flight Control subsystem shall maintain position hold within 2 meters of commanded position under nominal wind conditions.');
setAttribute(req037, 'Scope',     '[AVS]');
setAttribute(req037, 'Status',    'APPROVED');
setAttribute(req037, 'ReqParent', 'SYS-PR-001');
setAttribute(req037, 'Section',   'AVS Flight Control');
req037.Id = 'AVS-FC-PR-001';

% AVS-FC-IR-001
req038 = add(sec07, ...
    'Summary',     'The Flight Control subsystem shall interface with the Flight Computer subsystem via MAVLink over serial UART.', ...
    'Description', 'The Flight Control subsystem shall interface with the Flight Computer subsystem via MAVLink over serial UART.');
setAttribute(req038, 'Scope',     '[AVS]');
setAttribute(req038, 'Status',    'APPROVED');
setAttribute(req038, 'ReqParent', 'SYS-FR-003');
setAttribute(req038, 'Section',   'AVS Flight Control');
req038.Id = 'AVS-FC-IR-001';

% AVS-FC-IR-002
req039 = add(sec07, ...
    'Summary',     'The Flight Control subsystem shall interface with the Propulsion subsystem via PWM or DSHOT ESC protocol.', ...
    'Description', 'The Flight Control subsystem shall interface with the Propulsion subsystem via PWM or DSHOT ESC protocol.');
setAttribute(req039, 'Scope',     '[AVS]');
setAttribute(req039, 'Status',    'APPROVED');
setAttribute(req039, 'ReqParent', 'AVS-PR-FR-002');
setAttribute(req039, 'Section',   'AVS Flight Control');
req039.Id = 'AVS-FC-IR-002';


% ── AVS-CP — Flight Computer ──
sec08 = add(rs, 'Type', 'Container', 'Summary', 'AVS Flight Computer');

% AVS-CP-FR-001
req040 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall operate as a headless companion computer executing the UAV daemon software.', ...
    'Description', 'The Flight Computer subsystem shall operate as a headless companion computer executing the UAV daemon software.');
setAttribute(req040, 'Scope',     '[AVS]');
setAttribute(req040, 'Status',    'APPROVED');
setAttribute(req040, 'ReqParent', 'SYS-FR-003');
setAttribute(req040, 'Section',   'AVS Flight Computer');
req040.Id = 'AVS-CP-FR-001';

% AVS-CP-FR-002
req041 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall bridge MAVLink telemetry between the Flight Control subsystem and the GCS.', ...
    'Description', 'The Flight Computer subsystem shall bridge MAVLink telemetry between the Flight Control subsystem and the GCS.');
setAttribute(req041, 'Scope',     '[AVS]');
setAttribute(req041, 'Status',    'APPROVED');
setAttribute(req041, 'ReqParent', 'GCS-FT-FR-001');
setAttribute(req041, 'Section',   'AVS Flight Computer');
req041.Id = 'AVS-CP-FR-002';

% AVS-CP-FR-003
req042 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall serve RTL-SDR IQ data to the GCS via rtl_tcp over the active data link.', ...
    'Description', 'The Flight Computer subsystem shall serve RTL-SDR IQ data to the GCS via rtl_tcp over the active data link.');
setAttribute(req042, 'Scope',     '[AVS]');
setAttribute(req042, 'Status',    'APPROVED');
setAttribute(req042, 'ReqParent', 'GCS-DP-IR-001');
setAttribute(req042, 'Section',   'AVS Flight Computer');
req042.Id = 'AVS-CP-FR-003';

% AVS-CP-FR-004
req043 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall log LIDAR point cloud data with timestamps for post-flight processing.', ...
    'Description', 'The Flight Computer subsystem shall log LIDAR point cloud data with timestamps for post-flight processing.');
setAttribute(req043, 'Scope',     '[AVS]');
setAttribute(req043, 'Status',    'APPROVED');
setAttribute(req043, 'ReqParent', 'GCS-DP-IR-002');
setAttribute(req043, 'Section',   'AVS Flight Computer');
req043.Id = 'AVS-CP-FR-004';

% AVS-CP-FR-005
req044 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall tag all sensor data with GPS coordinates via GPSd.', ...
    'Description', 'The Flight Computer subsystem shall tag all sensor data with GPS coordinates via GPSd.');
setAttribute(req044, 'Scope',     '[AVS]');
setAttribute(req044, 'Status',    'APPROVED');
setAttribute(req044, 'ReqParent', 'SYS-FR-002');
setAttribute(req044, 'Section',   'AVS Flight Computer');
req044.Id = 'AVS-CP-FR-005';

% AVS-CP-FR-006
req045 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall implement graceful fault handling for data link loss and sensor dropout without interrupting flight operations.', ...
    'Description', 'The Flight Computer subsystem shall implement graceful fault handling for data link loss and sensor dropout without interrupting flight operations.');
setAttribute(req045, 'Scope',     '[AVS]');
setAttribute(req045, 'Status',    'APPROVED');
setAttribute(req045, 'ReqParent', 'GCS-FT-FR-002');
setAttribute(req045, 'Section',   'AVS Flight Computer');
req045.Id = 'AVS-CP-FR-006';

% AVS-CP-IR-001
req046 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall be implemented on a Raspberry Pi 5 4GB as the baseline hardware platform.', ...
    'Description', 'The Flight Computer subsystem shall be implemented on a Raspberry Pi 5 4GB as the baseline hardware platform.');
setAttribute(req046, 'Scope',     '[AVS]');
setAttribute(req046, 'Status',    'APPROVED');
setAttribute(req046, 'ReqParent', 'SYS-FR-003');
setAttribute(req046, 'Section',   'AVS Flight Computer');
req046.Id = 'AVS-CP-IR-001';

% AVS-CP-IR-002
req047 = add(sec08, ...
    'Summary',     'The Flight Computer subsystem shall receive power from the Power subsystem via 5V BEC from the UAV battery bus during flight.', ...
    'Description', 'The Flight Computer subsystem shall receive power from the Power subsystem via 5V BEC from the UAV battery bus during flight.');
setAttribute(req047, 'Scope',     '[AVS]');
setAttribute(req047, 'Status',    'APPROVED');
setAttribute(req047, 'ReqParent', 'AVS-PW-FR-002');
setAttribute(req047, 'Section',   'AVS Flight Computer');
req047.Id = 'AVS-CP-IR-002';


% ── AVS-RF — SDR/RF ──
sec09 = add(rs, 'Type', 'Container', 'Summary', 'AVS RF SDR');

% AVS-RF-FR-001
req048 = add(sec09, ...
    'Summary',     'The RF subsystem shall capture IQ samples across a configurable frequency range during flight.', ...
    'Description', 'The RF subsystem shall capture IQ samples across a configurable frequency range during flight.');
setAttribute(req048, 'Scope',     '[AVS]');
setAttribute(req048, 'Status',    'APPROVED');
setAttribute(req048, 'ReqParent', 'SYS-FR-002');
setAttribute(req048, 'Section',   'AVS RF SDR');
req048.Id = 'AVS-RF-FR-001';

% AVS-RF-FR-002
req049 = add(sec09, ...
    'Summary',     'The RF subsystem shall stream captured IQ data to the Flight Computer via USB for forwarding to the GCS.', ...
    'Description', 'The RF subsystem shall stream captured IQ data to the Flight Computer via USB for forwarding to the GCS.');
setAttribute(req049, 'Scope',     '[AVS]');
setAttribute(req049, 'Status',    'APPROVED');
setAttribute(req049, 'ReqParent', 'AVS-CP-FR-003');
setAttribute(req049, 'Section',   'AVS RF SDR');
req049.Id = 'AVS-RF-FR-002';

% AVS-RF-PR-001
req050 = add(sec09, ...
    'Summary',     'The RF subsystem shall support a minimum instantaneous receive bandwidth of 2.4 MHz.', ...
    'Description', 'The RF subsystem shall support a minimum instantaneous receive bandwidth of 2.4 MHz.');
setAttribute(req050, 'Scope',     '[AVS]');
setAttribute(req050, 'Status',    'APPROVED');
setAttribute(req050, 'ReqParent', 'SYS-FR-002');
setAttribute(req050, 'Section',   'AVS RF SDR');
req050.Id = 'AVS-RF-PR-001';

% AVS-RF-PR-002
req051 = add(sec09, ...
    'Summary',     'The RF subsystem shall operate across a tunable frequency range of 500 kHz to 1.766 GHz.', ...
    'Description', 'The RF subsystem shall operate across a tunable frequency range of 500 kHz to 1.766 GHz.');
setAttribute(req051, 'Scope',     '[AVS]');
setAttribute(req051, 'Status',    'APPROVED');
setAttribute(req051, 'ReqParent', 'SYS-FR-002');
setAttribute(req051, 'Section',   'AVS RF SDR');
req051.Id = 'AVS-RF-PR-002';

% AVS-RF-IR-001
req052 = add(sec09, ...
    'Summary',     'The RF subsystem shall be implemented using the RTL-SDR Blog V4 as the baseline SDR hardware.', ...
    'Description', 'The RF subsystem shall be implemented using the RTL-SDR Blog V4 as the baseline SDR hardware.');
setAttribute(req052, 'Scope',     '[AVS]');
setAttribute(req052, 'Status',    'APPROVED');
setAttribute(req052, 'ReqParent', 'SYS-FR-003');
setAttribute(req052, 'Section',   'AVS RF SDR');
req052.Id = 'AVS-RF-IR-001';

% AVS-RF-IR-002
req053 = add(sec09, ...
    'Summary',     'The RF subsystem shall connect to the Flight Computer via USB interface.', ...
    'Description', 'The RF subsystem shall connect to the Flight Computer via USB interface.');
setAttribute(req053, 'Scope',     '[AVS]');
setAttribute(req053, 'Status',    'APPROVED');
setAttribute(req053, 'ReqParent', 'AVS-CP-FR-003');
setAttribute(req053, 'Section',   'AVS RF SDR');
req053.Id = 'AVS-RF-IR-002';


% ── AVS-LI — LIDAR ──
sec10 = add(rs, 'Type', 'Container', 'Summary', 'AVS LIDAR');

% AVS-LI-FR-001
req054 = add(sec10, ...
    'Summary',     'The LIDAR subsystem shall continuously capture 2D point cloud scans of terrain below the AVS during flight.', ...
    'Description', 'The LIDAR subsystem shall continuously capture 2D point cloud scans of terrain below the AVS during flight.');
setAttribute(req054, 'Scope',     '[AVS]');
setAttribute(req054, 'Status',    'APPROVED');
setAttribute(req054, 'ReqParent', 'SYS-FR-002');
setAttribute(req054, 'Section',   'AVS LIDAR');
req054.Id = 'AVS-LI-FR-001';

% AVS-LI-FR-002
req055 = add(sec10, ...
    'Summary',     'The LIDAR subsystem shall log all point cloud data with timestamps to the Flight Computer for georeferencing.', ...
    'Description', 'The LIDAR subsystem shall log all point cloud data with timestamps to the Flight Computer for georeferencing.');
setAttribute(req055, 'Scope',     '[AVS]');
setAttribute(req055, 'Status',    'APPROVED');
setAttribute(req055, 'ReqParent', 'AVS-CP-FR-004');
setAttribute(req055, 'Section',   'AVS LIDAR');
req055.Id = 'AVS-LI-FR-002';

% AVS-LI-PR-001
req056 = add(sec10, ...
    'Summary',     'The LIDAR subsystem shall achieve a minimum scan range of 6 meters under nominal operating conditions.', ...
    'Description', 'The LIDAR subsystem shall achieve a minimum scan range of 6 meters under nominal operating conditions.');
setAttribute(req056, 'Scope',     '[AVS]');
setAttribute(req056, 'Status',    'APPROVED');
setAttribute(req056, 'ReqParent', 'SYS-FR-002');
setAttribute(req056, 'Section',   'AVS LIDAR');
req056.Id = 'AVS-LI-PR-001';

% AVS-LI-PR-002
req057 = add(sec10, ...
    'Summary',     'The LIDAR subsystem shall operate at a minimum scan frequency of 5.5 Hz.', ...
    'Description', 'The LIDAR subsystem shall operate at a minimum scan frequency of 5.5 Hz.');
setAttribute(req057, 'Scope',     '[AVS]');
setAttribute(req057, 'Status',    'APPROVED');
setAttribute(req057, 'ReqParent', 'SYS-FR-002');
setAttribute(req057, 'Section',   'AVS LIDAR');
req057.Id = 'AVS-LI-PR-002';

% AVS-LI-IR-001
req058 = add(sec10, ...
    'Summary',     'The LIDAR subsystem shall be implemented using the RPLidar A1M8 as the baseline sensor.', ...
    'Description', 'The LIDAR subsystem shall be implemented using the RPLidar A1M8 as the baseline sensor.');
setAttribute(req058, 'Scope',     '[AVS]');
setAttribute(req058, 'Status',    'APPROVED');
setAttribute(req058, 'ReqParent', 'SYS-FR-003');
setAttribute(req058, 'Section',   'AVS LIDAR');
req058.Id = 'AVS-LI-IR-001';

% AVS-LI-IR-002
req059 = add(sec10, ...
    'Summary',     'The LIDAR subsystem shall interface with the Flight Computer via USB.', ...
    'Description', 'The LIDAR subsystem shall interface with the Flight Computer via USB.');
setAttribute(req059, 'Scope',     '[AVS]');
setAttribute(req059, 'Status',    'APPROVED');
setAttribute(req059, 'ReqParent', 'AVS-CP-FR-004');
setAttribute(req059, 'Section',   'AVS LIDAR');
req059.Id = 'AVS-LI-IR-002';


% ── AVS-PW — Power ──
sec11 = add(rs, 'Type', 'Container', 'Summary', 'AVS Power');

% AVS-PW-FR-001
req060 = add(sec11, ...
    'Summary',     'The Power subsystem shall provide primary flight power to all AVS subsystems from a single LiPo battery.', ...
    'Description', 'The Power subsystem shall provide primary flight power to all AVS subsystems from a single LiPo battery.');
setAttribute(req060, 'Scope',     '[AVS]');
setAttribute(req060, 'Status',    'APPROVED');
setAttribute(req060, 'ReqParent', 'SYS-FR-003');
setAttribute(req060, 'Section',   'AVS Power');
req060.Id = 'AVS-PW-FR-001';

% AVS-PW-FR-002
req061 = add(sec11, ...
    'Summary',     'The Power subsystem shall provide regulated 5V DC power to the Flight Computer via BEC during flight.', ...
    'Description', 'The Power subsystem shall provide regulated 5V DC power to the Flight Computer via BEC during flight.');
setAttribute(req061, 'Scope',     '[AVS]');
setAttribute(req061, 'Status',    'APPROVED');
setAttribute(req061, 'ReqParent', 'AVS-CP-IR-002');
setAttribute(req061, 'Section',   'AVS Power');
req061.Id = 'AVS-PW-FR-002';

% AVS-PW-PR-001
req062 = add(sec11, ...
    'Summary',     'The Power subsystem shall provide sufficient capacity to satisfy SYS-PR-001 minimum flight duration under full payload load.', ...
    'Description', 'The Power subsystem shall provide sufficient capacity to satisfy SYS-PR-001 minimum flight duration under full payload load.');
setAttribute(req062, 'Scope',     '[AVS]');
setAttribute(req062, 'Status',    'APPROVED');
setAttribute(req062, 'ReqParent', 'SYS-PR-001');
setAttribute(req062, 'Section',   'AVS Power');
req062.Id = 'AVS-PW-PR-001';

% AVS-PW-IR-001
req063 = add(sec11, ...
    'Summary',     'The Power subsystem shall be implemented using a 4S 3300mAh LiPo as the baseline power source.', ...
    'Description', 'The Power subsystem shall be implemented using a 4S 3300mAh LiPo as the baseline power source.');
setAttribute(req063, 'Scope',     '[AVS]');
setAttribute(req063, 'Status',    'APPROVED');
setAttribute(req063, 'ReqParent', 'SYS-FR-003');
setAttribute(req063, 'Section',   'AVS Power');
req063.Id = 'AVS-PW-IR-001';


% ── DL — Data Link ──
sec12 = add(rs, 'Type', 'Container', 'Summary', 'Data Link');

% DL-FR-001
req064 = add(sec12, ...
    'Summary',     'The Data Link shall provide a bidirectional communication channel between the GCS and AVS supporting MAVLink telemetry, IQ data streaming, and LIDAR data transfer.', ...
    'Description', 'The Data Link shall provide a bidirectional communication channel between the GCS and AVS supporting MAVLink telemetry, IQ data streaming, and LIDAR data transfer.');
setAttribute(req064, 'Scope',     '[DL]');
setAttribute(req064, 'Status',    'APPROVED');
setAttribute(req064, 'ReqParent', 'SYS-FR-003');
setAttribute(req064, 'Section',   'Data Link');
req064.Id = 'DL-FR-001';

% DL-FR-002
req065 = add(sec12, ...
    'Summary',     'The Data Link shall support WiFi as the primary link architecture.', ...
    'Description', 'The Data Link shall support WiFi as the primary link architecture.');
setAttribute(req065, 'Scope',     '[DL]');
setAttribute(req065, 'Status',    'APPROVED');
setAttribute(req065, 'ReqParent', 'GCS-FT-IR-001');
setAttribute(req065, 'Section',   'Data Link');
req065.Id = 'DL-FR-002';

% DL-FR-003
req066 = add(sec12, ...
    'Summary',     'The Data Link shall support RFD900x radio as a configurable contingency link for MAVLink telemetry in environments where WiFi is unavailable or unreliable.', ...
    'Description', 'The Data Link shall support RFD900x radio as a configurable contingency link for MAVLink telemetry in environments where WiFi is unavailable or unreliable.');
setAttribute(req066, 'Scope',     '[DL]');
setAttribute(req066, 'Status',    'APPROVED');
setAttribute(req066, 'ReqParent', 'GCS-FT-IR-001');
setAttribute(req066, 'Section',   'Data Link');
req066.Id = 'DL-FR-003';

% DL-FR-004
req067 = add(sec12, ...
    'Summary',     'The Data Link shall maintain continuous MAVLink telemetry for the duration of each mission.', ...
    'Description', 'The Data Link shall maintain continuous MAVLink telemetry for the duration of each mission.');
setAttribute(req067, 'Scope',     '[DL]');
setAttribute(req067, 'Status',    'APPROVED');
setAttribute(req067, 'ReqParent', 'GCS-FT-FR-001');
setAttribute(req067, 'Section',   'Data Link');
req067.Id = 'DL-FR-004';

% DL-PR-001
req068 = add(sec12, ...
    'Summary',     'The Data Link shall sustain end-to-end command and telemetry latency not exceeding 500ms under nominal link conditions per SYS-PR-002.', ...
    'Description', 'The Data Link shall sustain end-to-end command and telemetry latency not exceeding 500ms under nominal link conditions per SYS-PR-002.');
setAttribute(req068, 'Scope',     '[DL]');
setAttribute(req068, 'Status',    'APPROVED');
setAttribute(req068, 'ReqParent', 'SYS-PR-002');
setAttribute(req068, 'Section',   'Data Link');
req068.Id = 'DL-PR-001';

% DL-PR-002
req069 = add(sec12, ...
    'Summary',     'The Data Link shall support simultaneous MAVLink telemetry and IQ data streaming without throughput degradation to either channel.', ...
    'Description', 'The Data Link shall support simultaneous MAVLink telemetry and IQ data streaming without throughput degradation to either channel.');
setAttribute(req069, 'Scope',     '[DL]');
setAttribute(req069, 'Status',    'APPROVED');
setAttribute(req069, 'ReqParent', 'SYS-PR-002');
setAttribute(req069, 'Section',   'Data Link');
req069.Id = 'DL-PR-002';

% DL-IR-001
req070 = add(sec12, ...
    'Summary',     'The Data Link shall interface with the GCS Flight Telemetry subsystem on the ground segment side.', ...
    'Description', 'The Data Link shall interface with the GCS Flight Telemetry subsystem on the ground segment side.');
setAttribute(req070, 'Scope',     '[DL]');
setAttribute(req070, 'Status',    'APPROVED');
setAttribute(req070, 'ReqParent', 'SYS-FR-003');
setAttribute(req070, 'Section',   'Data Link');
req070.Id = 'DL-IR-001';

% DL-IR-002
req071 = add(sec12, ...
    'Summary',     'The Data Link shall interface with the AVS Flight Computer subsystem on the aerial vehicle side.', ...
    'Description', 'The Data Link shall interface with the AVS Flight Computer subsystem on the aerial vehicle side.');
setAttribute(req071, 'Scope',     '[DL]');
setAttribute(req071, 'Status',    'APPROVED');
setAttribute(req071, 'ReqParent', 'SYS-FR-003');
setAttribute(req071, 'Section',   'Data Link');
req071.Id = 'DL-IR-002';


save(rs);
fprintf('Done! 71 requirements authored in RAVEN_Requirements.slreqx\n');
slreq.editor
