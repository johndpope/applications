function lftRes = runLifetimeAnalysis(data, varargin)

ip = inputParser;
ip.CaseSensitive = false;
ip.addRequired('data', @(x) isstruct(x) && numel(unique([data.framerate]))==1);
ip.addOptional('lb', [3:10 11 16 21 41 61 81 101 141]);
ip.addOptional('ub', [3:10 15 20 40 60 80 100 140 200]);
ip.addParamValue('Display', 'on', @(x) strcmpi(x, 'on') | strcmpi(x, 'off'));
ip.addParamValue('FileName', 'ProcessedTracks.mat', @ischar);
ip.addParamValue('Type', 'all', @ischar);
ip.addParamValue('Cutoff_f', 4, @isscalar);
ip.addParamValue('Print', false, @islogical);
ip.addParamValue('Buffer', 5);
ip.addParamValue('MaxIntensityThreshold', []);
ip.addParamValue('Overwrite', false, @islogical);
ip.addParamValue('ClassificationSelector', 'significantSignal');
ip.parse(data, varargin{:});
lb = ip.Results.lb;
ub = ip.Results.ub;
nd = length(data);
nc = numel(lb); % # cohorts

% median absolute deviation -> standard deviation
madFactor = 1/norminv(0.75, 0, 1);

% Extend all to max. movie length, in case of mismatch
Nmax = max([data.movieLength])-2;
buffer = ip.Results.Buffer;
cutoff_f = ip.Results.Cutoff_f;

framerate = data(1).framerate;

firstN = 3:20;

% loop through data sets, load tracks, store max. intensities and lifetimes
res = struct([]);
% lftRes = struct([]);


% fprintf('Lifetime analysis (%s) - loading tracks:     ', getShortPath(data));
lftFields = {'lifetime_s', 'trackLengths', 'start', 'catIdx'};
fprintf('=================================================\n');
fprintf('Lifetime analysis - loading tracks:   0%%');
for i = 1:nd
    lftData = getLifetimeData(data(i), 'Overwrite', ip.Results.Overwrite);
    
    % apply frames cutoff for short tracks
    lftData.intMat_Ia(lftData.trackLengths(lftData.catIdx==1)<cutoff_f,:) = [];
    idx = lftData.trackLengths < cutoff_f;
    for f = 1:numel(lftFields)
        lftData.(lftFields{f})(idx) = [];
    end
    lifetime_s = lftData.lifetime_s;
    
    % Category statistics
    idx_Ia = [lftData.catIdx]==1;
    idx_Ib = [lftData.catIdx]==2;
    idx_IIa = [lftData.catIdx]==5;
    v = hist([lftData.catIdx], 1:8);
    v = v/numel(lifetime_s);
    lftRes.trackClassStats(i,:) = v;
    
    % raw histograms
    N = data(i).movieLength-2*buffer;
    t = (cutoff_f:N)*framerate;
    lftHist_Ia = hist(lifetime_s(idx_Ia), t);
    lftHist_Ib = hist(lifetime_s(idx_Ib), t);
    lftHist_IIa = hist(lifetime_s(idx_IIa), t);
    
    % apply correction
    % relative probabilities:
    % P(obs. lifetime==1) = N
    % P(obs. lifetime==N) = 1
    % => weighting:
    w = N./(N-cutoff_f+1:-1:1);
    pad0 = zeros(1,Nmax-N);
    lftHist_Ia =  [lftHist_Ia.*w  pad0];
    lftHist_Ib =  [lftHist_Ib.*w  pad0];
    lftHist_IIa = [lftHist_IIa.*w pad0];
    res(i).t = (cutoff_f:Nmax)*framerate;
    
    % Normalization
    res(i).lftHist_Ia = lftHist_Ia / sum(lftHist_Ia) / framerate;
    res(i).lftHist_Ib = lftHist_Ib / sum(lftHist_Ib) / framerate;
    res(i).lftHist_IIa = lftHist_IIa / sum(lftHist_IIa) / framerate;
   
    % birth/death statistics
    startsPerFrame_all = hist(lftData.start, 1:data(i).movieLength);
    startsPerFrame_all = startsPerFrame_all(6:end-2);
    startsPerFrame_Ia = hist(lftData.start(idx_Ia), 1:data(i).movieLength);
    startsPerFrame_Ia = startsPerFrame_Ia(6:end-2);
    
    %-------------------------------------------------------------
    % Initiation density
    %-------------------------------------------------------------
    
    % Cell area
    px = data(i).pixelSize / data(i).M; % pixels size in object space
    mpath = [data(i).source 'Detection' filesep 'cellmask.tif'];
    mask = logical(imread(mpath));
    lftRes.cellArea(i) = sum(mask(:)) * px^2 / 1e-12; % in �m^2
    
    % in �m^-2 min^-1
    lftRes.initDensity_all(i,:) = [median(startsPerFrame_all); madFactor*mad(startsPerFrame_all, 1)]/data(i).framerate*60/lftRes.cellArea(i);
    lftRes.initDensity_Ia(i,:) = [median(startsPerFrame_Ia); madFactor*mad(startsPerFrame_Ia, 1)]/data(i).framerate*60/lftRes.cellArea(i);
    
    %-------------------------------------------------------------
    % Max. intensity distribution for cat. Ia CCP tracks
    %-------------------------------------------------------------
    lifetime_s = lifetime_s(idx_Ia);
    
    M = lftData.intMat_Ia;
    res(i).M = M;
    for k = 1:nc
        % indexes within cohorts
        cidx = lb(k)<=lifetime_s & lifetime_s<=ub(k);
        res(i).maxA{k} = nanmax(M(cidx,:),[],2);
        for n = firstN
           res(i).(['maxA_f' num2str(n)]){k} = nanmax(M(cidx,1:n),[],2);
        end
        
        % lifetimes for given cohort
        res(i).lft{k} = lifetime_s(cidx);
    end
    
    res(i).lft_all = lifetime_s;
    res(i).maxA_all = nanmax(M,[],2)';
    if isfield(lftData, 'significantSignal')
        res(i).significantSignal = lftData.significantSignal(:,idx_Ia);
    end
    res(i).firstN = firstN;
    
