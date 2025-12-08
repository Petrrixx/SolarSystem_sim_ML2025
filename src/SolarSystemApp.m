classdef SolarSystemApp < handle
%SOLARSYSTEMAPP GUI-based Solar System simulator using sprites and OOP.
%   Builds a uifigure with controls, loads body definitions from JSON, and
%   animates orbits with optional trails and orbit lines.

    properties
        ProjectRoot string
        AssetsRoot string

        Bodies cell
        NameToIndex containers.Map
        BodyLoader BodyDataLoader
        SpriteManager SpriteManager

        Figure
        Grid
        Axes
        PlayButton
        SpeedSlider
        SpeedLabel
        OrbitsCheckBox
        TrailsCheckBox
        BodyDropdown
        InfoTextArea
        BodyTable
        ShowModelButton
        ResetButton

        BackgroundHandle
        OrbitHandles
        OrbitParents
        RelativeOrbitX
        RelativeOrbitY
        SpriteHandles
        TrailHandles
        LatestScaledPositions

        SimTimer
        SimTime double = 0
        LastTick
        DistanceScale double = 1.3
        TimeSpeedFactor double = 200
        DefaultTimeSpeed double = 200
        Running logical = true
        SelectedBodyIndex double = 1
        InitialAxesLimit double = 0
        FactsCache containers.Map
    end

    methods
        function obj = SolarSystemApp()
            obj.ProjectRoot = fullfile(fileparts(mfilename('fullpath')), '..');
            obj.AssetsRoot = fullfile(obj.ProjectRoot, 'assets');
            obj.BodyLoader = BodyDataLoader();
            [obj.Bodies, obj.NameToIndex] = obj.BodyLoader.loadBodies();
            obj.SpriteManager = SpriteManager(obj.AssetsRoot);
            obj.FactsCache = containers.Map('KeyType','char','ValueType','any');

            obj.createUI();
            obj.populateBodyTable();
            obj.prepareScene();
            obj.startTimer();
        end

        function run(obj)
            %RUN helper to keep a reference alive when launched from script.
            if isvalid(obj.Figure)
                uialert(obj.Figure, 'Use the Pause/Play button or close the window to stop.', ...
                    'Solar System running', 'Icon', 'info');
            end
        end

        function delete(obj)
            obj.stopTimer();
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end

    methods (Access = private)
        function createUI(obj)
            %CREATEUI Build the figure, axes, and control widgets.
            obj.Figure = uifigure('Name', 'Solar System GUI', 'Color', [0 0 0], ...
                                  'Position', [100 100 1200 750]);
            obj.Figure.CloseRequestFcn = @(src, evt) obj.onClose();
            obj.Figure.WindowButtonDownFcn = @(src, evt) obj.onClick(evt);
            obj.Figure.WindowScrollWheelFcn = @(src, evt) obj.onScroll(evt);

            obj.Grid = uigridlayout(obj.Figure, [2 2]);
            obj.Grid.ColumnWidth = {'3x', '1.3x'};
            obj.Grid.RowHeight = {'3x', '1x'};
            obj.Grid.Padding = [8 8 8 8];

            obj.Axes = uiaxes(obj.Grid);
            obj.Axes.Layout.Row = [1 2];
            obj.Axes.Layout.Column = 1;
            obj.Axes.Color = 'k';
            obj.Axes.XTick = [];
            obj.Axes.YTick = [];
            obj.Axes.XColor = [0.8 0.8 0.8];
            obj.Axes.YColor = [0.8 0.8 0.8];
            axis(obj.Axes, 'equal');
            hold(obj.Axes, 'on');

            controlPanel = uipanel(obj.Grid, 'Title', 'Controls', ...
                'BackgroundColor', [0.05 0.05 0.1]);
            controlPanel.Layout.Row = 1;
            controlPanel.Layout.Column = 2;
            controlLayout = uigridlayout(controlPanel, [9 1]);
            controlLayout.RowHeight = {32, 40, 32, 32, 40, 36, 36, 110, '1x'};
            controlLayout.Padding = [12 12 12 12];

            obj.PlayButton = uibutton(controlLayout, 'Text', 'Pause', ...
                'ButtonPushedFcn', @(src, evt) obj.onTogglePlay());
            obj.PlayButton.Layout.Row = 1;

            obj.SpeedLabel = uilabel(controlLayout, 'Text', sprintf('Speed: %.0f days/sec', obj.TimeSpeedFactor), ...
                'FontColor', [0.9 0.9 0.9]);
            obj.SpeedLabel.Layout.Row = 2;

            obj.SpeedSlider = uislider(controlLayout, 'Limits', [10 500], ...
                'Value', obj.TimeSpeedFactor, 'ValueChangingFcn', @(src, evt) obj.onSpeedChanging(evt), ...
                'ValueChangedFcn', @(src, evt) obj.onSpeedChanged(src.Value));
            obj.SpeedSlider.Layout.Row = 3;

            obj.OrbitsCheckBox = uicheckbox(controlLayout, 'Text', 'Show Orbits', ...
                'Value', true, 'ValueChangedFcn', @(src, evt) obj.onToggleOrbits());
            obj.OrbitsCheckBox.Layout.Row = 4;
            obj.OrbitsCheckBox.FontColor = [0.9 0.9 0.9];

            obj.TrailsCheckBox = uicheckbox(controlLayout, 'Text', 'Show Trails', ...
                'Value', false, 'ValueChangedFcn', @(src, evt) obj.onToggleTrails());
            obj.TrailsCheckBox.Layout.Row = 5;
            obj.TrailsCheckBox.FontColor = [0.9 0.9 0.9];

            names = cellfun(@(b) char(b.Name), obj.Bodies, 'UniformOutput', false);
            obj.BodyDropdown = uidropdown(controlLayout, 'Items', names, ...
                'ItemsData', num2cell(1:numel(obj.Bodies)), ...
                'ValueChangedFcn', @(src, evt) obj.onSelectBody(evt.Value));
            obj.BodyDropdown.Layout.Row = 6;

            obj.ShowModelButton = uibutton(controlLayout, 'Text', 'Show 3D Model', ...
                'Enable', 'off', 'ButtonPushedFcn', @(src, evt) obj.onShowModel());
            obj.ShowModelButton.Layout.Row = 7;

            obj.ResetButton = uibutton(controlLayout, 'Text', 'Reset View', ...
                'ButtonPushedFcn', @(src, evt) obj.onReset());
            obj.ResetButton.Layout.Row = 8;

            obj.InfoTextArea = uitextarea(controlLayout, 'Editable', 'off', ...
                'Value', {'Select a body to see info.'});
            obj.InfoTextArea.Layout.Row = 9;
            obj.InfoTextArea.FontColor = [0.95 0.95 0.95];
            obj.InfoTextArea.BackgroundColor = [0.1 0.1 0.15];

            tablePanel = uipanel(obj.Grid, 'Title', 'Bodies', ...
                'BackgroundColor', [0.05 0.05 0.1]);
            tablePanel.Layout.Row = 2;
            tablePanel.Layout.Column = 2;
            tableLayout = uigridlayout(tablePanel, [1 1]);
            tableLayout.Padding = [5 5 5 5];
            tableLayout.RowHeight = {'1x'};
            tableLayout.ColumnWidth = {'1x'};

            obj.BodyTable = uitable(tableLayout, 'Data', {}, ...
                'ColumnName', {'Name', 'Type', 'Central', 'a (AU)', 'Period (days)'}, ...
                'ColumnEditable', [false false false false false], ...
                'ColumnWidth', {'auto', 70, 70, 70, 90});
            obj.BodyTable.Layout.Row = 1;
            obj.BodyTable.Layout.Column = 1;
        end

        function populateBodyTable(obj)
            %POPULATEBODYTABLE Fill uitable with static parameters.
            data = cell(numel(obj.Bodies), 5);
            for idx = 1:numel(obj.Bodies)
                b = obj.Bodies{idx};
                data{idx,1} = char(b.Name);
                data{idx,2} = char(b.BodyType);
                data{idx,3} = char(b.CentralBodyName);
                data{idx,4} = b.SemiMajorAxisAU;
                data{idx,5} = b.PeriodDays;
            end
            obj.BodyTable.Data = data;
            if ~isempty(obj.Bodies)
                obj.BodyDropdown.Value = 1;
                obj.SelectedBodyIndex = 1;
                obj.updateInfoText(1, [0 0]);
                obj.updateModelButtonState(1);
            end
        end

        function prepareScene(obj)
            %PREPARESCENE Draw background, orbits, sprites, and trails.
            numBodies = numel(obj.Bodies);
            obj.SpriteHandles = gobjects(numBodies,1);
            obj.TrailHandles = gobjects(numBodies,1);
            obj.OrbitHandles = gobjects(numBodies,1);
            obj.RelativeOrbitX = cell(numBodies,1);
            obj.RelativeOrbitY = cell(numBodies,1);
            obj.OrbitParents = nan(numBodies,1);

            semiScaled = cellfun(@(b) b.SemiMajorAxisAU .* b.OrbitScale, obj.Bodies);
            maxSemiMajor = max(semiScaled);
            axesLimit = maxSemiMajor * obj.DistanceScale * 1.45;
            axis(obj.Axes, [-axesLimit axesLimit -axesLimit axesLimit]);
            obj.InitialAxesLimit = axesLimit;

            bgPath = fullfile(obj.AssetsRoot, 'Backgrounds', 'space2D.png');
            bgImage = imread(bgPath);
            obj.BackgroundHandle = imagesc(obj.Axes, [-axesLimit axesLimit], [-axesLimit axesLimit], bgImage);
            obj.Axes.YDir = 'normal';
            uistack(obj.BackgroundHandle, 'bottom');

            theta = linspace(0, 2*pi, 360);
            orbitColor = [0.6 0.6 0.65];
            trailColors = lines(numBodies);

            for idx = 1:numBodies
                b = obj.Bodies{idx};
                if b.SemiMajorAxisAU > 0
                    aScaled = b.SemiMajorAxisAU * b.OrbitScale;
                    bSemi = aScaled * sqrt(1 - b.Eccentricity^2);
                    orbitX = aScaled * (cos(theta) - b.Eccentricity);
                    orbitY = bSemi * sin(theta);

                    if strlength(b.CentralBodyName) == 0 || strcmpi(b.CentralBodyName, 'Sun')
                        obj.OrbitHandles(idx) = plot(obj.Axes, orbitX * obj.DistanceScale, orbitY * obj.DistanceScale, ...
                            'Color', orbitColor, 'LineWidth', 0.5);
                    else
                        obj.OrbitParents(idx) = obj.lookupParentIndex(b.CentralBodyName);
                        obj.RelativeOrbitX{idx} = orbitX * obj.DistanceScale;
                        obj.RelativeOrbitY{idx} = orbitY * obj.DistanceScale;
                        obj.OrbitHandles(idx) = plot(obj.Axes, obj.RelativeOrbitX{idx}, obj.RelativeOrbitY{idx}, ...
                            'Color', orbitColor, 'LineWidth', 0.4, 'LineStyle', '--');
                    end
                end

                sprite = obj.SpriteManager.loadSprite(b.SpriteFile);
                obj.SpriteHandles(idx) = image(obj.Axes, sprite.CData, 'AlphaData', sprite.Alpha, ...
                    'XData', [-b.DisplayHalfX b.DisplayHalfX], 'YData', [-b.DisplayHalfY b.DisplayHalfY]);

                obj.TrailHandles(idx) = animatedline(obj.Axes, 'Color', trailColors(idx,:), ...
                    'LineWidth', 0.7, 'MaximumNumPoints', 600, 'Visible', 'off');
            end

            obj.LastTick = tic;
            obj.onTick(); % draw initial frame
        end

        function startTimer(obj)
            %STARTTIMER Creates and starts the animation timer.
            obj.SimTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.03, 'TimerFcn', @(src, evt) obj.onTick());
            start(obj.SimTimer);
        end

        function stopTimer(obj)
            %STOPTIMER Stops and deletes the animation timer.
            if ~isempty(obj.SimTimer) && isvalid(obj.SimTimer)
                stop(obj.SimTimer);
                delete(obj.SimTimer);
            end
            obj.SimTimer = [];
        end

        function onTick(obj)
            %ONTICK Timer callback updating positions and graphics.
            if isempty(obj.Figure) || ~isvalid(obj.Figure) || ~obj.Running
                return;
            end

            elapsed = toc(obj.LastTick);
            obj.LastTick = tic;
            obj.SimTime = obj.SimTime + elapsed * obj.TimeSpeedFactor;

            numBodies = numel(obj.Bodies);
            currentPositions = zeros(numBodies, 2);

            for idx = 1:numBodies
                basePos = obj.Bodies{idx}.positionAtTime(obj.SimTime);
                b = obj.Bodies{idx};
                scaledRelPos = basePos * b.OrbitScale; % display exaggeration for moons
                if strlength(b.CentralBodyName) > 0 && isKey(obj.NameToIndex, char(b.CentralBodyName))
                    parentIdx = obj.NameToIndex(char(b.CentralBodyName));
                    currentPositions(idx,:) = scaledRelPos + currentPositions(parentIdx,:);
                else
                    currentPositions(idx,:) = scaledRelPos;
                end
            end

            scaledPositions = currentPositions * obj.DistanceScale;
            obj.LatestScaledPositions = scaledPositions;

            for idx = 1:numBodies
                w = obj.Bodies{idx}.DisplayHalfX;
                h = obj.Bodies{idx}.DisplayHalfY;
                set(obj.SpriteHandles(idx), 'XData', scaledPositions(idx,1) + [-w, w], ...
                    'YData', scaledPositions(idx,2) + [-h, h]);

                if obj.TrailsCheckBox.Value
                    set(obj.TrailHandles(idx), 'Visible', 'on');
                    addpoints(obj.TrailHandles(idx), scaledPositions(idx,1), scaledPositions(idx,2));
                else
                    if isvalid(obj.TrailHandles(idx))
                        clearpoints(obj.TrailHandles(idx));
                        set(obj.TrailHandles(idx), 'Visible', 'off');
                    end
                end
            end

            for idx = 1:numBodies
                if ~isgraphics(obj.OrbitHandles(idx))
                    continue;
                end
                if ~isnan(obj.OrbitParents(idx)) && obj.OrbitParents(idx) > 0
                    parentPos = scaledPositions(obj.OrbitParents(idx), :);
                    set(obj.OrbitHandles(idx), ...
                        'XData', obj.RelativeOrbitX{idx} + parentPos(1), ...
                        'YData', obj.RelativeOrbitY{idx} + parentPos(2));
                end
            end

            if obj.OrbitsCheckBox.Value
                set(obj.OrbitHandles(isgraphics(obj.OrbitHandles)), 'Visible', 'on');
            else
                set(obj.OrbitHandles(isgraphics(obj.OrbitHandles)), 'Visible', 'off');
            end

            if ~isempty(obj.BodyDropdown.Value)
                idx = obj.BodyDropdown.Value;
                obj.updateInfoText(idx, currentPositions(idx,:));
            end

            drawnow limitrate;
        end

        function idx = lookupParentIndex(obj, parentName)
            if isKey(obj.NameToIndex, char(parentName))
                idx = obj.NameToIndex(char(parentName));
            else
                idx = NaN;
            end
        end

        function onTogglePlay(obj)
            obj.Running = ~obj.Running;
            if obj.Running
                obj.LastTick = tic;
                obj.PlayButton.Text = 'Pause';
            else
                obj.PlayButton.Text = 'Play';
            end
        end

        function onSpeedChanging(obj, evt)
            obj.TimeSpeedFactor = evt.Value;
            obj.SpeedLabel.Text = sprintf('Speed: %.0f days/sec', obj.TimeSpeedFactor);
        end

        function onSpeedChanged(obj, value)
            obj.TimeSpeedFactor = value;
            obj.SpeedLabel.Text = sprintf('Speed: %.0f days/sec', obj.TimeSpeedFactor);
        end

        function onToggleOrbits(obj)
            % Visibility handled inside onTick; here we force an immediate refresh.
            obj.onTick();
        end

        function onToggleTrails(obj)
            if ~obj.TrailsCheckBox.Value && ~isempty(obj.TrailHandles)
                for idx = 1:numel(obj.TrailHandles)
                    if isvalid(obj.TrailHandles(idx))
                        clearpoints(obj.TrailHandles(idx));
                        set(obj.TrailHandles(idx), 'Visible', 'off');
                    end
                end
            end
        end

        function onSelectBody(obj, idx)
            if isempty(idx)
                return;
            end
            obj.SelectedBodyIndex = idx;
            obj.updateInfoText(idx, [0 0]);
            obj.zoomToBody(idx);
            obj.updateModelButtonState(idx);
        end

        function updateInfoText(obj, idx, currentPos)
            b = obj.Bodies{idx};
            distanceAU = norm(currentPos);
            lines = { ...
                sprintf('%s (%s)', b.Name, b.BodyType); ...
                sprintf('Central body: %s', ternary(strlength(b.CentralBodyName)>0, b.CentralBodyName, "None")); ...
                sprintf('Semi-major axis: %.4g AU', b.SemiMajorAxisAU); ...
                sprintf('Eccentricity: %.3f', b.Eccentricity); ...
                sprintf('Orbital period: %.1f days', b.PeriodDays); ...
                sprintf('Current distance: %.4g AU', distanceAU); ...
                sprintf('3D model: %s', ternary(isfile(obj.modelPathForBody(b)), "available", "missing")); ...
                ''; ...
                char(b.Description) ...
                };
            fact = obj.fetchFact(b.Name);
            if strlength(fact) > 0
                lines = [lines; {''; 'Fact:'; char(fact)}]; %#ok<AGROW>
            end
            obj.InfoTextArea.Value = lines;
        end

        function zoomToBody(obj, idx)
            if isempty(obj.LatestScaledPositions)
                return;
            end
            target = obj.LatestScaledPositions(idx, :);
            span = max(0.6, obj.InitialAxesLimit / 5);
            xlim(obj.Axes, target(1) + [-span, span]);
            ylim(obj.Axes, target(2) + [-span, span]);
        end

        function onClick(obj, evt)
            hitAxes = ancestor(obj.Figure.CurrentObject, 'matlab.graphics.axis.Axes');
            if isempty(hitAxes) || hitAxes ~= obj.Axes
                return; % ignore clicks outside the sky view
            end
            pt = obj.Axes.CurrentPoint;
            clickPos = pt(1,1:2);
            if isempty(obj.LatestScaledPositions)
                return;
            end
            distances = vecnorm(obj.LatestScaledPositions - clickPos, 2, 2);
            threshold = range(obj.Axes.XLim) / 25;
            [minDist, idx] = min(distances);
            if minDist < threshold
                obj.BodyDropdown.Value = idx;
                obj.onSelectBody(idx);
            end
        end

        function onScroll(obj, evt)
            hitAxes = ancestor(obj.Figure.CurrentObject, 'matlab.graphics.axis.Axes');
            if isempty(hitAxes) || hitAxes ~= obj.Axes
                return; % only zoom when mouse is over the axes
            end
            cp = obj.Axes.CurrentPoint;
            focus = cp(1,1:2);
            count = evt.VerticalScrollCount;
            if count > 0
                scale = 1.1 ^ count; % zoom out
            else
                scale = 0.9 ^ abs(count); % zoom in
            end
            obj.zoomAroundPoint(focus, scale);
        end

        function zoomAroundPoint(obj, focus, scale)
            xl = obj.Axes.XLim;
            yl = obj.Axes.YLim;
            xl = focus(1) + (xl - focus(1)) * scale;
            yl = focus(2) + (yl - focus(2)) * scale;

            % clamp to reasonable limits
            maxLim = obj.InitialAxesLimit * 1.1;
            minSpan = 0.2;
            xl = max(min(xl, maxLim), -maxLim);
            yl = max(min(yl, maxLim), -maxLim);
            if diff(xl) < minSpan
                xl = focus(1) + [-minSpan/2, minSpan/2];
            end
            if diff(yl) < minSpan
                yl = focus(2) + [-minSpan/2, minSpan/2];
            end
            xlim(obj.Axes, xl);
            ylim(obj.Axes, yl);
        end

        function updateModelButtonState(obj, idx)
            b = obj.Bodies{idx};
            if isfile(obj.modelPathForBody(b))
                obj.ShowModelButton.Enable = 'on';
            else
                obj.ShowModelButton.Enable = 'off';
            end
        end

        function onShowModel(obj)
            idx = obj.BodyDropdown.Value;
            if isempty(idx)
                return;
            end
            b = obj.Bodies{idx};
            modelPath = obj.modelPathForBody(b);
            if ~isfile(modelPath)
                uialert(obj.Figure, sprintf('3D model not found: %s', modelPath), 'Model missing');
                return;
            end
            ObjModelViewer.showModel(modelPath, char(b.Name));
        end

        function path = modelPathForBody(obj, body)
            %MODELPAHTFORBODY Build path to OBJ file using naming convention.
            bodyFolder = fullfile(obj.AssetsRoot, char(body.Name));
            path = fullfile(bodyFolder, sprintf('%s.obj', char(body.Name)));
        end

        function onClose(obj)
            obj.stopTimer();
            delete(obj.Figure);
        end

        function onReset(obj)
            % Reset controls and scene to defaults and clear trails/marks.
            obj.TimeSpeedFactor = obj.DefaultTimeSpeed;
            obj.SpeedSlider.Value = obj.DefaultTimeSpeed;
            obj.SpeedLabel.Text = sprintf('Speed: %.0f days/sec', obj.TimeSpeedFactor);
            obj.OrbitsCheckBox.Value = true;
            obj.TrailsCheckBox.Value = false;
            obj.Running = true;
            obj.PlayButton.Text = 'Pause';
            obj.SimTime = 0;
            obj.LastTick = tic;
            obj.BodyDropdown.Value = 1;
            obj.SelectedBodyIndex = 1;
            % reset axes limits
            lim = obj.InitialAxesLimit;
            xlim(obj.Axes, [-lim lim]); ylim(obj.Axes, [-lim lim]);
            % clear trails
            for k = 1:numel(obj.TrailHandles)
                if isvalid(obj.TrailHandles(k))
                    clearpoints(obj.TrailHandles(k));
                    set(obj.TrailHandles(k), 'Visible', 'off');
                end
            end
            % refresh positions and info
            obj.onTick();
            obj.updateInfoText(1, [0 0]);
            obj.updateModelButtonState(1);
        end

        function fact = fetchFact(obj, bodyName)
            key = lower(char(bodyName));
            if isKey(obj.FactsCache, key)
                fact = obj.FactsCache(key);
                return;
            end
            fact = "";
            try
                encoded = char(matlab.net.URI.encode(string(bodyName)));
                url = sprintf('https://en.wikipedia.org/api/rest_v1/page/summary/%s', encoded);
                opts = weboptions('Timeout', 4);
                resp = webread(url, opts);
                if isfield(resp, 'extract') && strlength(string(resp.extract)) > 0
                    fact = string(resp.extract);
                    % keep it short (~2 sentences)
                    parts = split(fact, '. ');
                    if numel(parts) > 2
                        fact = strjoin(parts(1:2), '. ');
                        if ~endsWith(fact, ".")
                            fact = fact + ".";
                        end
                    end
                end
            catch
                % ignore network errors
            end
            if strlength(fact) == 0
                fact = "No extra fact available right now.";
            end
            obj.FactsCache(key) = fact;
        end
    end
end

function out = ternary(cond, a, b)
%TERNARY simple inline conditional helper.
    if cond
        out = a;
    else
        out = b;
    end
end
