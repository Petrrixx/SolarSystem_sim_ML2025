classdef SpriteManager
%SPRITEMANAGER Loads and caches sprite images with transparency.

    properties
        AssetsRoot string
        Cache containers.Map
    end

    methods
        function obj = SpriteManager(assetsRoot)
            obj.AssetsRoot = assetsRoot;
            obj.Cache = containers.Map('KeyType','char','ValueType','any');
        end

        function sprite = loadSprite(obj, spriteFile)
            key = char(spriteFile);
            if isKey(obj.Cache, key)
                sprite = obj.Cache(key);
                return;
            end

            fullPath = fullfile(obj.AssetsRoot, 'PixelArt', 'sprites', spriteFile);
            if ~isfile(fullPath)
                error('Sprite not found: %s', fullPath);
            end

            rawImage = imread(fullPath);
            if size(rawImage,3) == 4
                alpha = double(rawImage(:,:,4)) / 255;
                cData = rawImage(:,:,1:3);
            else
                alpha = ones(size(rawImage,1), size(rawImage,2));
                cData = rawImage;
            end

            sprite = struct('CData', cData, 'Alpha', alpha);
            obj.Cache(key) = sprite;
        end
    end
end
