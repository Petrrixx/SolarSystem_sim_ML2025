classdef ObjModelViewer
%OBJMODELVIEWER Opens a new window and displays a simple OBJ mesh.
%   Allows rotate and zoom using standard figure interactions.

    methods (Static)
        function showModel(modelPath, titleText)
            viewer = ObjModelViewer();
            viewer.openModel(modelPath, titleText);
        end
    end

    methods (Access = private)
        function openModel(~, modelPath, titleText)
            [V, F] = ObjModelViewer.readObj(modelPath);
            fig = figure('Name', sprintf('%s 3D Model', titleText), ...
                'Color', [0 0 0], 'ToolBar', 'figure', 'MenuBar', 'figure');
            ax = axes('Parent', fig, 'Color', [0 0 0]);
            p = patch(ax, 'Vertices', V, 'Faces', F, ...
                'FaceColor', [0.7 0.75 0.85], 'EdgeColor', 'none');
            axis(ax, 'equal');
            axis(ax, 'vis3d');
            grid(ax, 'on');
            ax.GridColor = [0.3 0.3 0.3];
            camlight(ax, 'headlight');
            lighting(ax, 'gouraud');
            material(p, 'dull');
            xlabel(ax, 'X', 'Color', [0.8 0.8 0.8]);
            ylabel(ax, 'Y', 'Color', [0.8 0.8 0.8]);
            zlabel(ax, 'Z', 'Color', [0.8 0.8 0.8]);
            title(ax, sprintf('%s 3D Model', titleText), 'Color', [0.95 0.95 0.95]);
            rotate3d(ax, 'on'); % allow dragging to rotate
            zoom(fig, 'on');    % allow scroll or toolbar to zoom
        end
    end

    methods (Static, Access = private)
        function [V, F] = readObj(path)
            if ~isfile(path)
                error('OBJ file not found: %s', path);
            end
            fid = fopen(path, 'r');
            if fid == -1
                error('Could not open OBJ file: %s', path);
            end

            verts = [];
            faces = [];
            while true
                tline = fgetl(fid);
                if ~ischar(tline)
                    break;
                end
                line = strtrim(tline);
                if startsWith(line, 'v ')
                    nums = sscanf(line(3:end), '%f');
                    if numel(nums) >= 3
                        verts(end+1, :) = nums(1:3).'; %#ok<AGROW>
                    end
                elseif startsWith(line, 'f ')
                    parts = strsplit(line);
                    idxs = zeros(1, numel(parts)-1);
                    for k = 2:numel(parts)
                        tok = parts{k};
                        slashPos = find(tok == '/', 1);
                        if isempty(slashPos)
                            idxs(k-1) = str2double(tok);
                        else
                            idxs(k-1) = str2double(tok(1:slashPos-1));
                        end
                    end
                    if numel(idxs) >= 3 && all(~isnan(idxs))
                        faces = ObjModelViewer.triangulateFace(faces, idxs); %#ok<AGROW>
                    end
                end
            end
            fclose(fid);

            V = verts;
            F = faces;
        end

        function faces = triangulateFace(faces, idxs)
            %TRIANGULATEFACE Fan-triangulates polygon faces.
            faces(end+1, :) = idxs(1:3);
            if numel(idxs) > 3
                for m = 4:numel(idxs)
                    faces(end+1, :) = [idxs(1), idxs(m-1), idxs(m)];
                end
            end
        end
    end
end
