function [stats,M]=plusTipDynamParam(dataMatCrpSecMic)
% plusTipDynamParam: generic function for calculating dynamics parameters
%
% SYNOPSIS: [stats,M]=plusTipDynamParam(dataMatCrpSecMic)
%
% INPUT:
% dataMatCrpSecMic : matrix produced by plusTipMergeSubtracks, or a
%                    concatenated matrix from multiple movies
%
% OUTPUT:
% stats : structure containing parameters (see plusTipPostTracking for
%         list) based on the subset of tracks starting after the first
%         frame and ending before the last frame
% M     : n x 9 matrix, where the columns are
%           1. growth speed (microns/min)
%           2. fgap speed
%           3. bgap speed
%           4. growth lifetimes (sec)
%           5. fgap lifetimes
%           6. bgap lifetimes
%           7. growth displacements (microns)
%           8. fgap displacements
%           9. bgap displacements
%
% functions that call this one:
% plusTipPostTracking
% plusTipPoolGroupData


% growth speed, lifetime, displacement
gIdx=find(dataMatCrpSecMic(:,5)==1);
gs=dataMatCrpSecMic(gIdx,4);
gl=dataMatCrpSecMic(gIdx,6);
gd=dataMatCrpSecMic(gIdx,7);

% fgap speed, lifetime, displacement
fIdx=find(dataMatCrpSecMic(:,5)==2);
fs=dataMatCrpSecMic(fIdx,4);
fl=dataMatCrpSecMic(fIdx,6);
fd=dataMatCrpSecMic(fIdx,7);

% bgap speed, lifetime, displacement
bIdx=find(dataMatCrpSecMic(:,5)==3);
bs=dataMatCrpSecMic(bIdx,4);
bl=dataMatCrpSecMic(bIdx,6);
bd=dataMatCrpSecMic(bIdx,7);

% put populations into a matrix backfilled with NaNs
M=nan(max([length(gs) length(fs) length(bs)]),9);
M(1:length(gs),1)=gs;
M(1:length(fs),2)=fs;
M(1:length(bs),3)=bs;
M(1:length(gl),4)=gl;
M(1:length(fl),5)=fl;
M(1:length(bl),6)=bl;
M(1:length(gd),7)=gd;
M(1:length(fd),8)=fd;
M(1:length(bd),9)=bd;


% PARAMETERS RELATED TO GROWTH
stats.nGrowths=length(gIdx);
% median/mean for growth speeds (microns/minute)
stats.growth_speed_median = median(gs);
stats.growth_speed_mean_SE = [mean(gs) std(gs)/sqrt(length(gs))];
% median/mean for growth lifetime (sec)
stats.growth_lifetime_median = median(gl);
stats.growth_lifetime_mean_SE = [mean(gl) std(gl)/sqrt(length(gl))];
% median/mean for growth displacement (microns)
stats.growth_length_median = median(gd);
stats.growth_length_mean_SE = [mean(gd) std(gd)/sqrt(length(gd))];


% PARAMETERS RELATED TO FGAPS
if isempty(fIdx)
    stats.nFgaps=0;
    % median/mean for fgap speeds (microns/minute)
    stats.fgap_speed_median = NaN;
    stats.fgap_speed_mean_SE = [NaN NaN];
    % median/mean for fgap lifetime (sec)
    stats.fgap_lifetime_median = NaN;
    stats.fgap_lifetime_mean_SE = [NaN NaN];
    % median/mean for fgap displacement (microns)
    stats.fgap_length_median = NaN;
    stats.fgap_length_mean_SE = [NaN NaN];
    % frequencies of fgap are the average of 1 over the total time (sec) spent
    % growing prior to fgap, and the average of 1 over the total displacement
    % (microns) during growth prior to fgap
    stats.fgap_freq_time_mean_SE=[NaN NaN];
    stats.fgap_freq_length_mean_SE=[NaN NaN];

