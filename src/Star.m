classdef Star < CelestialBody
%STAR Derived class for the Sun; stays at the origin.

    methods
        function obj = Star(definition)
            obj@CelestialBody(definition);
        end

        function pos = positionAtTime(obj, ~)
            %#ok<INUSD> keep interface consistent
            pos = [0 0];
        end
    end
end
