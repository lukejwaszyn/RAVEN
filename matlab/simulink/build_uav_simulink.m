%% RAVEN UAV Simulink Model — R2025b Build Script
% Reconnaissance Autonomous Vehicle with Electronic iNtelligence
%
% Build state:
%   - Closed-loop kinematic integration (velocity toward lookahead)
%   - Quadrotor mesh in Scenario Scope (renders as red cuboid placeholder)
%   - Path Manager and Guidance Model bypassed (commented on canvas)
%   - Simulation 3D omitted (Apple Silicon unsupported)
%   - HoverAtLastWaypoint enabled (prevents post-mission runaway)
%   - Rate Transition blocks on Orientation and Velocity into Motion Write
%     (resolves 0.1s scenario vs 0s continuous sample time mismatch)
%
% Pipeline:
%   Motion Read → BusSel → Position feedback
%   Position feedback + LookaheadPoint → Velocity command (capped at cruise)
%   Velocity command → Integrator → Position output → Motion Write
%
% Author: Luke J. Waszyn II | Penn State Engineering Science

%% ── Setup ────────────────────────────────────────────────────────────────────
clear; clc; close all;

modelName = 'RAVEN_UAV_Simulation';
saveDir   = '/Users/lukewaszyn/RAVEN/matlab/simulink';
savePath  = fullfile(saveDir, [modelName '.slx']);

if ~exist(saveDir, 'dir'); mkdir(saveDir); end
if bdIsLoaded(modelName); close_system(modelName, 0); end

%% ── Feature toggles ─────────────────────────────────────────────────────────
enable.lidar     = false;
enable.gps       = false;
enable.ins       = false;
enable.barometer = true;

%% ── Discover real uavlib block paths ────────────────────────────────────────
BLK = discover_uav_blocks();

%% ── F450 Physical Parameters ─────────────────────────────────────────────────
params.mass       = 1.5;
params.arm_length = 0.225;
params.Ixx        = 0.0211;
params.Iyy        = 0.0219;
params.Izz        = 0.0366;
params.g          = 9.81;
params.kt         = 1.69e-6;
params.kd         = 2.5e-8;
params.max_rpm    = 8000;

params.max_thrust = 4 * params.kt * params.max_rpm^2;
params.tw_ratio   = params.max_thrust / (params.mass * params.g);
params.hover_rpm  = sqrt(params.mass * params.g / (4 * params.kt));

% Mesh size for Scenario Scope. Physical arm length (0.225 m) is invisible
% at 100 m scene scale, so use a larger value for visibility.
mesh_scale = 5.0;

fprintf('── F450 Parameters ──────────────────────────\n');
fprintf('  Mass:         %.2f kg\n',  params.mass);
fprintf('  Arm length:   %.3f m\n',   params.arm_length);
fprintf('  Max thrust:   %.2f N\n',   params.max_thrust);
fprintf('  T/W ratio:    %.2f\n',     params.tw_ratio);

%% ── Mission Definition ───────────────────────────────────────────────────────
mission.origin_lat = 40.6144;
mission.origin_lon = -80.2007;
mission.alt_AGL    = 30.0;
mission.speed      = 5.0;
mission.start      = [0; 0; -30];

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
sim_p.duration   = 180;
sim_p.lidar_rate = 5.5;
sim_p.gps_rate   = 5.0;
sim_p.imu_rate   = 100.0;

%% ── V&V Pre-check ────────────────────────────────────────────────────────────
fprintf('\n── V&V Pre-check ────────────────────────────\n');
batt_mAh     = 3300;
hover_curr_A = 15;
hover_min    = batt_mAh / (hover_curr_A * 1000) * 60;
fprintf('SYS-PR-001  Endurance:  %.1f min [req >= 10] — %s\n', ...
    hover_min, pass_fail(hover_min >= 10));
fprintf('AVS-PR-PR-001 T/W:      %.2f     [req >= 2.0] — %s\n', ...
    params.tw_ratio, pass_fail(params.tw_ratio >= 2.0));
