function [res] = runLifetimeAnalysisNEW(data, varargin)

ip = inputParser;
ip.CaseSensitive = false;
ip.addRequired('data', @(x) isstruct(x) && numel(unique([data.framerate]))==1);
ip.addParamValue('Display', 'on', @(x) strcmpi(x, 'on') | strcmpi(x, 'off'));
ip.addParamValue('FileName', 'trackAnalysis.mat', @ischar);
ip.addParamValue('Type', 'all', @ischar);
ip.addParamValue('Cutoff_f', 4, @isscalar);
ip.addParamValue('Print', false, @islogical);
ip.addParamValue('Buffer', 5);
ip.parse(data, varargin{:});
nd = length(data);
framerate = data(1).framerate;

% Extend all to max. movie length, in case of mismatch
Nmax = max([data.movieLength])-2;

cutoff_f = ip.Results.Cutoff_f;

% generate lifetime histograms
fprintf('Lifetime analysis:   0%%');
for k = 1:nd
    
    % load/create cell mask, discard tracks that fall into background
    mpath = [data(k).source 'Detection' filesep 'cellmask.tif'];
    if (exist(mpath, 'file')==2)
        mask = logical(imread(mpath));
    else
        mask = logical(getCellMask(data(k)));
    end
    
    % load tracks
    tracks = loadTracks(data(k), 'Mask', true);

    
    lifetimes_s = [tracks.lifetime_s];
    
    %====================
    % Track statistics
    %====================
    % Categories
    % Ia)  Single tracks with valid gaps
    % Ib)  Single tracks with invalid gaps
    % Ic)  Single tracks cut at beginning or end
    % Id)  Single tracks, persistent
    % IIa) Compound tracks with valid gaps
    % IIb) Compound tracks with invalid gaps
    % IIc) Compound tracks cut at beginning or end
    % IId) Compound tracks, persistent
    validGaps = arrayfun(@(t) max([t.gapStatus 4]), tracks)==4;
    singleIdx = [tracks.nSeg]==1;
    vis = [tracks.visibility];
    
    idx_Ia = singleIdx & validGaps & vis==1;
    idx_Ib = singleIdx & ~validGaps & vis==1;
    idx_IIa = ~singleIdx & validGaps & vis==1;
    
    v = [sum(idx_Ia);
        sum(idx_Ib);
        sum(singleIdx & vis==2);
        sum(singleIdx & vis==3);
        sum(idx_IIa);
        sum(~singleIdx & ~validGaps & vis==1);
        sum(~singleIdx & vis==2);
        sum(~singleIdx & vis==3)];
    
    if sum(v) ~= numel(tracks)
        error('Track classification error');
    end
    res.trackClassStats{k} = v/numel(tracks);
    
    %====================
    % Histogram etc.
    %====================
    lftHist = getLifetimeHistogram(data(k), tracks, Nmax, 'Cutoff_f', ip.Results.Cutoff_f, 'Buffer', ip.Results.Buffer);
    res.lftHist_Iab{k} = lftHist.Iab;
    res.lftHist_Ia{k} = lftHist.Ia;
    res.lftHist_Ib{k} = lftHist.Ib;
    res.lftHist_IIa{k} = lftHist.IIa;
    
    samples = lifetimes_s(idx_Ia);
    res.samples{k} = samples;
    res.nSamples(k) = numel(samples);
    
    % birth/death statistics
    startsPerFrame_all = hist([tracks.start], 1:data(k).movieLength);
    %startsPerFrame_Ia = hist([tracks(idx_Ia).start], 1:data(k).movieLength);
    
    %====================
    % Initiation density
    %====================
    
    % Cell area
    px = data(k).pixelSize / data(k).M; % pixels size in object space
    res.area(k) = sum(mask(:)) * px^2 / 1e-12; % in �m^2
    spf = startsPerFrame_all(4:end-cutoff_f);
    
    madFactor = 1/norminv(0.75, 0, 1);
    res.init_um_min(k,:) = [mean(spf); madFactor*mad(spf, 1)]/data(k).framerate*60/res.area(k);
    
    %====================
    % Gap statistics
    %====================
    
    binEdges = [0:20:120 data(k).movieLength-data(k).framerate];
    nb = length(binEdges)-1;
    gapsPerTrack_Ia = zeros(1,nb);
    gapsPerTrack_Ib = zeros(1,nb);
    gapsPerTrack_IIa = zeros(1,nb);
    for b = 1:nb
        tidx = binEdges(b)<=lifetimes_s & lifetimes_s<binEdges(b+1);
        gapsPerTrack_Ia(b) = mean(arrayfun(@(i) sum(i.gapVect), tracks(idx_Ia & tidx)));
        gapsPerTrack_Ib(b) = mean(arrayfun(@(i) sum(i.gapVect), tracks(idx_Ib & tidx)));
        gapsPerTrack_IIa(b) = mean(arrayfun(@(i) sum(i.gapVect), tracks(idx_IIa & tidx)));
    end
    res.gapsPerTrack_Ia{k} = gapsPerTrack_Ia;
    res.gapsPerTrack_Ib{k} = gapsPerTrack_Ib;
    res.gapsPerTrack_IIa{k} = gapsPerTrack_IIa;
    fprintf('\b\b\b\b%3d%%', round(100*k/(nd)));
