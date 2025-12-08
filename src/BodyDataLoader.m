classdef BodyDataLoader
%BODYDATALOADER Reads body definitions from a JSON file and builds objects.

    properties
        DataFilePath string
    end

    methods
        function obj = BodyDataLoader(dataFilePath)
            if nargin < 1 || strlength(dataFilePath) == 0
                scriptDir = fileparts(mfilename('fullpath'));
                projectRoot = fullfile(scriptDir, '..');
                obj.DataFilePath = fullfile(projectRoot, 'assets', 'data', 'bodies.json');
            else
                obj.DataFilePath = dataFilePath;
            end
        end

        function [bodies, nameToIndex] = loadBodies(obj)
            if ~isfile(obj.DataFilePath)
                error('Body data file not found: %s', obj.DataFilePath);
            end

            rawText = fileread(obj.DataFilePath);
            decoded = jsondecode(rawText);

            bodies = BodyDataLoader.instantiateBodies(decoded); % cell array
            names = cellfun(@(b) char(b.Name), bodies, 'UniformOutput', false);
            nameToIndex = containers.Map(names, 1:numel(bodies));
        end
    end

    methods (Static, Access = private)
        function bodies = instantiateBodies(decodedArray)
            tmp = cell(numel(decodedArray), 1);
            for idx = 1:numel(decodedArray)
                entry = decodedArray(idx);
                switch lower(string(entry.type))
                    case "star"
                        tmp{idx} = Star(entry);
                    case "moon"
                        tmp{idx} = Moon(entry);
                    case "planet"
                        tmp{idx} = Planet(entry);
                    otherwise
                        tmp{idx} = CelestialBody(entry);
                end
            end
            bodies = tmp; % cell array to allow heterogeneous subclasses
        end
    end
end
