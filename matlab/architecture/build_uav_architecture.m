% RAVEN System Architecture — Programmatic Build Script
% Reconnaissance Autonomous Vehicle with Electronic iNtelligence
% Generated May 2026 | L0 → L2 Architecture
% Run from /Users/lukewaszyn/RAVEN/ with MATLAB project open
% Save path: /Users/lukewaszyn/RAVEN/matlab/architecture/

% ── Clean slate ──
close all;
bdclose all;

% ── Create architecture model ──
modelName = 'RavenSystem';
archModel = systemcomposer.createModel(modelName);
arch = get(archModel, 'Architecture');

savePath = '/Users/lukewaszyn/RAVEN/matlab/architecture/RavenSystem.slx';
save_system(modelName, savePath);

%% ════════════════════════════════════════════════════════════
%  L0 — RAVEN System Boundary
%  Top level components: GCS, AVS, DataLink
%% ════════════════════════════════════════════════════════════

% ── L0 Components ──
gcs = addComponent(arch, 'GroundControlSegment');
avs = addComponent(arch, 'AerialVehicleSegment');
dl  = addComponent(arch, 'DataLink');

% ── L0 Ports on DataLink ──
addPort(dl.Architecture, 'GcsInterface',    'in');
addPort(dl.Architecture, 'AvsInterface',    'out');

% ── L0 Ports on GCS ──
addPort(gcs.Architecture, 'DataLinkOut',    'out');
addPort(gcs.Architecture, 'DataLinkIn',     'in');

% ── L0 Ports on AVS ──
addPort(avs.Architecture, 'DataLinkIn',     'in');
addPort(avs.Architecture, 'DataLinkOut',    'out');

% ── L0 Connections ──
connect(arch, ...
    getPort(gcs, 'DataLinkOut'), ...
    getPort(dl,  'GcsInterface'));
connect(arch, ...
    getPort(dl,  'AvsInterface'), ...
    getPort(avs, 'DataLinkIn'));


%% ════════════════════════════════════════════════════════════
%  L1 — Ground Control Segment Decomposition
%  MissionControl, FlightTelemetry, DataProcessing
%% ════════════════════════════════════════════════════════════

gcsArch = get(gcs, 'Architecture');

% ── L1 GCS Components ──
mc = addComponent(gcsArch, 'MissionControl');
ft = addComponent(gcsArch, 'FlightTelemetry');
dp = addComponent(gcsArch, 'DataProcessing');

% ── MissionControl Ports ──
addPort(mc.Architecture, 'MavlinkCmdOut',       'out');
addPort(mc.Architecture, 'TelemetryIn',         'in');
addPort(mc.Architecture, 'AbortCmdOut',         'out');
addPort(mc.Architecture, 'MissionStatusIn',     'in');

% ── FlightTelemetry Ports ──
addPort(ft.Architecture, 'MavlinkCmdIn',        'in');
addPort(ft.Architecture, 'TelemetryOut',        'out');
addPort(ft.Architecture, 'LinkHealthOut',       'out');
addPort(ft.Architecture, 'DataLinkOut',         'out');
addPort(ft.Architecture, 'DataLinkIn',          'in');

% ── DataProcessing Ports ──
addPort(dp.Architecture, 'IqStreamIn',          'in');
addPort(dp.Architecture, 'LidarDataIn',         'in');
addPort(dp.Architecture, 'GeoreferencedRfOut',  'out');
addPort(dp.Architecture, 'FusedDataProductOut', 'out');
addPort(dp.Architecture, 'SpectrumDisplayOut',  'out');

% ── GCS Boundary Ports ──
addPort(gcsArch, 'DataLinkOut', 'out');
addPort(gcsArch, 'DataLinkIn',  'in');

% ── L1 GCS Internal Connections ──
connect(gcsArch, ...
    getPort(mc, 'MavlinkCmdOut'), ...
    getPort(ft, 'MavlinkCmdIn'));
connect(gcsArch, ...
    getPort(ft, 'TelemetryOut'), ...
    getPort(mc, 'TelemetryIn'));
connect(gcsArch, ...
    getPort(ft, 'LinkHealthOut'), ...
    getPort(mc, 'MissionStatusIn'));


%% ════════════════════════════════════════════════════════════
%  L1 — Aerial Vehicle Segment Decomposition
%  Structures, Propulsion, FlightControl,
%  FlightComputer, RfSdr, Lidar, Power
%% ════════════════════════════════════════════════════════════

