classdef CelestialBody
%CELESTIALBODY Base class for any orbiting object in the simulation.
%   Stores orbital elements and sprite metadata. Subclasses can override
%   positionAtTime for special behavior (e.g., the Sun stays at the origin).

    properties
        Name            string
        BodyType        string
        SemiMajorAxisAU double
        Eccentricity    double
        PeriodDays      double
        SpriteFile      string
        DisplayHalfX    double
        DisplayHalfY    double
        OrbitScale      double = 1
        CentralBodyName string
        Description     string
    end

    methods
        function obj = CelestialBody(definition)
            % Accepts a struct decoded from JSON and maps fields to properties.
            obj.Name            = string(definition.name);
            obj.BodyType        = string(definition.type);
            obj.SemiMajorAxisAU = double(definition.a);
            obj.Eccentricity    = double(definition.e);
            obj.PeriodDays      = double(definition.period);
            obj.SpriteFile      = string(definition.spriteFile);
            obj.DisplayHalfX    = double(definition.displayX);
            obj.DisplayHalfY    = double(definition.displayY);
            obj.OrbitScale      = double(definition.orbitScale);
            obj.CentralBodyName = string(definition.centralBody);
            obj.Description     = string(definition.description);
        end

        function pos = positionAtTime(obj, timeDays)
            %POSITIONATTIME Computes 2D position using Keplerian elements.
            if obj.SemiMajorAxisAU == 0 || obj.PeriodDays == 0
                pos = [0 0];
                return;
            end

            meanAnomaly = 2 * pi * mod(timeDays / obj.PeriodDays, 1);
            eccentricAnomaly = obj.solveKepler(meanAnomaly, obj.Eccentricity);
            semiMinor = obj.SemiMajorAxisAU * sqrt(1 - obj.Eccentricity^2);
            pos = [obj.SemiMajorAxisAU * (cos(eccentricAnomaly) - obj.Eccentricity), ...
                   semiMinor * sin(eccentricAnomaly)];
        end
    end

    methods (Access = protected)
        function E = solveKepler(~, M, e)
            %SOLVEKEPLER Newton-Raphson solution for Kepler's equation.
            E = M;
            for iter = 1:30
                delta = (E - e * sin(E) - M) / (1 - e * cos(E));
                E = E - delta;
                if abs(delta) < 1e-8
                    break;
                end
            end
        end
    end
end
