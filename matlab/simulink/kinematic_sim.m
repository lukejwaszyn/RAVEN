function out = kinematic_sim(waypoints, cruise_speed, dt)
% RAVEN UAV kinematic trajectory generator
% Open-loop: ideal flight following a sequence of NED waypoints at constant
% cruise speed. No dynamics, no closed loop, no controller.
%
% Inputs:
%   waypoints     [N x 3] NED positions (North, East, Down) in meters
%   cruise_speed  scalar cruise speed in m/s
%   dt            simulation time step in seconds
%
% Output struct fields:
%   t        [M x 1] time vector (s)
%   pos      [M x 3] NED position at each step
%   vel      [M x 3] NED velocity at each step
%   yaw      [M x 1] heading angle (rad), pointing toward next waypoint
%   wp_idx   [M x 1] index of waypoint being tracked at each step
%
% Example:
%   wp = [0 0 -30; 50 0 -30; 50 100 -30; -50 100 -30; -50 0 -30; 0 0 -30];
%   out = kinematic_sim(wp, 5.0, 0.01);

if nargin < 3; dt = 0.01;  end
if nargin < 2; cruise_speed = 5.0; end

pos = waypoints(1, :);
t = 0;

log_t = []; log_p = []; log_v = []; log_yaw = []; log_idx = [];

for wp_idx = 2:size(waypoints, 1)
    target = waypoints(wp_idx, :);
    while norm(target - pos) > cruise_speed * dt
        dir = (target - pos) / norm(target - pos);
        vel = dir * cruise_speed;
        yaw = atan2(dir(2), dir(1));  % heading from N/E components

        log_t(end+1, 1)   = t;            %#ok<AGROW>
        log_p(end+1, :)   = pos;          %#ok<AGROW>
        log_v(end+1, :)   = vel;          %#ok<AGROW>
        log_yaw(end+1, 1) = yaw;          %#ok<AGROW>
        log_idx(end+1, 1) = wp_idx;       %#ok<AGROW>

        pos = pos + vel * dt;
        t   = t + dt;
    end
    pos = target;  % snap to waypoint
end

% Final sample at the last waypoint, zero velocity
log_t(end+1, 1)   = t;
log_p(end+1, :)   = pos;
log_v(end+1, :)   = [0 0 0];
log_yaw(end+1, 1) = log_yaw(end);
log_idx(end+1, 1) = size(waypoints, 1);

out.t      = log_t;
out.pos    = log_p;
out.vel    = log_v;
out.yaw    = log_yaw;
out.wp_idx = log_idx;
out.waypoints    = waypoints;
out.cruise_speed = cruise_speed;
out.dt           = dt;
end