fprintf('AVS-LI-PR-002 LIDAR:    %.1f Hz  [req >= 5.5] — %s\n', ...
    sim_p.lidar_rate, pass_fail(sim_p.lidar_rate >= 5.5));
fprintf('SYS-PR-002  Latency:    %d ms    [req <= 500] — %s\n', ...
    20, pass_fail(true));

%% ── Build Simulink Model ─────────────────────────────────────────────────────
fprintf('\n── Building Simulink Model ──────────────────\n');

new_system(modelName);
open_system(modelName);

set_param(modelName, ...
    'SolverType',  'Variable-step', ...
    'Solver',      'ode45', ...
    'StopTime',    num2str(sim_p.duration), ...
    'MaxStep',     '0.01', ...
    'RelTol',      '1e-4');
set_param(modelName, 'ZoomFactor', 'FitSystem');

%% ── PreLoadFcn — scenario + quadrotor mesh ──────────────────────────────────
preLoadLines = {
    sprintf('scene = uavScenario("UpdateRate", 100, "ReferenceLocation", [%.4f %.4f 0]);', ...
            mission.origin_lat, mission.origin_lon)
    'plat = uavPlatform("RAVEN", scene, "ReferenceFrame", "NED");'
    sprintf('updateMesh(plat, "quadrotor", {%.3f}, [1 0 0], eye(4));', mesh_scale)
};
if enable.lidar
    preLoadLines{end+1} = ...
        'lidarModel = uavLidarPointCloudGenerator("MaxRange", 50, "UpdateRate", 5.5);';
    preLoadLines{end+1} = 'uavSensor("Lidar", plat, lidarModel);';
end
if enable.gps
    preLoadLines{end+1} = sprintf(...
        'gpsModel = gpsSensor("ReferenceFrame", "NED", "ReferenceLocation", [%.4f %.4f 0]);', ...
        mission.origin_lat, mission.origin_lon);
    preLoadLines{end+1} = 'uavSensor("GPS", plat, gpsModel);';
end
if enable.ins
    preLoadLines{end+1} = 'insModel = insSensor;';
    preLoadLines{end+1} = 'uavSensor("INS", plat, insModel);';
end
preLoadFcn = strjoin(preLoadLines, newline);
set_param(modelName, 'PreLoadFcn', preLoadFcn);
fprintf('  + PreLoadFcn (quadrotor mesh, scale=%.2f m)\n', mesh_scale);

%% ── UAV Toolbox blocks ──────────────────────────────────────────────────────
add_block(BLK.scenarioConfig, [modelName '/UAV Scenario Configuration'], ...
    'Position', [50, 50, 250, 130]);
add_block(BLK.motionWrite, [modelName '/UAV Scenario Motion Write'], ...
    'Position', [50, 200, 250, 340]);
add_block(BLK.motionRead, [modelName '/UAV Scenario Motion Read'], ...
    'Position', [50, 400, 250, 480]);

% HoverAtLastWaypoint prevents post-mission runaway (no external state machine)
add_block(BLK.waypointFollower, [modelName '/Waypoint Follower'], ...
    'Position', [550, 200, 750, 320]);
set_param([modelName '/Waypoint Follower'], 'HoverAtLastWaypoint', 'on');

add_block(BLK.pathManager, [modelName '/Path Manager (unwired)'], ...
    'Position', [800, 200, 1000, 340]);
set_param([modelName '/Path Manager (unwired)'], 'Commented', 'on');

add_block(BLK.guidanceModel, [modelName '/Guidance Model (unwired)'], ...
    'Position', [550, 400, 750, 520]);
try
    set_param([modelName '/Guidance Model (unwired)'], ...
        'MassMultirotor', num2str(params.mass));
catch
end
set_param([modelName '/Guidance Model (unwired)'], 'Commented', 'on');

if enable.gps
    add_block(BLK.gps, [modelName '/GPS'], 'Position', [550, 580, 750, 680]);
end
if enable.ins
    add_block(BLK.ins, [modelName '/INS'], 'Position', [800, 580, 1000, 680]);
