classdef Planet < CelestialBody
%PLANET Derived class representing planets orbiting the Sun.
%   Uses the base Keplerian position computation.

    methods
        function obj = Planet(definition)
            obj@CelestialBody(definition);
        end
    end
end
