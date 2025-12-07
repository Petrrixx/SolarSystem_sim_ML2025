function SolarSystemSprites()
%SOLARSYSTEMSPRITES 2D Solar System visualization using pre-rendered sprites.
%   Uses Keplerian motion for planets and the Moon, scales distances and sizes
%   for visual clarity, and animates via hgtransform objects with a starry
%   background.

    %=============== Adjust these values for experimentation ===============
    timeSpeedFactor    = 200;   % simulation days per real second
    distanceScale      = 1.30;  % scales AU distances to on-screen units (bigger = more separation)
    artisticSizeScale  = 1.0;   % multiplies sprite footprint (make >1 for larger planets)
    %==========================================================================

    scriptDir   = fileparts(mfilename('fullpath'));
    projectRoot = fullfile(scriptDir, '..');
    assetsRoot  = fullfile(projectRoot, 'assets');

    bodies = defineBodies(artisticSizeScale);
    nameToIndex = containers.Map({bodies.name}, 1:numel(bodies));

    maxSemiMajor = max([bodies.a]);
    axesLimit = maxSemiMajor * distanceScale * 1.45; % ensure all orbits are inside view

    fig = figure('Name','2D Sprite Solar System','Color','k','MenuBar','none','ToolBar','none', ...
                 'Position',[80 80 1200 1100]);
    ax  = axes('Parent',fig);
    hold(ax,'on');
    axis(ax,'equal');
    axis(ax,[-axesLimit axesLimit -axesLimit axesLimit]);
    ax.Color = 'k';
    ax.XColor = 'none';
    ax.YColor = 'none';
    ax.Layer = 'top';

    bgImage = imread(fullfile(assetsRoot, 'Backgrounds', 'space2D.png'));
    bgHandle = imagesc(ax, [-axesLimit axesLimit], [-axesLimit axesLimit], bgImage);
    ax.YDir = 'normal';
    uistack(bgHandle,'bottom');

    theta = linspace(0, 2*pi, 360);
    relativeOrbitHandles = gobjects(numel(bodies),1);
    relativeOrbitX = cell(numel(bodies),1);
    relativeOrbitY = cell(numel(bodies),1);
    orbitParents = nan(numel(bodies),1);

    for idx = 1:numel(bodies)
        b = bodies(idx);
        if b.a > 0
            scaledA = b.a * distanceScale * b.orbitScale;
            bSemi   = scaledA * sqrt(1 - b.e^2);
            orbitX  = scaledA * (cos(theta) - b.e);
            orbitY  = bSemi * sin(theta);

            if strcmp(b.centralBody, 'Sun')
                plot(ax, orbitX, orbitY, 'Color', [0.6 0.6 0.65], 'LineWidth', 0.5);
            else
                orbitParents(idx) = nameToIndex(b.centralBody);
                relativeOrbitX{idx} = orbitX;
                relativeOrbitY{idx} = orbitY;
                relativeOrbitHandles(idx) = plot(ax, orbitX, orbitY, 'Color', [0.6 0.6 0.65], ...
                                                 'LineWidth', 0.4, 'LineStyle', '--');
            end
        end
    end

    % instantiate sprites
    transforms = gobjects(numel(bodies),1);
    for idx = 1:numel(bodies)
        spritePath = fullfile(assetsRoot, 'PixelArt', 'sprites', bodies(idx).spriteFile);
        if ~isfile(spritePath)
            error('Missing sprite: %s', spritePath);
        end

        rawImage = imread(spritePath);
        [cData, alpha] = normalizeSprite(rawImage);
        spriteWidth = bodies(idx).displayX;
        spriteHeight = bodies(idx).displayY;

        tform = hgtransform('Parent', ax);
        image('CData', cData, 'AlphaData', alpha, ...
              'XData', [-spriteWidth spriteWidth], ...
              'YData', [-spriteHeight spriteHeight], ...
              'Parent', tform);
        transforms(idx) = tform;
    end

    simTime = 0;
    lastTime = tic;

    while ishandle(fig)
        elapsed = toc(lastTime);
        lastTime = tic;
        simTime = simTime + timeSpeedFactor * elapsed;

        currentPositions = zeros(numel(bodies), 2);

        for idx = 1:numel(bodies)
            if bodies(idx).a == 0
                currentPositions(idx,:) = [0 0];
            else
                currentPositions(idx,:) = keplerPosition(bodies(idx).a, bodies(idx).e, bodies(idx).period, simTime);
            end
            currentPositions(idx,:) = currentPositions(idx,:) .* bodies(idx).orbitScale;

            if ~strcmp(bodies(idx).centralBody, 'Sun')
                if isKey(nameToIndex, bodies(idx).centralBody)
                    parentIdx = nameToIndex(bodies(idx).centralBody);
                    currentPositions(idx,:) = currentPositions(idx,:) + currentPositions(parentIdx,:);
                end
            end
        end

        scaledPositions = currentPositions * distanceScale;

        for idx = 1:numel(relativeOrbitHandles)
            if isgraphics(relativeOrbitHandles(idx)) && ~isnan(orbitParents(idx))
                parentPos = scaledPositions(orbitParents(idx),:);
                set(relativeOrbitHandles(idx), ...
                    'XData', relativeOrbitX{idx} + parentPos(1), ...
                    'YData', relativeOrbitY{idx} + parentPos(2));
            end
        end

        for idx = 1:numel(transforms)
            worldPos = [scaledPositions(idx,:), 0];
            set(transforms(idx), 'Matrix', makehgtform('translate', worldPos));
        end

        drawnow limitrate;
    end