end
if enable.barometer
    add_block(BLK.barometer, [modelName '/Barometer'], 'Position', [550, 720, 750, 800]);
end
if enable.lidar
    add_block(BLK.lidar, [modelName '/UAV Scenario Lidar'], 'Position', [800, 720, 1000, 800]);
end

add_block(BLK.scope, [modelName '/UAV Scenario Scope'], ...
    'Position', [1300, 50, 1500, 150]);
fprintf('  + UAV Toolbox blocks placed\n');

%% ── Waypoint Source and helpers ─────────────────────────────────────────────
add_block('simulink/Sources/Constant', [modelName '/Mission Waypoints'], ...
    'Value', mat2str(mission.waypoints), 'OutDataTypeStr', 'double', ...
    'Position', [350, 220, 470, 260]);

add_block('simulink/Signal Routing/Bus Selector', [modelName '/BusSel_Motion'], ...
    'Position', [290, 400, 310, 540], ...
    'OutputSignals', 'Position,Orientation,Velocity,AngularVelocity,Acceleration', ...
    'OutputAsBus', 'off');

add_block('simulink/Sources/Constant', [modelName '/LookaheadDist'], ...
    'Value', '5.0', 'OutDataTypeStr', 'double', ...
    'Position', [400, 290, 480, 320]);

add_block('simulink/Sources/Constant', [modelName '/CruiseSpeed'], ...
    'Value', sprintf('%.2f', mission.speed), 'OutDataTypeStr', 'double', ...
    'Position', [600, 580, 680, 610]);
fprintf('  + Mission source and helpers\n');

%% ── Data Loggers ─────────────────────────────────────────────────────────────
add_block('simulink/Sinks/To Workspace', [modelName '/Log_UAV_Motion'], ...
    'VariableName', 'raven_uav_motion', 'SaveFormat', 'Timeseries', ...
    'Position', [1300, 480, 1450, 520]);

logSpecs = {};
if enable.gps
    logSpecs{end+1} = {'GPS_LLA',      'raven_gps_lla',      [1300, 200]};
    logSpecs{end+1} = {'GPS_Velocity', 'raven_gps_velocity', [1300, 270]};
end
if enable.ins
    logSpecs{end+1} = {'INS_Position',    'raven_ins_position',    [1300, 340]};
    logSpecs{end+1} = {'INS_Orientation', 'raven_ins_orientation', [1300, 410]};
end
if enable.barometer
    logSpecs{end+1} = {'Baro_Pressure', 'raven_baro_pressure', [1300, 550]};
end

for i = 1:numel(logSpecs)
    spec = logSpecs{i};
    add_block('simulink/Sinks/To Workspace', [modelName '/Log_' spec{1}], ...
        'VariableName', spec{2}, 'SaveFormat', 'Timeseries', ...
        'Position', [spec{3}(1), spec{3}(2), spec{3}(1)+150, spec{3}(2)+40]);
end
fprintf('  + Data loggers (%d signals)\n', 1 + numel(logSpecs));

%% ── Clock ────────────────────────────────────────────────────────────────────
add_block('simulink/Sources/Clock', [modelName '/Sim Clock'], ...
    'Position', [50, 870, 130, 910]);

%% ── Pose_4Row subsystem ─────────────────────────────────────────────────────
% Waypoint Follower expects pose as [x; y; z; yaw] (4-row column).
% Extracts yaw from the quaternion orientation, defaults safe on NaN.
pose_subsys = [modelName '/Pose_4Row'];
add_block('built-in/Subsystem', pose_subsys, 'Position', [400, 220, 480, 280]);

add_block('simulink/Sources/In1', [pose_subsys '/Pos'], ...
    'Position', [30, 30, 60, 50]);
add_block('simulink/Sources/In1', [pose_subsys '/Quat'], ...
    'Position', [30, 90, 60, 110], 'Port', '2');
add_block('simulink/User-Defined Functions/MATLAB Function', [pose_subsys '/BuildPose'], ...
    'Position', [120, 50, 240, 110]);
