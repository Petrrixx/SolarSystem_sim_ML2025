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
                    vIdx = zeros(1, numel(parts)-1);
                    tIdx = nan(1, numel(parts)-1);
                    nIdx = nan(1, numel(parts)-1);
                    for k = 2:numel(parts)
                        tok = parts{k};
                        splitTok = strsplit(tok, '/');
                        vIdx(k-1) = str2double(splitTok{1});
                        if numel(splitTok) >= 2 && ~isempty(splitTok{2})
                            tIdx(k-1) = str2double(splitTok{2});
                        end
                        if numel(splitTok) >= 3 && ~isempty(splitTok{3})
                            nIdx(k-1) = str2double(splitTok{3});
                        end
                    end
                    if numel(vIdx) >= 3 && all(~isnan(vIdx))
                        [triFaces, triTex, triNorm] = ObjModelViewer.triangulateFace(vIdx, tIdx, nIdx);
                        faces = [faces; triFaces]; %#ok<AGROW>
                        faceTex(end+1:end+numel(triTex)) = triTex; %#ok<AGROW>
                        faceNorm(end+1:end+numel(triNorm)) = triNorm; %#ok<AGROW>
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
            [Vnew, Fnew, UV, VN] = ObjModelViewer.buildMeshWithUV(verts, faces, faceTex, texCoords, faceNorm, normals);
            subdivLevels = isempty(tex.Image) * 0 + ~isempty(tex.Image) * 2; % more verts for crisper texture
            [Vnew, Fnew, UV, VN] = ObjModelViewer.subdivideMesh(Vnew, Fnew, UV, VN, subdivLevels);
            if isempty(VN)
                VN = ObjModelViewer.computeNormals(Vnew, Fnew);
            else
                missing = any(isnan(VN),2);
                if any(missing)
                    comp = ObjModelViewer.computeNormals(Vnew, Fnew);
                    VN(missing, :) = comp(missing, :);
                end
                VN = VN ./ max(vecnorm(VN,2,2), eps);
            end

            vertexColor = ObjModelViewer.assignVertexColorsUV(UV, tex);
            if isempty(vertexColor)
                vertexColor = repmat([0.7 0.75 0.85], size(Vnew,1), 1);
            end

            mesh = struct('V', Vnew, 'F', Fnew, 'VN', VN, 'UV', UV, 'VertexColor', vertexColor);
        end

        function [triFaces, triTex, triNorm] = triangulateFace(vIdx, tIdx, nIdx)
            %TRIANGULATEFACE Fan-triangulates polygon faces and keeps UV/normal indices aligned.
            triFaces = [];
            triTex = {};
            triNorm = {};
            if numel(vIdx) < 3 || any(isnan(vIdx))
                return;
            end
            numTri = numel(vIdx) - 2;
            for m = 1:numTri
                triFaces(end+1, :) = [vIdx(1), vIdx(m+1), vIdx(m+2)]; %#ok<AGROW>
                triTex{end+1} = ObjModelViewer.pickFaceIndices(tIdx, [1, m+1, m+2]); %#ok<AGROW>
                triNorm{end+1} = ObjModelViewer.pickFaceIndices(nIdx, [1, m+1, m+2]); %#ok<AGROW>
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

        function vertexColor = assignVertexColorsUV(UV, tex)
            if isempty(tex.Image) || isempty(UV) || all(isnan(UV(:)))
                vertexColor = [];
                return;
            end
            img = tex.Image;
            h = size(img,1); w = size(img,2);
            % flip V because OBJ origin differs from image origin
            u = UV(:,1);
            v = 1 - UV(:,2);
            u(isnan(u)) = 0; v(isnan(v)) = 0;
            u = min(max(u, 0), 1);
            v = min(max(v, 0), 1);
            x = u .* (w-1) + 1;
            y = v .* (h-1) + 1;
            % bilinear sample for smoother texture
            r = interp2(1:w, 1:h, img(:,:,1), x, y, 'linear', 0);
            g = interp2(1:w, 1:h, img(:,:,2), x, y, 'linear', 0);
            b = interp2(1:w, 1:h, img(:,:,3), x, y, 'linear', 0);
            vertexColor = [r(:), g(:), b(:)];
        end

        function [Vnew, Fnew, UVnew, VNnew] = buildMeshWithUV(verts, faces, faceTex, texCoords, faceNorm, normals)
            %BUILDMESHWITHUV Duplicates vertices where UV/normal seams occur.
            keyMap = containers.Map('KeyType','char','ValueType','double');
            Vnew = [];
            UVnew = [];
            VNnew = [];
            Fnew = zeros(size(faces));
            for f = 1:size(faces,1)
                for k = 1:3
                    vi = faces(f,k);
                    ti = ObjModelViewer.safeIndex(faceTex, f, k);
                    ni = ObjModelViewer.safeIndex(faceNorm, f, k);
                    key = sprintf('%d_%d_%d', vi, ObjModelViewer.nanToKey(ti), ObjModelViewer.nanToKey(ni));
                    if isKey(keyMap, key)
                        idx = keyMap(key);
                    else
                        Vnew(end+1, :) = verts(vi, :); %#ok<AGROW>
                        if ~isnan(ti) && ti >= 1 && ti <= size(texCoords,1)
                            UVnew(end+1, :) = texCoords(ti, :); %#ok<AGROW>
                        else
                            UVnew(end+1, :) = [NaN NaN]; %#ok<AGROW>
                        end
                        if ~isnan(ni) && ni >=1 && ni <= size(normals,1)
                            VNnew(end+1, :) = normals(ni, :); %#ok<AGROW>
                        else
                            VNnew(end+1, :) = [NaN NaN NaN]; %#ok<AGROW>
                        end
                        idx = size(Vnew,1);
                        keyMap(key) = idx;
                    end
                    Fnew(f,k) = idx;
                end
            end
        end

        function out = safeIndex(cellArr, f, k)
            out = NaN;
            if isempty(cellArr) || numel(cellArr) < f || isempty(cellArr{f})
                return;
            end
            if numel(cellArr{f}) < k
                return;
            end
            out = cellArr{f}(k);
        end

        function val = nanToKey(x)
            if isnan(x)
                val = 0;
            else
                val = x;
            end
        end

        function [V, F, UV, VN] = subdivideMesh(V, F, UV, VN, levels)
            %SUBDIVIDEMESH Uniformly splits each triangle into 4 to raise vertex density.
            if nargin < 5
                levels = 0;
            end
            for lvl = 1:levels
                edgeMap = containers.Map('KeyType','char','ValueType','double');
                newV = V;
                newUV = UV;
                newVN = VN;
                newF = zeros(size(F,1)*4, 3);
                nf = 1;
                for f = 1:size(F,1)
                    a = F(f,1); b = F(f,2); c = F(f,3);
                    [ab, edgeMap, newV, newUV, newVN] = ObjModelViewer.midpoint(a, b, V, UV, VN, edgeMap, newV, newUV, newVN);
                    [bc, edgeMap, newV, newUV, newVN] = ObjModelViewer.midpoint(b, c, V, UV, VN, edgeMap, newV, newUV, newVN);
                    [ca, edgeMap, newV, newUV, newVN] = ObjModelViewer.midpoint(c, a, V, UV, VN, edgeMap, newV, newUV, newVN);
                    newF(nf,:) = [a, ab, ca]; nf = nf + 1;
                    newF(nf,:) = [ab, b, bc]; nf = nf + 1;
                    newF(nf,:) = [ca, bc, c]; nf = nf + 1;
                    newF(nf,:) = [ab, bc, ca]; nf = nf + 1;
                end
                V = newV; UV = newUV; VN = newVN; F = newF;
            end
        end

        function [midIdx, edgeMap, V, UV, VN] = midpoint(i1, i2, Vorig, UVorig, VNorig, edgeMap, V, UV, VN)
            key = ObjModelViewer.edgeKey(i1, i2);
            if isKey(edgeMap, key)
                midIdx = edgeMap(key);
                return;
            end
            Vmid = (Vorig(i1,:) + Vorig(i2,:)) / 2;
            if isempty(UVorig)
                UVmid = [NaN NaN];
            else
                UVmid = mean([UVorig(i1,:); UVorig(i2,:)], 1, 'omitnan');
                if any(isnan(UVmid))
                    UVmid = [NaN NaN];
                end
            end
            if isempty(VNorig)
                VNmid = [NaN NaN NaN];
            else
                VNmid = mean([VNorig(i1,:); VNorig(i2,:)], 1, 'omitnan');
                if any(isnan(VNmid))
                    VNmid = [NaN NaN NaN];
                end
            end
            V(end+1,:) = Vmid;
            UV(end+1,:) = UVmid;
            VN(end+1,:) = VNmid;
            midIdx = size(V,1);
            edgeMap(key) = midIdx;
        end

        function key = edgeKey(a, b)
            if a < b
                key = sprintf('%d_%d', a, b);
            else
                key = sprintf('%d_%d', b, a);
            end
        end

        function vals = pickFaceIndices(source, triIdx)
            %PICKFACEINDICES Extracts selected indices or fills with NaN when missing.
            vals = nan(1, numel(triIdx));
            if isempty(source)
                return;
            end
            for i = 1:numel(triIdx)
                idx = triIdx(i);
                if idx <= numel(source)
                    vals(i) = source(idx);
                end
            end
        end
    end
end
