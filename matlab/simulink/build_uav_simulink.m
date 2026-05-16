%% RAVEN UAV Simulink Model — R2025b Build Script
% Reconnaissance Autonomous Vehicle with Electronic iNtelligence
% Uses UAV Toolbox native blocks confirmed in R2025b library
%
% Block paths verified from uavlib:
%   Algorithms:              uavlib/Algorithms/Guidance Model
%                            uavlib/Algorithms/Waypoint Follower
%                            uavlib/Algorithms/Path Manager
%   Scenario & Sensors:      uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Configuration
%                            uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Motion Write
%                            uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Motion Read
%                            uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Lidar
%                            uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Scope
%                            uavlib/UAV Scenario and Sensor Modeling/GPS
%                            uavlib/UAV Scenario and Sensor Modeling/INS
%                            uavlib/UAV Scenario and Sensor Modeling/Barometer
%
% Author: Luke J. Waszyn II | Penn State Engineering Science

%% ── Setup ────────────────────────────────────────────────────────────────────
clear; clc; close all;

modelName = 'RAVEN_UAV_Simulation';
saveDir   = '/Users/lukewaszyn/RAVEN/matlab/simulink';
savePath  = fullfile(saveDir, [modelName '.slx']);

if ~exist(saveDir, 'dir'); mkdir(saveDir); end
if bdIsLoaded(modelName); close_system(modelName, 0); end

%% ── F450 Physical Parameters ─────────────────────────────────────────────────
params.mass       = 1.5;       % kg — frame + payload + battery
params.arm_length = 0.225;     % m
params.Ixx        = 0.0211;    % kg·m²
params.Iyy        = 0.0219;    % kg·m²
params.Izz        = 0.0366;    % kg·m²
params.g          = 9.81;      % m/s²
params.kt         = 1.69e-6;   % thrust coefficient
params.kd         = 2.5e-8;    % drag coefficient
params.max_rpm    = 8000;

params.max_thrust = 4 * params.kt * params.max_rpm^2;
params.tw_ratio   = params.max_thrust / (params.mass * params.g);
params.hover_rpm  = sqrt(params.mass * params.g / (4 * params.kt));

fprintf('── F450 Parameters ──────────────────────────\n');
fprintf('  Mass:         %.2f kg\n',  params.mass);
fprintf('  Max thrust:   %.2f N\n',   params.max_thrust);
fprintf('  T/W ratio:    %.2f\n',     params.tw_ratio);
fprintf('  Hover RPM:    %.0f\n',     params.hover_rpm);

%% ── Mission Definition ───────────────────────────────────────────────────────
% Rectangular lawnmower survey — Aliquippa PA area
% NED coordinates from takeoff origin

mission.origin_lat = 40.6144;
mission.origin_lon = -80.2007;
mission.alt_AGL    = 30.0;     % m
mission.speed      = 5.0;      % m/s

% [North(m), East(m), Down(m)] — Down is negative AGL
mission.waypoints = [
      0,    0, -30;
     50,    0, -30;
     50,  100, -30;
    -50,  100, -30;
    -50,    0, -30;
      0,    0, -30;
];

fprintf('\n── Mission ──────────────────────────────────\n');
fprintf('  Waypoints:  %d\n',     size(mission.waypoints,1));
fprintf('  Altitude:   %.1f m\n', mission.alt_AGL);
fprintf('  Speed:      %.1f m/s\n', mission.speed);

%% ── Simulation Parameters ────────────────────────────────────────────────────
sim_p.duration   = 180;     % s
sim_p.lidar_rate = 5.5;     % Hz — AVS-LI-PR-002
sim_p.gps_rate   = 5.0;     % Hz
sim_p.imu_rate   = 100.0;   % Hz

% PID gains — F450 payload-loaded
pid.roll  = [4.0, 0.5, 0.2];
pid.pitch = [4.0, 0.5, 0.2];
pid.yaw   = [3.0, 0.3, 0.1];
pid.alt   = [2.0, 0.2, 0.5];
pid.pos   = [1.5, 0.1, 0.3];

%% ── V&V Pre-check ────────────────────────────────────────────────────────────
fprintf('\n── V&V Pre-check ────────────────────────────\n');

% SYS-PR-001: Flight endurance
batt_mAh     = 3300;
hover_curr_A = 15;
hover_min    = batt_mAh / (hover_curr_A * 1000) * 60;
fprintf('SYS-PR-001  Endurance:  %.1f min [req >= 10] — %s\n', ...
    hover_min, pass_fail(hover_min >= 10));

% AVS-PR-PR-001: T/W ratio
fprintf('AVS-PR-PR-001 T/W:      %.2f     [req >= 2.0] — %s\n', ...
    params.tw_ratio, pass_fail(params.tw_ratio >= 2.0));

% AVS-LI-PR-002: LIDAR rate
fprintf('AVS-LI-PR-002 LIDAR:    %.1f Hz  [req >= 5.5] — %s\n', ...
    sim_p.lidar_rate, pass_fail(sim_p.lidar_rate >= 5.5));

% SYS-PR-002: Latency budget (from bench measurement)
est_lat_ms = 20;
fprintf('SYS-PR-002  Latency:    %d ms    [req <= 500] — %s\n', ...
    est_lat_ms, pass_fail(est_lat_ms <= 500));

%% ── Build Simulink Model ─────────────────────────────────────────────────────
fprintf('\n── Building Simulink Model ──────────────────\n');

new_system(modelName);
open_system(modelName);