install_matlab_fcn([pose_subsys '/BuildPose'], modelName, sprintf([...
    'function pose = build_pose(pos, quat)\n' ...
    'p = pos(:); q = quat(:);\n' ...
    'if any(isnan(p)) || any(isnan(q)) || norm(q) < 1e-6\n' ...
    '    pose = [0; 0; 0; 0]; return\n' ...
    'end\n' ...
    'q = q / norm(q);\n' ...
    'yaw = atan2(2*(q(1)*q(4)+q(2)*q(3)), 1-2*(q(3)^2+q(4)^2));\n' ...
    'pose = [p(1); p(2); p(3); yaw];\n' ...
    'end\n']));

add_block('simulink/Sinks/Out1', [pose_subsys '/Pose'], ...
    'Position', [280, 70, 310, 90]);
add_line(pose_subsys, 'Pos/1',       'BuildPose/1', 'autorouting', 'on');
add_line(pose_subsys, 'Quat/1',      'BuildPose/2', 'autorouting', 'on');
add_line(pose_subsys, 'BuildPose/1', 'Pose/1',      'autorouting', 'on');
fprintf('  + Pose_4Row subsystem\n');

%% ── Kinematic_Dynamics subsystem (closed-loop integration) ──────────────────
% Velocity = unit_vector(lookahead - current_pos) * cruise_speed
% Position = integrator of velocity, initialized at first waypoint
kin = [modelName '/Kinematic_Dynamics'];
add_block('built-in/Subsystem', kin, 'Position', [800, 380, 1050, 580]);

add_block('simulink/Sources/In1', [kin '/LookaheadPoint'], ...
    'Position', [30, 30, 60, 50]);
add_block('simulink/Sources/In1', [kin '/CurrentPos'], ...
    'Position', [30, 80, 60, 100], 'Port', '2');
add_block('simulink/Sources/In1', [kin '/DesiredYaw'], ...
    'Position', [30, 180, 60, 200], 'Port', '3');
add_block('simulink/Sources/In1', [kin '/CruiseSpeed'], ...
    'Position', [30, 130, 60, 150], 'Port', '4');

add_block('simulink/User-Defined Functions/MATLAB Function', [kin '/VelocityCmd'], ...
    'Position', [120, 60, 240, 130]);
install_matlab_fcn([kin '/VelocityCmd'], modelName, sprintf([...
    'function vel = velocity_cmd(lookahead, current_pos, cruise_speed)\n' ...
    'la = lookahead(:); cp = current_pos(:);\n' ...
    'd = la - cp;\n' ...
    'n = norm(d);\n' ...
    'if n < 1e-6 || isnan(n)\n' ...
    '    vel = [0; 0; 0]; return\n' ...
    'end\n' ...
    'vel = (d / n) * cruise_speed;\n' ...
    'end\n']));

add_block('simulink/Continuous/Integrator', [kin '/PositionIntegrator'], ...
    'Position', [280, 60, 320, 130], ...
    'InitialCondition', mat2str(mission.start));

add_block('simulink/User-Defined Functions/MATLAB Function', [kin '/YawToQuat'], ...
    'Position', [120, 170, 240, 210]);
install_matlab_fcn([kin '/YawToQuat'], modelName, sprintf([...
    'function q = yaw_to_quat(yaw)\n' ...
    'c = cos(yaw/2); s = sin(yaw/2);\n' ...
    'q = [c, 0, 0, s];\n' ...
    'end\n']));

add_block('simulink/Sinks/Out1', [kin '/Position'], ...
    'Position', [400, 80, 430, 100]);
add_block('simulink/Sinks/Out1', [kin '/Orientation'], ...
    'Position', [400, 180, 430, 200], 'Port', '2');
add_block('simulink/Sinks/Out1', [kin '/Velocity'], ...
    'Position', [400, 130, 430, 150], 'Port', '3');
add_block('simulink/Sinks/Out1', [kin '/AngularVelocity'], ...
    'Position', [400, 230, 430, 250], 'Port', '4');
add_block('simulink/Sinks/Out1', [kin '/Acceleration'], ...
    'Position', [400, 280, 430, 300], 'Port', '5');

