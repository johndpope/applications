% File: five.m
% ------------
% This script file is to demonstrate how to set up the STATE-BASED
% trajectory generator mtMultiStates (kinetic Monte Carlo simulation).
% Each model(i) represents a state. Parameters are extracted from a 
% published 4-state model (see reference). The fifth state (growth 2)
% is hypothetical.
%
% Reference:
% Keller et al. Three-dimensional microtubule behavior in Xenopus egg 
% extracts reveals four dynamic states and state-dependent elastic 
% properties. Biophys. J. 95: 1474-1486 (2008)
%
% Pei-hsin Hsu, December 2008

% Input 5-state parameters

% growth 1
model(1).name = 'g1';   
model(1).speed = 11.1;
model(1).nTransits = 3;
model(1).transit(1).rate = 0.71;
model(1).transit(1).dS = 2;
model(1).transit(2).rate = 0.06;
model(1).transit(2).dS = 3;

model(1).transit(3).rate = 0.5;
model(1).transit(3).dS = 5;

% growth pause
model(2).name = 'gp';   
model(2).speed = 0;
model(2).nTransits = 3;
model(2).transit(1).rate = 2.58;
model(2).transit(1).dS = 1;
model(2).transit(2).rate = 0.31;
model(2).transit(2).dS = 3;

model(2).transit(3).rate = 2.58;
model(2).transit(3).dS = 5;

% shrinkage
model(3).name = 's';   
model(3).speed = -11.5;
model(3).nTransits = 3;
model(3).transit(1).rate = 1.79;
model(3).transit(1).dS = 1;
model(3).transit(2).rate = 3.58;
model(3).transit(2).dS = 4;

model(3).transit(3).rate = 1.79;
model(3).transit(3).dS = 5;

% shrinkage pause
model(4).name = 'sp';   
model(4).speed = 0;
model(4).nTransits = 3;
model(4).transit(1).rate = 2.76;
model(4).transit(1).dS = 1;
model(4).transit(2).rate = 0.79;
model(4).transit(2).dS = 3;

model(4).transit(3).rate = 2.76;
model(4).transit(3).dS = 5;

% growth 2
model(5).name = 'g2';   
model(5).speed = 11.1 * 0.5; % (speed of growth 1) * 0.5
model(5).nTransits = 3;
model(5).transit(1).rate = 0.71;
model(5).transit(1).dS = 2;
model(5).transit(2).rate = 0.06;
model(5).transit(2).dS = 3;

model(5).transit(3).rate = 0.5;
model(5).transit(3).dS = 1;

% Input initial length [micron] and total simulation time [s]
initLen = 10;
time = 5000;

% Retrieve a 2-column trajectory and a state index array
[traj, stateIndex, errFlag] = mtMultiStates(model, initLen, time);

% Plot
plot(traj(:, 1), traj(:, 2));
xlabel('Time (sec)');
ylabel('Length (micron)');
title('Kinetic Monte Carlo Trajectory (5-state)');