else
    stats.nFgaps=length(fIdx);
    % median/mean for fgap speeds (microns/minute)
    stats.fgap_speed_median = median(fs);
    stats.fgap_speed_mean_SE = [mean(fs) std(fs)/sqrt(length(fs))];
    % median/mean for fgap lifetime (sec)
    stats.fgap_lifetime_median = median(fl);
    stats.fgap_lifetime_mean_SE = [mean(fl) std(fl)/sqrt(length(fl))];
    % median/mean for fgap displacement (microns)
    stats.fgap_length_median = median(fd);
    stats.fgap_length_mean_SE = [mean(fd) std(fd)/sqrt(length(fd))];
    % frequencies of fgap are the average of 1 over the total time (sec) spent
    % growing prior to fgap, and the average of 1 over the total displacement
    % (microns) during growth prior to fgap
    beforeFgapIdx=fIdx-1;
    freq=1./dataMatCrpSecMic(beforeFgapIdx,6);
    stats.fgap_freq_time_mean_SE=[mean(freq) std(freq)/sqrt(length(freq))];
    freq=1./dataMatCrpSecMic(beforeFgapIdx,7);
    stats.fgap_freq_length_mean_SE=[mean(freq) std(freq)/sqrt(length(freq))];
end

% PARAMETERS RELATED TO BGAPS
if isempty(bIdx)
    stats.nBgaps=0;
    % median/mean for bgap speeds (microns/minute)
    stats.bgap_speed_median = NaN;
    stats.bgap_speed_mean_SE = [NaN NaN];
    % median/mean for bgap lifetime (sec)
    stats.bgap_lifetime_median = NaN;
    stats.bgap_lifetime_mean_SE = [NaN NaN];
    % median/mean for bgap displacement (microns)
    stats.bgap_length_median = NaN;
    stats.bgap_length_mean_SE = [NaN NaN];
    % frequencies of bgap are the average of 1 over the total time (sec) spent
    % growing prior to bgap, and the average of 1 over the total displacement
    % (microns) during growth prior to bgap
    stats.bgap_freq_time_mean_SE=[NaN NaN];
    stats.bgap_freq_length_mean_SE=[NaN NaN];

else
    stats.nBgaps=length(bIdx);
    % median/mean for bgap speeds (microns/minute)
    stats.bgap_speed_median = median(bs);
    stats.bgap_speed_mean_SE = [mean(bs) std(bs)/sqrt(length(bs))];
    % median/mean for bgap lifetime (sec)
    stats.bgap_lifetime_median = median(bl);
    stats.bgap_lifetime_mean_SE = [mean(bl) std(bl)/sqrt(length(bl))];
    % median/mean for bgap displacement (microns)
    stats.bgap_length_median = median(bd);
    stats.bgap_length_mean_SE = [mean(bd) std(bd)/sqrt(length(bd))];
    % frequencies of bgap are the average of 1 over the total time (sec) spent
    % growing prior to bgap, and the average of 1 over the total displacement
    % (microns) during growth prior to bgap
    beforeBgapIdx=bIdx-1;
    freq=1./dataMatCrpSecMic(beforeBgapIdx,6);
    stats.bgap_freq_time_mean_SE=[mean(freq) std(freq)/sqrt(length(freq))];
    freq=1./dataMatCrpSecMic(beforeBgapIdx,7);
    stats.bgap_freq_length_mean_SE=[mean(freq) std(freq)/sqrt(length(freq))];
end

% MISC PARAMETERS

% percent of time spent in growth, fgap, and bgap
totalTime=sum(gl)+sum(fl)+sum(bl);
stats.percentTimeGrowth=100*(sum(gl)/totalTime);
stats.percentTimeFgap  =100*(sum(fl)/totalTime);
stats.percentTimeBgap  =100*(sum(bl)/totalTime);

if stats.nFgaps+stats.nBgaps~=0
    % percent nFgaps/nGaps
    stats.percentGapsForward = 100*(stats.nFgaps/(stats.nFgaps+stats.nBgaps));
    % percent nBgaps/nGaps
    stats.percentGapsBackward= 100*(stats.nBgaps/(stats.nFgaps+stats.nBgaps));
else
    % percent nFgaps/nGaps
    stats.percentGapsForward = NaN;
    % percent nBgaps/nGaps
    stats.percentGapsBackward= NaN;
end


% if next one after growth has index 2, it's an fgap; if 3, it's a bgap; if
% 1 or 4, it is unlinked to another subtrack
if gIdx(end)==size(dataMatCrpSecMic,1)
    gIdx(end)=[];