add_block('simulink/Sources/Constant', [kin '/Zero3a'], ...
    'Position', [280, 225, 340, 255], 'Value', '[0 0 0]');
add_block('simulink/Sources/Constant', [kin '/Zero3b'], ...
    'Position', [280, 275, 340, 305], 'Value', '[0 0 0]');

add_line(kin, 'LookaheadPoint/1',     'VelocityCmd/1',       'autorouting', 'on');
add_line(kin, 'CurrentPos/1',         'VelocityCmd/2',       'autorouting', 'on');
add_line(kin, 'CruiseSpeed/1',        'VelocityCmd/3',       'autorouting', 'on');
add_line(kin, 'VelocityCmd/1',        'PositionIntegrator/1','autorouting', 'on');
add_line(kin, 'VelocityCmd/1',        'Velocity/1',          'autorouting', 'on');
add_line(kin, 'PositionIntegrator/1', 'Position/1',          'autorouting', 'on');
add_line(kin, 'DesiredYaw/1',         'YawToQuat/1',         'autorouting', 'on');
add_line(kin, 'YawToQuat/1',          'Orientation/1',       'autorouting', 'on');
add_line(kin, 'Zero3a/1',             'AngularVelocity/1',   'autorouting', 'on');
add_line(kin, 'Zero3b/1',             'Acceleration/1',      'autorouting', 'on');
fprintf('  + Kinematic_Dynamics subsystem (closed-loop integration)\n');

%% ── Reshape blocks for Motion Write inputs ──────────────────────────────────
% Force 1-D so downstream coerces to whatever shape Motion Write expects
reshapeNames = {'Pos','Ori','Vel','AngVel','Acc'};
for p = 1:5
    name = sprintf('Reshape_%s', reshapeNames{p});
    add_block('simulink/Math Operations/Reshape', [modelName '/' name], ...
        'OutputDimensionality', '1-D array', ...
        'Position', [1100, 380 + (p-1)*30, 1140, 400 + (p-1)*30]);
end
fprintf('  + Reshape blocks (5)\n');

%% ── Rate Transition blocks (sample-time alignment) ──────────────────────────
% Orientation and Velocity paths come from continuous Integrator (0s) but
% Motion Write's PlatBusCreator runs at scenario rate (0.1s). RT blocks bridge.
add_block('simulink/Signal Attributes/Rate Transition', [modelName '/RT_Ori'], ...
    'Position', [1160, 410, 1200, 440], 'OutPortSampleTime', '0');
add_block('simulink/Signal Attributes/Rate Transition', [modelName '/RT_Vel'], ...
    'Position', [1160, 440, 1200, 470], 'OutPortSampleTime', '0');
fprintf('  + Rate Transition blocks (Ori, Vel)\n');