fprintf('\b\b\b\b%3d%%', round(100*i/nd));
end
fprintf('\n');

%====================
% Initiation density
%====================
fprintf(2, 'Initiation density, all tracks:\n');
for i = 1:nd
    fprintf('%s: %.3f � %.3f [�m^-2 min^-1]\n', getCellDir(data(i)), lftRes.initDensity_all(i,1), lftRes.initDensity_all(i,2));
end
% fprintf('Initiation density, SEM: %f � %f [�m^-2 min^-1]\n', mean(D(1,:)), std(D(1,:))/sqrt(nd));
fprintf(2, 'Average: %.3f � %.3f [�m^-2 min^-1]\n', mean(lftRes.initDensity_all(:,1)), std(lftRes.initDensity_all(:,1)));
fprintf('-------------------------------------------------\n');
fprintf(2, 'Initiation density, valid tracks only:\n');
for i = 1:nd
    fprintf('%s: %.3f � %.3f [�m^-2 min^-1]\n', getCellDir(data(i)), lftRes.initDensity_Ia(i,1), lftRes.initDensity_Ia(i,2));
end
fprintf(2, 'Average: %.3f � %.3f [�m^-2 min^-1]\n', mean(lftRes.initDensity_Ia(:,1)), std(lftRes.initDensity_Ia(:,1)));
fprintf('-------------------------------------------------\n');



%====================
% Threshold
%====================
% Rescale EDFs (correction for FP-fusion expression level)
a = rescaleEDFs({res.maxA_all}, 'Display', false);

% apply scaling
for i = 1:nd
    res(i).maxA_all = a(i) * res(i).maxA_all;
    res(i).maxA = cellfun(@(x) a(i)*x, res(i).maxA, 'UniformOutput', false);
    for n = firstN
       fname = ['maxA_f' num2str(n)];
       res(i).(fname) = cellfun(@(x) a(i)*x, res(i).(fname), 'UniformOutput', false);
    end
end

if isempty(ip.Results.MaxIntensityThreshold)
    % lifetime cohort: [5..10] seconds
    % combine first 5 frames from all cohorts
    
    maxIntDistCat_f5 = horzcat(res.maxA_f5);
    maxIntDistCat_f5 = vertcat(maxIntDistCat_f5{:});
    
    %[mu_g sigma_g] = fitGaussianModeToPDF(maxIntDistCat_f5);
    [mu_g sigma_g] = fitGaussianModeToCDF(maxIntDistCat_f5);
    T = norminv(0.99, mu_g, sigma_g);
    fprintf('Max. intensity threshold: %.2f\n', T);
else
    T = ip.Results.MaxIntensityThreshold;
end