end
fprintf('\n');

%-------------------------
% Mean histogram
%-------------------------
t_hist = (cutoff_f:Nmax)*framerate;

% Class percentages
v = mean([res.trackClassStats{:}],2);
v_std = std([res.trackClassStats{:}],[],2);

% meanHist_Iab =  mean(vertcat(res.lftHist_Iab{:}),1);
res.meanHist_Ia =  mean(vertcat(res.lftHist_Ia{:}),1);
res.meanHist_Ib =  mean(vertcat(res.lftHist_Ib{:}),1);
res.meanHist_IIa = mean(vertcat(res.lftHist_IIa{:}),1);



%-------------------------
% Assign output
%-------------------------
res.t = t_hist;
% res.meanHist_Ia = meanHist_Ia;
res.source = {data.source};

if strcmpi(ip.Results.Display, 'on')
    fset = loadFigureSettings();
    
    % classes
    hf(1) = plotTrackClasses(v, v_std, 'FaceColor', fset.cfTrackClasses, 'EdgeColor', fset.ceTrackClasses);
    
    % mean histograms (main classes)
    hf(2) = figure;
    hold on;
    hp(3) = plot(t_hist, res.meanHist_IIa, '.-', 'Color', 0.6*[1 1 1], 'LineWidth', 2, 'MarkerSize', 16);
    hp(2) = plot(t_hist, res.meanHist_Ib, '.-', 'Color', hsv2rgb([0 1 0.8]), 'LineWidth', 2, 'MarkerSize', 16);
    hp(1) = plot(t_hist, res.meanHist_Ia, '.-', 'Color', 'k', 'LineWidth', 2, 'MarkerSize', 16);
    axis([0 min(120, t_hist(end)) 0 0.05]);
    set(gca, 'LineWidth', 2, fset.sfont{:}, 'Layer', 'top');
    xlabel('Lifetime (s)', fset.lfont{:});
    ylabel('Frequency', fset.lfont{:});
    hl = legend(hp, 'Single tracks', 'Single tracks, rej. gaps', 'Comp. track', 'Location', 'NorthEast');
    set(hl, 'Box', 'off', fset.tfont{:});
    
    % gap statistics
    ce = fset.ceTrackClasses([1 2 5],:);
    cf = fset.cfTrackClasses([1 2 5],:);
    xlabels = arrayfun(@(b) [num2str(binEdges(b)) '-' num2str(binEdges(b+1)) ' s'], 1:numel(binEdges)-1, 'UniformOutput', false);
    
    
    M_Ia = vertcat(res.gapsPerTrack_Ia{:});
    M_Ib = vertcat(res.gapsPerTrack_Ib{:});
    M_IIa = vertcat(res.gapsPerTrack_IIa{:});
    
    M = [mean(M_Ia,1); mean(M_Ib,1); mean(M_IIa,1)]';
    S = [std(M_Ia,[],1); std(M_Ib,[],1); std(M_IIa,[],1)]';
    
    hf(3) = figure; barplot2(M, S, 'FaceColor', cf, 'EdgeColor', ce,...
        'XLabels', xlabels, 'XLabel', 'Lifetime cohort', 'YLabel', 'gaps/track');
    
end

if ip.Results.Print
    
    fpath = cell(1,nd);
    for k = 1:nd
        [~,fpath{k}] = getCellDir(data(k));
    end
    fpath = unique(fpath);
    if numel(fpath)>1
        fprintf('Figures could not be printed.');
    else
        fpath = [fpath{1} 'Figures' filesep];
        [~,~] = mkdir(fpath);
        print(hf(1), '-depsc2', [fpath 'trackClassDistribution.eps']);
        print(hf(2), '-depsc2', [fpath 'meanLftHist_classes.eps']);
        print(hf(3), '-depsc2', [fpath 'gapStatistics.eps']);
    end
end