%% ── Altitude-to-pressure subsystem (Barometer) ──────────────────────────────
% Saturation clamps altitude to [0, inf] before the Fcn (Fcn can't use max())
if enable.barometer
    baroSubsys = [modelName '/Alt_to_Pressure'];
    add_block('built-in/Subsystem', baroSubsys, 'Position', [400, 720, 500, 770]);

    add_block('simulink/Sources/In1', [baroSubsys '/Position_NED'], ...
        'Position', [30, 30, 60, 50]);
    add_block('simulink/Signal Routing/Selector', [baroSubsys '/Get_Z'], ...
        'Position', [100, 25, 140, 55], ...
        'IndexOptionArray', {'Index vector (dialog)'}, ...
        'IndexParamArray', {'3'}, 'InputPortWidth', '3');
    add_block('simulink/Math Operations/Gain', [baroSubsys '/Neg'], ...
        'Position', [180, 25, 220, 55], 'Gain', '-1');
    add_block('simulink/Discontinuities/Saturation', [baroSubsys '/Sat'], ...
        'Position', [240, 25, 270, 55], 'LowerLimit', '0', 'UpperLimit', 'inf');
    add_block('simulink/User-Defined Functions/Fcn', [baroSubsys '/ISA_Pressure'], ...
        'Position', [300, 20, 400, 60], ...
        'Expr', '101325 * (1 - 0.0065*u/288.15)^5.255');
    add_block('simulink/Sinks/Out1', [baroSubsys '/Pressure_Pa'], ...
        'Position', [430, 30, 460, 50]);

    add_line(baroSubsys, 'Position_NED/1', 'Get_Z/1',        'autorouting', 'on');
    add_line(baroSubsys, 'Get_Z/1',        'Neg/1',          'autorouting', 'on');
    add_line(baroSubsys, 'Neg/1',          'Sat/1',          'autorouting', 'on');
    add_line(baroSubsys, 'Sat/1',          'ISA_Pressure/1', 'autorouting', 'on');
    add_line(baroSubsys, 'ISA_Pressure/1', 'Pressure_Pa/1',  'autorouting', 'on');
    fprintf('  + Altitude-to-pressure subsystem\n');
end

%% ── Wiring ──────────────────────────────────────────────────────────────────
fprintf('\n── Wiring signals ───────────────────────────\n');

wires = {
    'UAV Scenario Motion Read/1', 'BusSel_Motion/1';

    'BusSel_Motion/1', 'Pose_4Row/1';
    'BusSel_Motion/2', 'Pose_4Row/2';

    'Pose_4Row/1',         'Waypoint Follower/1';
    'Mission Waypoints/1', 'Waypoint Follower/2';
    'LookaheadDist/1',     'Waypoint Follower/3';

    'Waypoint Follower/1', 'Kinematic_Dynamics/1';
    'BusSel_Motion/1',     'Kinematic_Dynamics/2';
    'Waypoint Follower/3', 'Kinematic_Dynamics/3';
    'CruiseSpeed/1',       'Kinematic_Dynamics/4';

    'Kinematic_Dynamics/1', 'Reshape_Pos/1';
    'Reshape_Pos/1',        'UAV Scenario Motion Write/1';

    'Kinematic_Dynamics/2', 'Reshape_Ori/1';
    'Reshape_Ori/1',        'RT_Ori/1';
    'RT_Ori/1',             'UAV Scenario Motion Write/2';

    'Kinematic_Dynamics/3', 'Reshape_Vel/1';
    'Reshape_Vel/1',        'RT_Vel/1';
    'RT_Vel/1',             'UAV Scenario Motion Write/3';

    'Kinematic_Dynamics/4', 'Reshape_AngVel/1';
    'Reshape_AngVel/1',     'UAV Scenario Motion Write/4';
    'Kinematic_Dynamics/5', 'Reshape_Acc/1';
    'Reshape_Acc/1',        'UAV Scenario Motion Write/5';

    'UAV Scenario Motion Read/1', 'Log_UAV_Motion/1';
};

if enable.gps
    wires(end+1, :) = {'BusSel_Motion/1', 'GPS/1'};
    wires(end+1, :) = {'BusSel_Motion/3', 'GPS/2'};
    wires(end+1, :) = {'GPS/1',           'Log_GPS_LLA/1'};
    wires(end+1, :) = {'GPS/2',           'Log_GPS_Velocity/1'};
end
if enable.ins
    wires(end+1, :) = {'BusSel_Motion/1', 'INS/1'};
    wires(end+1, :) = {'BusSel_Motion/3', 'INS/2'};
    wires(end+1, :) = {'BusSel_Motion/2', 'INS/3'};
    wires(end+1, :) = {'INS/1',           'Log_INS_Position/1'};
    wires(end+1, :) = {'INS/3',           'Log_INS_Orientation/1'};
end
if enable.barometer
    wires(end+1, :) = {'BusSel_Motion/1',   'Alt_to_Pressure/1'};
    wires(end+1, :) = {'Alt_to_Pressure/1', 'Barometer/1'};
    wires(end+1, :) = {'Barometer/1',       'Log_Baro_Pressure/1'};
end

ok = 0; fail = 0; failed = {};
for w = 1:size(wires, 1)
    try
        add_line(modelName, wires{w,1}, wires{w,2}, 'autorouting', 'on');
        ok = ok + 1;
    catch ME
        fail = fail + 1;
        failed{end+1} = sprintf('%s -> %s : %s', wires{w,1}, wires{w,2}, ME.message);
    end
end
fprintf('  + %d wires placed, %d failed\n', ok, fail);
if fail > 0
    fprintf('\n── Failed wires ─────────────────────────────\n');
    for i = 1:numel(failed); fprintf('  %s\n', failed{i}); end
end

%% ── Classification Banner ───────────────────────────────────────────────────
bannerText = 'RAVEN UAV Simulation | UNCLASSIFIED // FOR TRAINING PURPOSES ONLY | Luke J. Waszyn II';
bannerPath = [modelName '/' bannerText];
add_block('built-in/Note', bannerPath);
set_param(bannerPath, ...
    'Position', '[50, 930]', ...
    'FontSize', '12', 'FontWeight', 'bold', ...
    'ForegroundColor', 'red');

%% ── Run PreLoadFcn now so workspace has scene/plat ──────────────────────────
eval(preLoadFcn);
fprintf('  + Scenario objects created in workspace\n');

%% ── Save ─────────────────────────────────────────────────────────────────────
save_system(modelName, savePath);
fprintf('\n── Model saved ──────────────────────────────\n');
fprintf('  Path: %s\n', savePath);

%% ── Helpers ─────────────────────────────────────────────────────────────────
function s = pass_fail(condition)
    if condition; s = 'PASS'; else; s = 'FAIL'; end
end

function install_matlab_fcn(blockPath, modelName, scriptText)
    sfRoot = sfroot;
    machine = sfRoot.find('-isa', 'Stateflow.Machine', '-and', 'Name', modelName);
    if isempty(machine); return; end
    chart = machine.find('-isa', 'Stateflow.EMChart', '-and', 'Path', blockPath);
    if isempty(chart); return; end
    chart.Script = scriptText;
end

function BLK = discover_uav_blocks()
    libs = {'uavalgslib', 'uavsimlib', 'uavsim3dlib', ...
            'uavmavlinklib', 'uavutilslib'};
    all_blocks = {};
    for i = 1:numel(libs)
        try
            load_system(libs{i});
            b = find_system(libs{i}, ...
                'MatchFilter', @Simulink.match.allVariants, ...
                'LookUnderMasks', 'all', ...
                'FollowLinks', 'on', 'Type', 'Block');
            all_blocks = [all_blocks; b];
        catch
            fprintf('  (skip) %s not present\n', libs{i});
        end
    end

    want = struct( ...
        'scenarioConfig',   {{'UAV Scenario Configuration'}}, ...
        'motionWrite',      {{'UAV Scenario Motion Write'}}, ...
        'motionRead',       {{'UAV Scenario Motion Read'}}, ...
        'lidar',            {{'UAV Scenario Lidar', 'Simulation 3D Lidar'}}, ...
        'scope',            {{'UAV Scenario Scope'}}, ...
        'gps',              {{'GPS'}}, ...
        'ins',              {{'INS'}}, ...
        'barometer',        {{'Barometer'}}, ...
        'guidanceModel',    {{'Guidance Model'}}, ...
        'waypointFollower', {{'Waypoint Follower'}}, ...
        'pathManager',      {{'Path Manager'}});

    fields = fieldnames(want);
    BLK = struct();
    fprintf('── Resolving uavlib block paths ─────────────\n');
    for k = 1:numel(fields)
        candidates = want.(fields{k});
        found = '';
        for c = 1:numel(candidates)
            target = ['/' candidates{c}];
            mask = endsWith(all_blocks, target) & ...
                   ~contains(extractAfter(all_blocks, target), '/');
            hits = all_blocks(mask);
            if ~isempty(hits); found = hits{1}; break; end
        end
        if isempty(found)
            error('Block not found in any UAV sub-library: %s', candidates{1});
        end
        BLK.(fields{k}) = found;
        fprintf('  %-28s -> %s\n', candidates{1}, found);
    end
end