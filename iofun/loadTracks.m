%tracks = loadTracks(data, varargin)
%
% Inputs:
%
%  data      : data structure
% 
% Options:
%
% 'Category' : 'Ia'  Single tracks with valid gaps
%              'Ib'  Single tracks with invalid gaps
%              'Ic'  Single tracks cut at beginning or end
%              'Id'  Single tracks, persistent
%              'IIa' Compound tracks with valid gaps
%              'IIb' Compound tracks with invalid gaps
%              'IIc' Compound tracks cut at beginning or end
%              'IId' Compound tracks, persistent

% Francois Aguet (last modified: 02/06/12)

function tracks = loadTracks(data, varargin)

catValues = {'all', 'Ia', 'Ib', 'Ic', 'Id', 'IIa', 'IIb', 'IIc', 'IId'};

ip = inputParser;
ip.CaseSensitive = false;
ip.addRequired('data', @(x) isstruct(x) & numel(x)==1);
ip.addParamValue('Mask', true, @islogical);
ip.addParamValue('FileName', 'ProcessedTracks.mat', @ischar); 
ip.addParamValue('Cutoff_f', 5, @isscalar);
ip.addParamValue('Sort', true, @islogical);
ip.addParamValue('Category', 'Ia');
ip.addParamValue('SignificantSlaveIndex', []);
ip.parse(data, varargin{:});
category = ip.Results.Category;
if ~iscell(category)
    category = {category};
end
if ~all(arrayfun(@(i) any(strcmpi(i, catValues)), category))
    error('Unknown ''Category''.');
end

mCh = strcmp(data.source, data.channels);
cutoff_s = ip.Results.Cutoff_f * data.framerate;

load([data.source 'Tracking' filesep ip.Results.FileName]);

if ip.Results.Sort
    [~, sortIdx] = sort([tracks.lifetime_s], 'descend'); %#ok<NODEF>
    tracks = tracks(sortIdx);
end


% load cell mask, discard tracks that fall into background
mpath = [data.source 'Detection' filesep 'cellmask.tif'];
if ip.Results.Mask 
    if (exist(mpath, 'file')==2)
        mask = logical(imread(mpath));
    else
        mask = logical(getCellMask(data));
    end
    
    nt = numel(tracks);
    x = NaN(1,nt);
    y = NaN(1,nt);
    for k = 1:nt
        x(k) = round(nanmean(tracks(k).x(mCh,:)));
        y(k) = round(nanmean(tracks(k).y(mCh,:)));
    end
    
    % remove tracks outside of mask
    [ny,nx] = size(mask);
    idx = sub2ind([ny nx], y, x);
    tracks = tracks(mask(idx)==1);
end


idx = false(1,numel(tracks));
for k = 1:numel(category);
    switch category{k}
        case 'Ia'
            idx0 = [tracks.catIdx]==1;
        case 'Ib'
            idx0 = [tracks.catIdx]==2;
        case 'Ic'
            idx0 = [tracks.catIdx]==3;
        case 'Id'
            idx0 = [tracks.catIdx]==4;
        case 'IIa'
            idx0 = [tracks.catIdx]==5;
        case 'IIb'
            idx0 = [tracks.catIdx]==6;
        case 'IIc'
            idx0 = [tracks.catIdx]==7;
        case 'IId'
            idx0 = [tracks.catIdx]==8;
        case 'all'
            idx0 = 1:numel(tracks);
    end
    idx = idx | idx0;
end
idx = idx & [tracks.lifetime_s] >= cutoff_s;
tracks = tracks(idx);

if ~isempty(ip.Results.SignificantSlaveIndex)
    significantMaster = [tracks.significantMaster]';
    % slave channels
    sCh = setdiff(1:numel(data.channels), mCh);
    sIdx = all(bsxfun(@eq, significantMaster(:,sCh), ip.Results.SignificantSlaveIndex),2);
    tracks = tracks(sIdx);
end
