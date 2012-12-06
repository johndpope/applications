function cellData = formatEdgeVelocity(movieObj,varargin)
%This function takes the output of the protrusion sampling process and formats each edge velocity time series
%Format actually means TS pre-processing. It removes: outliers, mean, trend, NaN and close gaps 
%
% Usage: cellData = formatEdgeVelocity(ML,varargin)
%
% INPUTS:
%       ML - movie list or movie data object  
%
%       excludeWin - indexes of the windows(variables) to be excluded
%                    Ex: If #Windows = 100, Exclude border windows: [1 2 3 98 99 100];    
%
%       outLevel  - # of sigmas considered for outlier removal (see detectOutliers)
%
%       trendType - optional: a scalar giving the type of trend to remove
%                  -1 : no trend removal (default)
%                   0 : remove only sample means (see dtrend.m)
%                   1 : remove linear trend (see dtrend.m)
%                   2 : remove all deterministic trend
%
%       minLength  - minimal length accepted. Any window that has a TS with less than
%                    minLength points will be discarded. (Default = 30)
%
%
%Marco Vilela, 2012
%UnderConstruction

ip = inputParser;
ip.addRequired('movieObj',@(x) isa(x,'MovieList') || isa(x,'MovieData'));
ip.addParamValue('excludeWin', [],@isvector);
ip.addParamValue('outLevel',7,@isscalar);
ip.addParamValue('trend',   -1,@isscalar);
ip.addParamValue('minLen',  30,@isscalar);

ip.parse(movieObj,varargin{:});
excludeWin = ip.Results.excludeWin;
outLevel   = ip.Results.outLevel;
minLen     = ip.Results.minLen;
trend      = ip.Results.trend;

if isa(movieObj,'MovieData')
    
    ML = movieData2movieList(movieObj);
    
else
    
    ML = movieObj;
    
end

nCell = numel(ML.movies_);
tPaux = cell(nCell,1);

for iCell = 1:nCell
    
    currMD = ML.movies_{iCell};
    
    cellData(iCell).data.excludeWin = excludeWin;
    cellData(iCell).data.pixelSize  = currMD.pixelSize_;
    cellData(iCell).data.frameRate  = currMD.timeInterval_;

    
    edgeProcIdx = currMD.getProcessIndex('ProtrusionSamplingProcess');
    scaling     = currMD.pixelSize_/currMD.timeInterval_;

    
    %Converting the edge velocity in pixel/frame into nanometers/seconds
    protSamples                        = currMD.processes_{edgeProcIdx}.loadChannelOutput;
    cellData(iCell).data.rawEdgeMotion = protSamples.avgNormal*scaling;
    
   
    tRawP = cellData(iCell).data.rawEdgeMotion;
    
    %Extracting outliers
    tRawP(detectOutliers(tRawP,outLevel)) = NaN;
    
    %Extracting pre-selected windows*****************************************
    
    tRawP(excludeWin,:) = [];
        
    %***************************************************************
    %Removing NaN and closing 1 frame gaps
    [tPaux{iCell},~,~,~,excludeVar]     = removeMeanTrendNaN(tRawP','trendType',trend,'minLength',minLen);
        
    cellData(iCell).data.procEdgeMotion = tPaux{iCell};
    cellData(iCell).data.excludeWin     = unique([cellData(iCell).data.excludeWin excludeVar]);
    
end
%% Saving results per cell
savingMovieResultsPerCell(ML,cellData)

end