% loop through data sets, apply max. intensity threshold
for i = 1:nd
    idx = res(i).maxA_all >= T;
    res(i).lftAboveT = res(i).lft_all(idx);
    res(i).lftBelowT = res(i).lft_all(~idx);
    lftRes.pctAbove(i) = sum(idx)/numel(idx);
    
    N = data(i).movieLength-2*buffer;
    t = (cutoff_f:N)*framerate;
    %t = (1:N)*framerate;
    lftHist_A = hist(res(i).lftAboveT, t);
    lftHist_B = hist(res(i).lftBelowT, t);
    
    %lftHist_A(1:cutoff_f-1) = [];
    %lftHist_B(1:cutoff_f-1) = [];
    
    % apply correction
    % relative probabilities:
    % P(obs. lifetime==1) = N
    % P(obs. lifetime==N) = 1
    % => weighting:
    w = N./(N-cutoff_f+1:-1:1);
    pad0 = zeros(1,Nmax-N);
    lftHist_A =  [lftHist_A.*w  pad0];
    lftHist_B =  [lftHist_B.*w  pad0];
    
    % Normalization
    %normA = sum(lftHist_A);
    %normB = sum(lftHist_B);
    lftRes.lftHist_A(i,:) = lftHist_A / sum(lftHist_A) / framerate;
    lftRes.lftHist_B(i,:) = lftHist_B / sum(lftHist_B) / framerate;
    
    if isfield(res, 'significantSignal')
        lftHist_Apos = hist(res(i).lft_all(idx & res(i).significantSignal(2,:)), t);
        lftHist_Aneg = hist(res(i).lft_all(idx & ~res(i).significantSignal(2,:)), t);
        lftHist_Bpos = hist(res(i).lft_all(~idx & res(i).significantSignal(2,:)), t);
        lftHist_Bneg = hist(res(i).lft_all(~idx & ~res(i).significantSignal(2,:)), t);
        lftHist_Apos =  [lftHist_Apos.*w  pad0];
        lftHist_Aneg =  [lftHist_Aneg.*w  pad0];
        lftHist_Bpos =  [lftHist_Bpos.*w  pad0];
        lftHist_Bneg =  [lftHist_Bneg.*w  pad0];
        lftRes.lftHist_Apos(i,:) = lftHist_Apos / sum(lftHist_Apos) / framerate;
        lftRes.lftHist_Aneg(i,:) = lftHist_Aneg / sum(lftHist_Aneg) / framerate;
        lftRes.lftHist_Bpos(i,:) = lftHist_Bpos / sum(lftHist_Bpos) / framerate;
        lftRes.lftHist_Bneg(i,:) = lftHist_Bneg / sum(lftHist_Bneg) / framerate;
        %lftRes.lftHist_Apos(i,:) = lftHist_Apos / normA / framerate;
        %lftRes.lftHist_Aneg(i,:) = lftHist_Aneg / normA / framerate;
        %lftRes.lftHist_Bpos(i,:) = lftHist_Bpos / normB / framerate;
        %lftRes.lftHist_Bneg(i,:) = lftHist_Bneg / normB / framerate;
        
        lftRes.pctAboveSignificant(i) = sum(idx & res(i).significantSignal(2,:))/numel(idx);
        lftRes.pctAboveNS(i) = sum(idx & ~res(i).significantSignal(2,:))/numel(idx);
        lftRes.pctBelowSignificant(i) = sum(~idx & res(i).significantSignal(2,:))/numel(idx);
    end
end

lftRes.t_hist = (cutoff_f:Nmax)*framerate;
lftRes.meanLftHist_A =  mean(lftRes.lftHist_A,1);
lftRes.meanLftHist_B =  mean(lftRes.lftHist_B,1);
lftRes.data = data;

plotLifetimes(lftRes);

%=====================================================================
% Fit lifetime histogram with Weibull-distributed populations
%=====================================================================
fitResCDF = fitLifetimeDistWeibullModel(lftRes, 'Mode', 'CDF');
fitResPDF = fitLifetimeDistWeibullModel(lftRes, 'Mode', 'PDF');
plotLifetimeDistModel(lftRes, fitResCDF);
plotLifetimeDistModel(lftRes, fitResPDF);

fitResPDF = fitLifetimeDistGammaModel(lftRes, 'Mode', 'PDF');
plotLifetimeDistModel(lftRes, fitResPDF);
% fitResCDF = fitLifetimeDistGammaModel(lftRes, 'Mode', 'CDF');
% plotLifetimeDistModel(lftRes, fitResCDF);

return
    %====================
    % Histogram etc.
    %====================