end

f=sum(dataMatCrpSecMic(gIdx+1,5)==2);
b=sum(dataMatCrpSecMic(gIdx+1,5)==3);
u=sum(dataMatCrpSecMic(gIdx+1,5)==1 | dataMatCrpSecMic(gIdx+1,5)==4);

% percent of growths ending in fgap, bgap, or nothing
stats.percentGrowthLinkedForward  = 100*(f/length(gIdx));
stats.percentGrowthLinkedBackward = 100*(b/length(gIdx));
stats.percentGrowthTerminal       = 100*(u/length(gIdx));


% all track indices where there is either a forward or backward gap
tracksWithFgap=unique(dataMatCrpSecMic(dataMatCrpSecMic(:,5)==2,1));
tracksWithBgap=unique(dataMatCrpSecMic(dataMatCrpSecMic(:,5)==3,1));

% calculate the average percentage of time a MT spends in fgap
idx=unique(tracksWithFgap);
if ~isempty(idx)
    idxCell=mat2cell(idx,ones(length(idx),1),1);
    % sub track indices of the full tracks
    subIdxAll=cellfun(@(x) find(dataMatCrpSecMic(:,1)==x),idxCell,'uniformoutput',0);
    % full track lifetimes and displacements
    ltfAll=cell2mat(cellfun(@(x) sum(dataMatCrpSecMic(x,6)),subIdxAll,'uniformoutput',0));
    
    % sub track indices of the full tracks
    subIdxFgaps=cellfun(@(x) find(dataMatCrpSecMic(:,1)==x & dataMatCrpSecMic(:,5)==2),idxCell,'uniformoutput',0);
    % full track lifetimes and displacements
    ltfFgaps=cell2mat(cellfun(@(x) sum(dataMatCrpSecMic(x,6)),subIdxFgaps,'uniformoutput',0));
    
    % average percent of time spent in fgap for individual MT
    stats.avgIndivPercentTimeFgap=100*mean(ltfFgaps./ltfAll);
    
    clear idx idxCell subIdxAll
else
    stats.avgIndivPercentTimeFgap=NaN;
end


% calculate the average percentage of time a MT spends in bgap
idx=unique(tracksWithBgap);
if ~isempty(idx)
    idxCell=mat2cell(idx,ones(length(idx),1),1);
    % sub track indices of the full tracks
    subIdxAll=cellfun(@(x) find(dataMatCrpSecMic(:,1)==x),idxCell,'uniformoutput',0);
    % full track lifetimes and displacements
    ltfAll=cell2mat(cellfun(@(x) sum(dataMatCrpSecMic(x,6)),subIdxAll,'uniformoutput',0));
    
    % sub track indices of the full tracks
    subIdxBgaps=cellfun(@(x) find(dataMatCrpSecMic(:,1)==x & dataMatCrpSecMic(:,5)==3),idxCell,'uniformoutput',0);
    % full track lifetimes and displacements
    ltfBgaps=cell2mat(cellfun(@(x) sum(dataMatCrpSecMic(x,6)),subIdxBgaps,'uniformoutput',0));
    
    % average percent of time spent in bgap for individual MT
    stats.avgIndivPercentTimeBgap=100*mean(ltfBgaps./ltfAll);
    
    clear idx idxCell subIdxAll
else
    stats.avgIndivPercentTimeBgap=NaN;
end

% calculate dynamicity (mic/min)
idx=unique([tracksWithFgap; tracksWithBgap]);
if ~isempty(idx)
    idxCell=mat2cell(idx,ones(length(idx),1),1);
    % sub track indices of the full tracks
    subIdx=cellfun(@(x) find(dataMatCrpSecMic(:,1)==x),idxCell,'uniformoutput',0);
    % full track lifetimes and displacements
    ltf=cell2mat(cellfun(@(x) sum(dataMatCrpSecMic(x,6)),subIdx,'uniformoutput',0));
    disp=cell2mat(cellfun(@(x) sum(abs(dataMatCrpSecMic(x,7))),subIdx,'uniformoutput',0));
    % collective displacement of all gap-containing MTs over their collective lifetime
    stats.dynamicity=sum(disp)/(sum(ltf)/60);
else
    stats.dynamicity=NaN;
end



