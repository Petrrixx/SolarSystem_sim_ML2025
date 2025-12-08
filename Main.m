%MAIN Entry point for the Solar System GUI application.
%   Launches SolarSystemApp, which builds the GUI and starts the timer loop.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'src')));

app = SolarSystemApp();
app.run();