%     lftHist = getLifetimeHistogram(data(k), tracks, Nmax, 'Cutoff_f', ip.Results.Cutoff_f, 'Buffer', ip.Results.Buffer);
%     res.lftHist_Ia{k} = lftHist.Ia;
%     res.lftHist_Ib{k} = lftHist.Ib;
%     res.lftHist_IIa{k} = lftHist.IIa;    
    %====================
    % Gap statistics
    %==================== 
%     binEdges = [0:20:120 data(k).movieLength-data(k).framerate];
%     nb = length(binEdges)-1;
%     gapsPerTrack_Ia = zeros(1,nb);
%     gapsPerTrack_Ib = zeros(1,nb);
%     gapsPerTrack_IIa = zeros(1,nb);
%     for b = 1:nb
%         tidx = binEdges(b)<=lifetimes_s & lifetimes_s<binEdges(b+1);
%         gapsPerTrack_Ia(b) = mean(arrayfun(@(i) sum(i.gapVect), tracks(idx_Ia & tidx)));
%         gapsPerTrack_Ib(b) = mean(arrayfun(@(i) sum(i.gapVect), tracks(idx_Ib & tidx)));
%         gapsPerTrack_IIa(b) = mean(arrayfun(@(i) sum(i.gapVect), tracks(idx_IIa & tidx)));
%     end
%     res.gapsPerTrack_Ia{k} = gapsPerTrack_Ia;
%     res.gapsPerTrack_Ib{k} = gapsPerTrack_Ib;
%     res.gapsPerTrack_IIa{k} = gapsPerTrack_IIa;


%-------------------------
% Mean histogram
%-------------------------
meanHist_Ia =  mean(vertcat(res.lftHist_Ia),1);
meanHist_Ib =  mean(vertcat(res.lftHist_Ib),1);
meanHist_IIa = mean(vertcat(res.lftHist_IIa),1);



%-------------------------
% Assign output
%-------------------------
% res.t = t_hist;
% res.meanHist_Ia = meanHist_Ia;
% res.source = {data.source};

if strcmpi(ip.Results.Display, 'on')
    fset = loadFigureSettings();
    
   
    % mean histograms (main classes)
    hf(1) = figure;
    hold on;
    hp(3) = plot(t_hist, meanHist_IIa, '.-', 'Color', 0.6*[1 1 1], 'LineWidth', 2, 'MarkerSize', 16);
    hp(2) = plot(t_hist, meanHist_Ib, '.-', 'Color', hsv2rgb([0 1 0.8]), 'LineWidth', 2, 'MarkerSize', 16);
    hp(1) = plot(t_hist, meanHist_Ia, '.-', 'Color', 'k', 'LineWidth', 2, 'MarkerSize', 16);
    axis([0 min(120, t_hist(end)) 0 0.05]);
    set(gca, 'LineWidth', 2, fset.sfont{:}, 'Layer', 'top');
    xlabel('Lifetime (s)', fset.lfont{:});
    ylabel('Frequency', fset.lfont{:});
    hl = legend(hp, 'Single tracks, valid', 'Single tracks, rejected', 'Compound tracks', 'Location', 'NorthEast');
    set(hl, 'Box', 'off', fset.tfont{:});
    
    
    
     % classes
%     hf(2) = plotTrackClasses(v', v_std', 'FaceColor', fset.cfTrackClasses, 'EdgeColor', fset.ceTrackClasses);
    
    
    
    % gap statistics
%     ce = fset.ceTrackClasses([1 2 5],:);
%     cf = fset.cfTrackClasses([1 2 5],:);
%     xlabels = arrayfun(@(b) [num2str(binEdges(b)) '-' num2str(binEdges(b+1)) ' s'], 1:numel(binEdges)-1, 'UniformOutput', false);
    
    
%     M_Ia = vertcat(res.gapsPerTrack_Ia{:});
%     M_Ib = vertcat(res.gapsPerTrack_Ib{:});
%     M_IIa = vertcat(res.gapsPerTrack_IIa{:});
%     
%     M = [mean(M_Ia,1); mean(M_Ib,1); mean(M_IIa,1)]';
%     S = [std(M_Ia,[],1); std(M_Ib,[],1); std(M_IIa,[],1)]';
%     
%     hf(3) = figure; barplot2(M, S, 'FaceColor', cf, 'EdgeColor', ce,...
%         'XLabels', xlabels, 'XLabel', 'Lifetime cohort', 'YLabel', 'gaps/track');
    
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
