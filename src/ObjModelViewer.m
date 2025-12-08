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
            [mesh, tex] = ObjModelViewer.readObj(modelPath);
            fig = figure('Name', sprintf('%s 3D Model', titleText), ...
                'Color', [0 0 0], 'ToolBar', 'figure', 'MenuBar', 'figure');
            ax = axes('Parent', fig, 'Color', [0 0 0]);
            p = patch(ax, 'Vertices', mesh.V, 'Faces', mesh.F, ...
                'FaceColor', 'interp', 'EdgeColor', 'none', ...
                'FaceVertexCData', mesh.VertexColor, ...
                'VertexNormals', mesh.VN, ...
                'BackFaceLighting', 'reverselit');
            axis(ax, 'equal');
            axis(ax, 'vis3d');
            grid(ax, 'on');
            ax.GridColor = [0.3 0.3 0.3];
            camlight(ax, 'headlight');
            camlight(ax, 'right');
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
        function [mesh, tex] = readObj(path)
            if ~isfile(path)
                error('OBJ file not found: %s', path);
            end
            fid = fopen(path, 'r');
            if fid == -1
                error('Could not open OBJ file: %s', path);
            end

            verts = [];
            faces = [];
            texCoords = [];
            normals = [];
            faceTex = {};
            faceNorm = {};
            mtlFile = '';
            while true
                tline = fgetl(fid);
                if ~ischar(tline)
                    break;
                end
                line = strtrim(tline);
                if startsWith(line, 'mtllib')
                    toks = strsplit(line);
                    if numel(toks) >= 2
                        mtlFile = strtrim(toks{2});
                    end
                elseif startsWith(line, 'v ')
                    nums = sscanf(line(3:end), '%f');
                    if numel(nums) >= 3
                        verts(end+1, :) = nums(1:3).'; %#ok<AGROW>
                    end
                elseif startsWith(line, 'f ')
                    parts = strsplit(line);
                    idxs = zeros(1, numel(parts)-1);
                    tIdx = nan(1, numel(parts)-1);
                    nIdx = nan(1, numel(parts)-1);
                    for k = 2:numel(parts)
                        tok = parts{k};
                        splitTok = strsplit(tok, '/');
                        idxs(k-1) = str2double(splitTok{1});
                        if numel(splitTok) >= 2 && ~isempty(splitTok{2})
                            tIdx(k-1) = str2double(splitTok{2});
                        end
                        if numel(splitTok) >= 3 && ~isempty(splitTok{3})
                            nIdx(k-1) = str2double(splitTok{3});
                        end
                    end
                    if numel(idxs) >= 3 && all(~isnan(idxs))
                        faces = ObjModelViewer.triangulateFace(faces, idxs); %#ok<AGROW>
                        faceTex{end+1} = tIdx; %#ok<AGROW>
                        faceNorm{end+1} = nIdx; %#ok<AGROW>
                    end
                elseif startsWith(line, 'vt')
                    nums = sscanf(line(4:end), '%f');
                    if numel(nums) >= 2
                        texCoords(end+1, :) = nums(1:2).'; %#ok<AGROW>
                    end
                elseif startsWith(line, 'vn')
                    nums = sscanf(line(4:end), '%f');
                    if numel(nums) >= 3
                        normals(end+1, :) = nums(1:3).'; %#ok<AGROW>
                    end
                end
            end
            fclose(fid);

            tex = ObjModelViewer.readMtl(path, mtlFile);
            vertexColor = ObjModelViewer.assignVertexColors(faces, faceTex, texCoords, tex);
            if isempty(vertexColor)
                vertexColor = repmat([0.7 0.75 0.85], size(verts,1), 1);
            end

            if isempty(normals)
                VN = ObjModelViewer.computeNormals(verts, faces);
            else
                VN = ObjModelViewer.expandNormals(faces, faceNorm, normals, size(verts,1));
            end

            mesh = struct('V', verts, 'F', faces, 'VN', VN, 'VertexColor', vertexColor);
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

        function tex = readMtl(objPath, mtlFile)
            tex = struct('Image', [], 'Path', '');
            if isempty(mtlFile)
                return;
            end
            objDir = fileparts(objPath);
            candidate = fullfile(objDir, mtlFile);
            if ~isfile(candidate)
                return;
            end
            fid = fopen(candidate, 'r');
            if fid == -1
                return;
            end
            mapPath = '';
            while true
                tline = fgetl(fid);
                if ~ischar(tline); break; end
                line = strtrim(tline);
                if startsWith(line, 'map_Kd')
                    parts = strsplit(line);
                    if numel(parts) >= 2
                        mapPath = strtrim(strjoin(parts(2:end), ' '));
                        break;
                    end
                end
            end
            fclose(fid);
            if isempty(mapPath)
                return;
            end
            absTex = fullfile(objDir, mapPath);
            if isfile(absTex)
                tex.Image = im2double(imread(absTex));
                tex.Path = absTex;
            end
        end

        function vertexColor = assignVertexColors(faces, faceTex, texCoords, tex)
            if isempty(tex.Image) || isempty(texCoords)
                vertexColor = [];
                return;
            end
            numVerts = max(faces(:));
            acc = zeros(numVerts, 3);
            counts = zeros(numVerts, 1);
            img = tex.Image;
            h = size(img,1); w = size(img,2);

            for f = 1:size(faces,1)
                vIdx = faces(f,:);
                if numel(faceTex) < f || isempty(faceTex{f}) || all(isnan(faceTex{f}))
                    continue;
                end
                tIdx = faceTex{f};
                tIdx = tIdx(~isnan(tIdx));
                if numel(tIdx) ~= numel(vIdx)
                    continue;
                end
                for k = 1:numel(vIdx)
                    uv = texCoords(tIdx(k), :);
                    u = uv(1); v = uv(2);
                    x = max(1, min(w, round(u * (w-1) + 1)));
                    y = max(1, min(h, round((1 - v) * (h-1) + 1)));
                    acc(vIdx(k), :) = acc(vIdx(k), :) + reshape(img(y, x, 1:3), [1 3]);
                    counts(vIdx(k)) = counts(vIdx(k)) + 1;
                end
            end
            counts(counts==0) = 1;
            vertexColor = acc ./ counts;
        end

        function VN = computeNormals(V, F)
            %COMPUTENORMALS approximate per-vertex normals.
            VN = zeros(size(V));
            for i = 1:size(F,1)
                idx = F(i,:);
                v1 = V(idx(2),:) - V(idx(1),:);
                v2 = V(idx(3),:) - V(idx(1),:);
                n = cross(v1, v2);
                n = n / max(norm(n), eps);
                VN(idx,:) = VN(idx,:) + repmat(n, numel(idx),1);
            end
            VN = VN ./ vecnorm(VN, 2, 2);
        end

        function VN = expandNormals(faces, faceNorm, normals, numVerts)
            VN = zeros(numVerts, 3);
            counts = zeros(numVerts,1);
            for f = 1:size(faces,1)
                if numel(faceNorm) < f || isempty(faceNorm{f}) || all(isnan(faceNorm{f}))
                    continue;
                end
                vIdx = faces(f,:);
                nIdx = faceNorm{f};
                nIdx = nIdx(~isnan(nIdx));
                if numel(nIdx) ~= numel(vIdx)
                    continue;
                end
                for k = 1:numel(vIdx)
                    VN(vIdx(k), :) = VN(vIdx(k), :) + normals(nIdx(k), :);
                    counts(vIdx(k)) = counts(vIdx(k)) + 1;
                end
            end
            counts(counts==0) = 1;
            VN = VN ./ counts;
            VN = VN ./ max(vecnorm(VN,2,2), eps);
        end
    end
end