end

function bodies = defineBodies(sizeScale)
    % body data based on approximate real-world values in AU/days
    names = {'Sun','Mercury','Venus','Earth','Mars','Jupiter','Saturn','Uranus','Neptune','Moon'};
    aVals = [0, 0.387, 0.723, 1.000, 1.524, 5.204, 9.582, 19.218, 30.11, 0.00257];
    eVals = [0, 0.2056, 0.0067, 0.0167, 0.0934, 0.0489, 0.0565, 0.0460, 0.010, 0.0549];
    periods = [1, 88, 224.7, 365.25, 687, 4331, 10747, 30589, 59800, 27.3];
    spriteFiles = {'sun.png','mercury.png','venus.png','earth.png','mars.png',...
                   'jupiter.png','saturn.png','uranus.png','neptune.png','moon.png'};
    displayWidths = [0.25, 0.14, 0.18, 0.24, 0.17, 0.52, 0.70, 0.42, 0.40, 0.07];
    displayHeights = [0.25, 0.14, 0.18, 0.24, 0.17, 0.52, 0.46, 0.42, 0.40, 0.07];
    orbitScales = [1, 1, 1, 1, 1, 1, 1, 1, 1, 400];

    centralBodies = {'Sun','Sun','Sun','Sun','Sun','Sun','Sun','Sun','Sun','Earth'};

    vectorized = struct('name', names, 'a', num2cell(aVals), 'e', num2cell(eVals), ...
        'period', num2cell(periods), 'spriteFile', spriteFiles, ...
        'displayX', num2cell(displayWidths * sizeScale), ...
        'displayY', num2cell(displayHeights * sizeScale), ...
        'centralBody', centralBodies, 'orbitScale', num2cell(orbitScales));

    bodies = vectorized;
end

function [cData, alpha] = normalizeSprite(imageData)
    if size(imageData, 3) == 4
        alpha = double(imageData(:,:,4)) / 255;
        cData = imageData(:,:,1:3);
    else
        alpha = ones(size(imageData,1), size(imageData,2));
        cData = imageData;
    end
end

function pos = keplerPosition(a, e, period, timeDays)
    if a == 0 || period == 0
        pos = [0 0];
        return;
    end

    meanAnomaly = 2*pi * mod(timeDays / period, 1);
    eccentricAnomaly = solveKepler(meanAnomaly, e);
    semiMinor = a * sqrt(1 - e^2);
    pos = [a * (cos(eccentricAnomaly) - e), semiMinor * sin(eccentricAnomaly)];
end

function E = solveKepler(M, e)
    E = M;
    for iter = 1:30
        delta = (E - e*sin(E) - M) / (1 - e*cos(E));
        E = E - delta;
        if abs(delta) < 1e-8
            break;
        end
    end
end