% Solver configuration
set_param(modelName, ...
    'SolverType',  'Variable-step', ...
    'Solver',      'ode45', ...
    'StopTime',    num2str(sim_p.duration), ...
    'MaxStep',     '0.01', ...
    'RelTol',      '1e-4');

% Canvas size
set_param(modelName, 'ZoomFactor', 'FitSystem');

%% ── Block: UAV Scenario Configuration ───────────────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Configuration', ...
    [modelName '/UAV Scenario Configuration'], ...
    'Position', [50, 50, 250, 130]);
fprintf('  + UAV Scenario Configuration\n');

%% ── Block: UAV Scenario Motion Write ────────────────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Motion Write', ...
    [modelName '/UAV Scenario Motion Write'], ...
    'Position', [50, 200, 250, 340]);
fprintf('  + UAV Scenario Motion Write\n');

%% ── Block: UAV Scenario Motion Read ─────────────────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Motion Read', ...
    [modelName '/UAV Scenario Motion Read'], ...
    'Position', [50, 400, 250, 480]);
fprintf('  + UAV Scenario Motion Read\n');

%% ── Block: Waypoint Follower ─────────────────────────────────────────────────
add_block('uavlib/Algorithms/Waypoint Follower', ...
    [modelName '/Waypoint Follower'], ...
    'Position', [350, 200, 550, 320]);
fprintf('  + Waypoint Follower\n');

%% ── Block: Path Manager ──────────────────────────────────────────────────────
add_block('uavlib/Algorithms/Path Manager', ...
    [modelName '/Path Manager'], ...
    'Position', [600, 200, 800, 340]);
fprintf('  + Path Manager\n');

%% ── Block: Guidance Model ────────────────────────────────────────────────────
add_block('uavlib/Algorithms/Guidance Model', ...
    [modelName '/Guidance Model'], ...
    'Position', [350, 400, 550, 520]);
fprintf('  + Guidance Model\n');

%% ── Block: GPS ───────────────────────────────────────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/GPS', ...
    [modelName '/GPS'], ...
    'Position', [350, 580, 550, 680]);
fprintf('  + GPS\n');

%% ── Block: INS ───────────────────────────────────────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/INS', ...
    [modelName '/INS'], ...
    'Position', [600, 580, 800, 680]);
fprintf('  + INS\n');

%% ── Block: Barometer ─────────────────────────────────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/Barometer', ...
    [modelName '/Barometer'], ...
    'Position', [350, 720, 550, 800]);
fprintf('  + Barometer\n');

%% ── Block: UAV Scenario Lidar ────────────────────────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Lidar', ...
    [modelName '/UAV Scenario Lidar'], ...
    'Position', [600, 720, 800, 800]);
fprintf('  + UAV Scenario Lidar\n');

%% ── Block: UAV Scenario Scope (3D Visualization) ────────────────────────────
add_block('uavlib/UAV Scenario and Sensor Modeling/UAV Scenario Scope', ...
    [modelName '/UAV Scenario Scope'], ...
    'Position', [900, 50, 1100, 150]);
fprintf('  + UAV Scenario Scope (3D)\n');

%% ── Waypoint Source ──────────────────────────────────────────────────────────
add_block('simulink/Sources/Constant', ...
    [modelName '/Mission Waypoints'], ...
    'Value',            mat2str(mission.waypoints), ...
    'OutDataTypeStr',   'double', ...
    'Position',         [50, 580, 250, 640]);
fprintf('  + Mission Waypoints\n');

%% ── Data Loggers ─────────────────────────────────────────────────────────────
signals = {'GPS_LLA', 'GPS_Velocity', 'INS_Position', 'INS_Orientation', ...
           'Baro_Pressure', 'UAV_Motion'};
positions = [900,200; 900,270; 900,340; 900,410; 900,480; 900,550];

for i = 1:length(signals)
    add_block('simulink/Sinks/To Workspace', ...
        [modelName '/Log_' signals{i}], ...
        'VariableName',  ['raven_' lower(signals{i})], ...
        'SaveFormat',    'Timeseries', ...
        'Position',      [positions(i,1), positions(i,2), ...
                          positions(i,1)+150, positions(i,2)+40]);
end
fprintf('  + Data loggers (%d signals)\n', length(signals));

%% ── Clock ────────────────────────────────────────────────────────────────────
add_block('simulink/Sources/Clock', ...
    [modelName '/Sim Clock'], ...
    'Position', [50, 870, 130, 910]);

%% ── Classification Annotation ───────────────────────────────────────────────
add_block('simulink/Model-Wide Utilities/DocBlock', ...
    [modelName '/Classification'], ...
    'Position', [50, 930, 600, 970]);
set_param([modelName '/Classification'], ...
    'Document', 'RAVEN UAV Simulation | UNCLASSIFIED // FOR TRAINING PURPOSES ONLY | Luke J. Waszyn II | Penn State Engineering Science');

%% ── Save ─────────────────────────────────────────────────────────────────────
save_system(modelName, savePath);
fprintf('\n── Model saved ──────────────────────────────\n');
fprintf('  Path: %s\n', savePath);
fprintf('\nNext steps:\n');
fprintf('  1. Open model:     open_system(''%s'')\n', modelName);
fprintf('  2. Wire blocks manually in Simulink GUI\n');
fprintf('  3. Configure UAV Scenario Configuration block\n');
fprintf('  4. Run simulation: sim(''%s'')\n', modelName);
fprintf('  5. Open 3D scope:  UAV Scenario Scope block\n');

%% ── Helper ───────────────────────────────────────────────────────────────────
function s = pass_fail(condition)
    if condition; s = 'PASS'; else; s = 'FAIL'; end
end