avsArch = get(avs, 'Architecture');

% ── L1 AVS Components ──
st = addComponent(avsArch, 'Structures');
pr = addComponent(avsArch, 'Propulsion');
fc = addComponent(avsArch, 'FlightControl');
cp = addComponent(avsArch, 'FlightComputer');
rf = addComponent(avsArch, 'RfSdr');
li = addComponent(avsArch, 'Lidar');
pw = addComponent(avsArch, 'Power');

% ── Structures Ports ──
addPort(st.Architecture, 'MechanicalSupportOut', 'out');

% ── Propulsion Ports ──
addPort(pr.Architecture, 'MotorCmdIn',    'in');
addPort(pr.Architecture, 'PowerIn',       'in');
addPort(pr.Architecture, 'ThrustOut',     'out');

% ── FlightControl Ports ──
addPort(fc.Architecture, 'MavlinkCmdIn',  'in');
addPort(fc.Architecture, 'MavlinkTlmOut', 'out');
addPort(fc.Architecture, 'MotorCmdOut',   'out');
addPort(fc.Architecture, 'PowerIn',       'in');

% ── FlightComputer Ports ──
addPort(cp.Architecture, 'DataLinkIn',    'in');
addPort(cp.Architecture, 'DataLinkOut',   'out');
addPort(cp.Architecture, 'MavlinkOut',    'out');
addPort(cp.Architecture, 'MavlinkIn',     'in');
addPort(cp.Architecture, 'IqStreamIn',    'in');
addPort(cp.Architecture, 'PointCloudIn',  'in');
addPort(cp.Architecture, 'PowerIn',       'in');

% ── RfSdr Ports ──
addPort(rf.Architecture, 'IqStreamOut',   'out');
addPort(rf.Architecture, 'PowerIn',       'in');

% ── Lidar Ports ──
addPort(li.Architecture, 'PointCloudOut', 'out');
addPort(li.Architecture, 'PowerIn',       'in');

% ── Power Ports ──
addPort(pw.Architecture, 'FlightPowerOut',  'out');
addPort(pw.Architecture, 'RegulatedPwrOut', 'out');

% ── AVS Boundary Ports ──
addPort(avsArch, 'DataLinkIn',  'in');
addPort(avsArch, 'DataLinkOut', 'out');

% ── L1 AVS Internal Connections ──
connect(avsArch, ...
    getPort(fc,  'MotorCmdOut'), ...
    getPort(pr,  'MotorCmdIn'));
connect(avsArch, ...
    getPort(cp,  'MavlinkOut'), ...
    getPort(fc,  'MavlinkCmdIn'));
connect(avsArch, ...
    getPort(fc,  'MavlinkTlmOut'), ...
    getPort(cp,  'MavlinkIn'));
connect(avsArch, ...
    getPort(rf,  'IqStreamOut'), ...
    getPort(cp,  'IqStreamIn'));
connect(avsArch, ...
    getPort(li,  'PointCloudOut'), ...
    getPort(cp,  'PointCloudIn'));
connect(avsArch, ...
    getPort(pw,  'FlightPowerOut'), ...
    getPort(pr,  'PowerIn'));
connect(avsArch, ...
    getPort(pw,  'FlightPowerOut'), ...
    getPort(fc,  'PowerIn'));
connect(avsArch, ...
    getPort(pw,  'FlightPowerOut'), ...
    getPort(rf,  'PowerIn'));
connect(avsArch, ...
    getPort(pw,  'FlightPowerOut'), ...
    getPort(li,  'PowerIn'));
connect(avsArch, ...
    getPort(pw,  'RegulatedPwrOut'), ...
    getPort(cp,  'PowerIn'));


%% ════════════════════════════════════════════════════════════
%  L2 — MissionControl Decomposition
%  WaypointPlanner, MissionExecutor, AbortController
%% ════════════════════════════════════════════════════════════

mcArch = get(mc, 'Architecture');

wp  = addComponent(mcArch, 'WaypointPlanner');
me  = addComponent(mcArch, 'MissionExecutor');
ac  = addComponent(mcArch, 'AbortController');

addPort(wp.Architecture,  'WaypointListOut',    'out');
addPort(me.Architecture,  'WaypointListIn',     'in');
addPort(me.Architecture,  'MavlinkCmdOut',      'out');
addPort(me.Architecture,  'MissionStatusOut',   'out');
addPort(ac.Architecture,  'AbortCmdOut',        'out');
addPort(ac.Architecture,  'TelemetryIn',        'in');

