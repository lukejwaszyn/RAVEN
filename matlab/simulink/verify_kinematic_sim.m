%% RAVEN Kinematic Sim — Verification
% Runs the open-loop trajectory generator and plots the result.
%
% Place this and kinematic_sim.m in the same directory, then run this.

clear; clc; close all;

%% Mission
waypoints = [
      0,    0, -30;
     50,    0, -30;
     50,  100, -30;
    -50,  100, -30;
    -50,    0, -30;
      0,    0, -30;
];
cruise_speed = 5.0;
dt           = 0.01;

%% Run
out = kinematic_sim(waypoints, cruise_speed, dt);

fprintf('── RAVEN Kinematic Sim ──────────────────\n');
fprintf('  Waypoints:        %d\n',       size(waypoints, 1));
fprintf('  Cruise speed:     %.1f m/s\n', cruise_speed);
fprintf('  Time step:        %.3f s\n',   dt);
fprintf('  Samples logged:   %d\n',       length(out.t));
fprintf('  Sim duration:     %.1f s\n',   out.t(end));
fprintf('  Path length:      %.1f m\n',   sum(vecnorm(diff(out.pos), 2, 2)));

%% Plot 1: Top-down lawnmower track
figure('Name', 'RAVEN Mission Track', 'Color', 'w');
plot(out.pos(:, 2), out.pos(:, 1), 'b-', 'LineWidth', 1.5);
hold on;
plot(waypoints(:, 2), waypoints(:, 1), 'r--o', ...
    'LineWidth', 1, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot(out.pos(1, 2), out.pos(1, 1), 'go', ...
    'MarkerSize', 12, 'LineWidth', 2);
plot(out.pos(end, 2), out.pos(end, 1), 'mx', ...
    'MarkerSize', 12, 'LineWidth', 2);
xlabel('East (m)'); ylabel('North (m)');
title('RAVEN Lawnmower Mission Track');
legend('Flight path', 'Waypoints', 'Start', 'End', 'Location', 'best');
axis equal; grid on;

%% Plot 2: Altitude profile
figure('Name', 'Altitude Profile', 'Color', 'w');
plot(out.t, -out.pos(:, 3), 'b-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Altitude AGL (m)');
title('Altitude profile'); grid on;

%% Plot 3: Velocity components
figure('Name', 'Velocity', 'Color', 'w');
plot(out.t, out.vel(:, 1), 'r-', 'LineWidth', 1.2); hold on;
plot(out.t, out.vel(:, 2), 'g-', 'LineWidth', 1.2);
plot(out.t, out.vel(:, 3), 'b-', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('Velocity (m/s)');
title('Velocity components (NED)');
legend('vN', 'vE', 'vD', 'Location', 'best'); grid on;

%% Plot 4: Heading
figure('Name', 'Heading', 'Color', 'w');
plot(out.t, rad2deg(out.yaw), 'k-', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('Heading (deg)');
title('Heading angle'); grid on;