classdef Moon < CelestialBody
%MOON Derived class representing natural satellites.
%   Inherits Keplerian motion; orbitScale can be used to visually enlarge the orbit.

    methods
        function obj = Moon(definition)
            obj@CelestialBody(definition);
        end
    end
end