addPort(mcArch, 'MavlinkCmdOut',    'out');
addPort(mcArch, 'TelemetryIn',      'in');
addPort(mcArch, 'AbortCmdOut',      'out');
addPort(mcArch, 'MissionStatusIn',  'in');

connect(mcArch, ...
    getPort(wp, 'WaypointListOut'), ...
    getPort(me, 'WaypointListIn'));
connect(mcArch, ...
    getPort(me, 'MavlinkCmdOut'), ...
    getPort(mcArch, 'MavlinkCmdOut'));
connect(mcArch, ...
    getPort(ac, 'AbortCmdOut'), ...
    getPort(mcArch, 'AbortCmdOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — FlightTelemetry Decomposition
%  MavlinkParser, LinkHealthMonitor, TelemetryRouter
%% ════════════════════════════════════════════════════════════

ftArch = get(ft, 'Architecture');

mp  = addComponent(ftArch, 'MavlinkParser');
lh  = addComponent(ftArch, 'LinkHealthMonitor');
tr  = addComponent(ftArch, 'TelemetryRouter');

addPort(mp.Architecture,  'RawMavlinkIn',       'in');
addPort(mp.Architecture,  'ParsedTlmOut',       'out');
addPort(lh.Architecture,  'HeartbeatIn',        'in');
addPort(lh.Architecture,  'LinkStatusOut',      'out');
addPort(tr.Architecture,  'TelemetryIn',        'in');
addPort(tr.Architecture,  'MavlinkCmdIn',       'in');
addPort(tr.Architecture,  'DataLinkOut',        'out');

addPort(ftArch, 'MavlinkCmdIn',  'in');
addPort(ftArch, 'TelemetryOut',  'out');
addPort(ftArch, 'LinkHealthOut', 'out');
addPort(ftArch, 'DataLinkOut',   'out');
addPort(ftArch, 'DataLinkIn',    'in');

connect(ftArch, ...
    getPort(mp, 'ParsedTlmOut'), ...
    getPort(tr, 'TelemetryIn'));
connect(ftArch, ...
    getPort(lh, 'LinkStatusOut'), ...
    getPort(ftArch, 'LinkHealthOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — DataProcessing Decomposition
%  IqIngestion, LidarIngestion, Georeferencer, DataFusion, SpectrumDisplay
%% ════════════════════════════════════════════════════════════

dpArch = get(dp, 'Architecture');

iq  = addComponent(dpArch, 'IqIngestion');
lg  = addComponent(dpArch, 'LidarIngestion');
gr  = addComponent(dpArch, 'Georeferencer');
df  = addComponent(dpArch, 'DataFusion');
sd  = addComponent(dpArch, 'SpectrumDisplay');

addPort(iq.Architecture,  'RawIqIn',            'in');
addPort(iq.Architecture,  'SpectrumSnapshotOut', 'out');
addPort(lg.Architecture,  'RawPointCloudIn',    'in');
addPort(lg.Architecture,  'TaggedCloudOut',     'out');
addPort(gr.Architecture,  'SpectrumIn',         'in');
addPort(gr.Architecture,  'PointCloudIn',       'in');
addPort(gr.Architecture,  'GpsTagIn',           'in');
addPort(gr.Architecture,  'GeoreferencedRfOut', 'out');
addPort(gr.Architecture,  'GeoreferencedLiOut', 'out');
addPort(df.Architecture,  'GeoreferencedRfIn',  'in');
addPort(df.Architecture,  'GeoreferencedLiIn',  'in');
addPort(df.Architecture,  'FusedProductOut',    'out');
addPort(sd.Architecture,  'SpectrumIn',         'in');
addPort(sd.Architecture,  'DisplayOut',         'out');

addPort(dpArch, 'IqStreamIn',           'in');
addPort(dpArch, 'LidarDataIn',          'in');
addPort(dpArch, 'GeoreferencedRfOut',   'out');
addPort(dpArch, 'FusedDataProductOut',  'out');
addPort(dpArch, 'SpectrumDisplayOut',   'out');

connect(dpArch, ...
    getPort(iq, 'SpectrumSnapshotOut'), ...
    getPort(gr, 'SpectrumIn'));
connect(dpArch, ...
    getPort(lg, 'TaggedCloudOut'), ...
    getPort(gr, 'PointCloudIn'));
connect(dpArch, ...
    getPort(gr, 'GeoreferencedRfOut'), ...
    getPort(df, 'GeoreferencedRfIn'));
connect(dpArch, ...
    getPort(gr, 'GeoreferencedLiOut'), ...
    getPort(df, 'GeoreferencedLiIn'));
connect(dpArch, ...
    getPort(iq, 'SpectrumSnapshotOut'), ...
    getPort(sd, 'SpectrumIn'));


%% ════════════════════════════════════════════════════════════
%  L2 — FlightControl Decomposition
%  Pixhawk6cMini, ArduPilot, AttitudeController, WaypointExecutor
%% ════════════════════════════════════════════════════════════

fcArch = get(fc, 'Architecture');

px  = addComponent(fcArch, 'Pixhawk6cMini');
ap  = addComponent(fcArch, 'ArduPilot');
att = addComponent(fcArch, 'AttitudeController');
we  = addComponent(fcArch, 'WaypointExecutor');

addPort(px.Architecture,  'MavlinkIn',      'in');
addPort(px.Architecture,  'MavlinkOut',     'out');
addPort(px.Architecture,  'ImuDataOut',     'out');
addPort(px.Architecture,  'BaroDataOut',    'out');
addPort(px.Architecture,  'GpsDataOut',     'out');
addPort(ap.Architecture,  'ImuIn',          'in');
addPort(ap.Architecture,  'BaroIn',         'in');
addPort(ap.Architecture,  'GpsIn',          'in');
addPort(ap.Architecture,  'WaypointIn',     'in');
addPort(ap.Architecture,  'AttitudeCmdOut', 'out');
addPort(att.Architecture, 'AttitudeCmdIn',  'in');
addPort(att.Architecture, 'MotorCmdOut',    'out');
addPort(we.Architecture,  'MavlinkCmdIn',   'in');
addPort(we.Architecture,  'WaypointOut',    'out');

addPort(fcArch, 'MavlinkCmdIn',  'in');
addPort(fcArch, 'MavlinkTlmOut', 'out');
addPort(fcArch, 'MotorCmdOut',   'out');
addPort(fcArch, 'PowerIn',       'in');

connect(fcArch, ...
    getPort(px,  'ImuDataOut'), ...
    getPort(ap,  'ImuIn'));
connect(fcArch, ...
    getPort(px,  'BaroDataOut'), ...
    getPort(ap,  'BaroIn'));
connect(fcArch, ...
    getPort(px,  'GpsDataOut'), ...
    getPort(ap,  'GpsIn'));
connect(fcArch, ...
    getPort(ap,  'AttitudeCmdOut'), ...
    getPort(att, 'AttitudeCmdIn'));
connect(fcArch, ...
    getPort(we,  'WaypointOut'), ...
    getPort(ap,  'WaypointIn'));
connect(fcArch, ...
    getPort(att, 'MotorCmdOut'), ...
    getPort(fcArch, 'MotorCmdOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — FlightComputer Decomposition
%  RaspberryPi5, UavDaemon, MavlinkBridge,
%  RtlTcpServer, LidarDriver, GpsDaemon
%% ════════════════════════════════════════════════════════════

cpArch = get(cp, 'Architecture');

pi5 = addComponent(cpArch, 'RaspberryPi5');
ud  = addComponent(cpArch, 'UavDaemon');
mb  = addComponent(cpArch, 'MavlinkBridge');
rts = addComponent(cpArch, 'RtlTcpServer');
ld  = addComponent(cpArch, 'LidarDriver');
gpsd = addComponent(cpArch, 'GpsDaemon');

addPort(pi5.Architecture,  'ComputeOut',      'out');
addPort(ud.Architecture,   'ComputeIn',       'in');
addPort(ud.Architecture,   'MavlinkBridgeOut','out');
addPort(ud.Architecture,   'RtlTcpOut',       'out');
addPort(ud.Architecture,   'LidarLogOut',     'out');
addPort(ud.Architecture,   'GpsTagIn',        'in');
addPort(mb.Architecture,   'UartMavlinkIn',   'in');
addPort(mb.Architecture,   'WifiMavlinkOut',  'out');
addPort(mb.Architecture,   'WifiMavlinkIn',   'in');
addPort(mb.Architecture,   'UartMavlinkOut',  'out');
addPort(rts.Architecture,  'IqDataIn',        'in');
addPort(rts.Architecture,  'IqStreamOut',     'out');
addPort(ld.Architecture,   'RawScanIn',       'in');
addPort(ld.Architecture,   'PointCloudOut',   'out');
addPort(gpsd.Architecture, 'GpsCoordOut',     'out');

addPort(cpArch, 'DataLinkIn',   'in');
addPort(cpArch, 'DataLinkOut',  'out');
addPort(cpArch, 'MavlinkOut',   'out');
addPort(cpArch, 'MavlinkIn',    'in');
addPort(cpArch, 'IqStreamIn',   'in');
addPort(cpArch, 'PointCloudIn', 'in');
addPort(cpArch, 'PowerIn',      'in');

connect(cpArch, ...
    getPort(gpsd, 'GpsCoordOut'), ...
    getPort(ud,   'GpsTagIn'));
connect(cpArch, ...
    getPort(rts,  'IqStreamOut'), ...
    getPort(cpArch, 'DataLinkOut'));
connect(cpArch, ...
    getPort(ld,   'PointCloudOut'), ...
    getPort(ud,   'LidarLogOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — RfSdr Decomposition
%  RtlSdrV4, SmaAntenna, UsbInterface
%% ════════════════════════════════════════════════════════════

rfArch = get(rf, 'Architecture');

sdr  = addComponent(rfArch, 'RtlSdrV4');
ant  = addComponent(rfArch, 'SmaAntenna');
usb  = addComponent(rfArch, 'UsbInterface');

addPort(ant.Architecture,  'RfSignalOut',   'out');
addPort(sdr.Architecture,  'RfSignalIn',    'in');
addPort(sdr.Architecture,  'IqDataOut',     'out');
addPort(usb.Architecture,  'IqDataIn',      'in');
addPort(usb.Architecture,  'IqStreamOut',   'out');

addPort(rfArch, 'IqStreamOut', 'out');
addPort(rfArch, 'PowerIn',     'in');

connect(rfArch, ...
    getPort(ant, 'RfSignalOut'), ...
    getPort(sdr, 'RfSignalIn'));
connect(rfArch, ...
    getPort(sdr, 'IqDataOut'), ...
    getPort(usb, 'IqDataIn'));
connect(rfArch, ...
    getPort(usb, 'IqStreamOut'), ...
    getPort(rfArch, 'IqStreamOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — Lidar Decomposition
%  RplidarA1M8, LidarUsbInterface
%% ════════════════════════════════════════════════════════════

liArch = get(li, 'Architecture');

rpli = addComponent(liArch, 'RplidarA1M8');
lusb = addComponent(liArch, 'LidarUsbInterface');

addPort(rpli.Architecture, 'RawScanOut',    'out');
addPort(lusb.Architecture, 'RawScanIn',     'in');
addPort(lusb.Architecture, 'PointCloudOut', 'out');

addPort(liArch, 'PointCloudOut', 'out');
addPort(liArch, 'PowerIn',       'in');

connect(liArch, ...
    getPort(rpli, 'RawScanOut'), ...
    getPort(lusb, 'RawScanIn'));
connect(liArch, ...
    getPort(lusb, 'PointCloudOut'), ...
    getPort(liArch, 'PointCloudOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — Power Decomposition
%  LipoBattery4S, PowerDistributionBoard, Bec5V
%% ════════════════════════════════════════════════════════════

pwArch = get(pw, 'Architecture');

lipo = addComponent(pwArch, 'LipoBattery4S');
pdb  = addComponent(pwArch, 'PowerDistributionBoard');
bec  = addComponent(pwArch, 'Bec5V');

addPort(lipo.Architecture, 'RawPowerOut',       'out');
addPort(pdb.Architecture,  'RawPowerIn',        'in');
addPort(pdb.Architecture,  'FlightPowerOut',    'out');
addPort(pdb.Architecture,  'BecPowerOut',       'out');
addPort(bec.Architecture,  'UnregulatedIn',     'in');
addPort(bec.Architecture,  'RegulatedPwrOut',   'out');

addPort(pwArch, 'FlightPowerOut',  'out');
addPort(pwArch, 'RegulatedPwrOut', 'out');

connect(pwArch, ...
    getPort(lipo, 'RawPowerOut'), ...
    getPort(pdb,  'RawPowerIn'));
connect(pwArch, ...
    getPort(pdb,  'BecPowerOut'), ...
    getPort(bec,  'UnregulatedIn'));
connect(pwArch, ...
    getPort(pdb,  'FlightPowerOut'), ...
    getPort(pwArch, 'FlightPowerOut'));
connect(pwArch, ...
    getPort(bec,  'RegulatedPwrOut'), ...
    getPort(pwArch, 'RegulatedPwrOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — DataLink Decomposition
%  WifiLink, Rfd900xLink, LinkManager
%% ════════════════════════════════════════════════════════════

dlArch = get(dl, 'Architecture');

wifi = addComponent(dlArch, 'WifiLink');
rfd  = addComponent(dlArch, 'Rfd900xLink');
lm   = addComponent(dlArch, 'LinkManager');

addPort(wifi.Architecture, 'DataIn',        'in');
addPort(wifi.Architecture, 'DataOut',       'out');
addPort(rfd.Architecture,  'MavlinkIn',     'in');
addPort(rfd.Architecture,  'MavlinkOut',    'out');
addPort(lm.Architecture,   'PrimaryIn',     'in');
addPort(lm.Architecture,   'ContingencyIn', 'in');
addPort(lm.Architecture,   'ActiveLinkOut', 'out');
addPort(lm.Architecture,   'LinkStatusOut', 'out');

addPort(dlArch, 'GcsInterface', 'in');
addPort(dlArch, 'AvsInterface', 'out');

connect(dlArch, ...
    getPort(wifi, 'DataOut'), ...
    getPort(lm,   'PrimaryIn'));
connect(dlArch, ...
    getPort(rfd,  'MavlinkOut'), ...
    getPort(lm,   'ContingencyIn'));
connect(dlArch, ...
    getPort(lm,   'ActiveLinkOut'), ...
    getPort(dlArch, 'AvsInterface'));


%% ════════════════════════════════════════════════════════════
%  L2 — Structures Decomposition
%  F450Frame, PayloadMount, AntennaMount, LandingGear
%% ════════════════════════════════════════════════════════════

stArch = get(st, 'Architecture');

frm = addComponent(stArch, 'F450Frame');
pm  = addComponent(stArch, 'PayloadMount');
am  = addComponent(stArch, 'AntennaMount');
lg2 = addComponent(stArch, 'LandingGear');

addPort(frm.Architecture, 'StructuralSupportOut', 'out');
addPort(pm.Architecture,  'StructuralSupportIn',  'in');
addPort(pm.Architecture,  'PayloadMountOut',      'out');
addPort(am.Architecture,  'AntennaMountOut',      'out');
addPort(lg2.Architecture, 'GroundSupportOut',     'out');

addPort(stArch, 'MechanicalSupportOut', 'out');

connect(stArch, ...
    getPort(frm, 'StructuralSupportOut'), ...
    getPort(pm,  'StructuralSupportIn'));
connect(stArch, ...
    getPort(pm,  'PayloadMountOut'), ...
    getPort(stArch, 'MechanicalSupportOut'));


%% ════════════════════════════════════════════════════════════
%  L2 — Propulsion Decomposition
%  Motor1..4, Esc1..4, Propeller1..4
%% ════════════════════════════════════════════════════════════

prArch = get(pr, 'Architecture');

for i = 1:4
    m = addComponent(prArch, sprintf('Motor%d', i));
    e = addComponent(prArch, sprintf('Esc%d', i));
    p = addComponent(prArch, sprintf('Propeller%d', i));

    addPort(m.Architecture, 'PwmIn',      'in');
    addPort(m.Architecture, 'PowerIn',    'in');
    addPort(m.Architecture, 'ShaftOut',   'out');
    addPort(e.Architecture, 'PwmCmdIn',   'in');
    addPort(e.Architecture, 'PowerIn',    'in');
    addPort(e.Architecture, 'PwmOut',     'out');
    addPort(p.Architecture, 'ShaftIn',    'in');
    addPort(p.Architecture, 'ThrustOut',  'out');

    connect(prArch, ...
        getPort(e, 'PwmOut'), ...
        getPort(m, 'PwmIn'));
    connect(prArch, ...
        getPort(m, 'ShaftOut'), ...
        getPort(p, 'ShaftIn'));
end

addPort(prArch, 'MotorCmdIn', 'in');
addPort(prArch, 'PowerIn',    'in');
addPort(prArch, 'ThrustOut',  'out');


%% ════════════════════════════════════════════════════════════
%  Save and open
%% ════════════════════════════════════════════════════════════

save_system(modelName, savePath);
fprintf('RAVEN System Architecture built and saved to:\n%s\n', savePath);
systemcomposer.openModel(modelName);
