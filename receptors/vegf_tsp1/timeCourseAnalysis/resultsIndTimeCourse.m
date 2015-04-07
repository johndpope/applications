function [caseTimeList,caseResSummary] = resultsIndTimeCourse(ML,caseParam)
%RESULTSINDTIMECOURSE compiles the results of a group of movies making one or multiple timecourse datasets and orders them based on time
%
%SYNOPSIS [caseTimeList,caseResSummary] = resultsIndTimeCourse(ML,caseParam)
%
%INPUT  ML       : MovieList object containing all movies, either all
%                  belonging to one timecourse, or potentially belonging
%                  to multiple timecourses. The number of timecourses is
%                  indicated in the next variable.
%       caseParam: Structure array with number of entries = number of
%                  timecourses among which the movies will be divided. For
%                  each time course, it contains the following fields:
%           .indx    : Indices of movies in ML belonging to this
%                      timecourse.
%           .timeList: The time point of each movie, with order following
%                      the movie order in ML.
%           .name    : Case name, to be used in naming output variables.
%           .indx0min: Index of movie to be considered at time 0, e.g. when
%                      a ligand is added. If > 1, movies before will have a
%                      negative relative time, movies after wil have a
%                      positive relative time. If 1, relative time and
%                      absolute time are the same.
%    
%OUTPUT caseTimeList  : 2-column vector indicating the movie times. Column 1
%                       shows absolute time, Column 2 shows relative time.
%       caseResSummary: Structure array storing various results for each
%                       movie, ordered based on their time (corresponding
%                       to caseTimeList). Contains the fields: 
%           .diffSummary         : Diffusion analysis summary, as output
%                                  by summarizeDiffAnRes.
%           .diffCoefMeanPerClass: Mean diffusion coefficient per motion
%                                  class. Order: Immobile, confined, free,
%                                  directed, undetermined.
%           .confRadMeanPerClass : Mean confinement radius per motion
%                                  class. Same order as above.
%           .ampMeamPerClass     : Mean particle amplitude per motion
%                                  class. Same order as above.
%           .ampMeanFL20         : Mean particle amplitude in first and
%                                  last 20 frame of each movie.
%
%Khuloud Jaqaman, March 2015

%% Input and pre-processing

if nargin < 2
    error('resultsIndTimeCourse: Too few input arguments')
end

%get number of movies and number of cases
numMovies = length(ML.movieDataFile_);
numCases = length(caseParam);

%reserve memory for individual movie results
resSummary = struct('diffSummary',[],'diffCoefMeanPerClass',[],...
    'confRadMeanPerClass',[],'ampMeanPerClass',[],'ampMeanFL20',[],...
    'statsMS',[]);
resSummary = repmat(resSummary,numMovies,1);

%define directory for saving results
dir2save = [ML.movieListPath_ filesep 'analysisKJ'];

%% Calculations

%go over all movies
for iM = 1 : numMovies
    
    %read in raw results
    %     disp([num2str(iM) '  ' ML.movieDataFile_{iM}]);
    MD = MovieData.load(ML.movieDataFile_{iM}); 
    load(MD.processes_{3}.outFilePaths_{1});
    
    %diffusion analysis summary
    diffSummary = diffAnalysisRes(1).summary;
    
    %diffusion analysis per track
    trajClass = vertcat(diffAnalysisRes.classification);
    trajClass = trajClass(:,2);
    trajDiffCoef = catStruct(1,'diffAnalysisRes.fullDim.normDiffCoef');
    trajConfRad = catStruct(1,'diffAnalysisRes.confRadInfo.confRadius');
    
    %amplitude matrix
    tracksMat = convStruct2MatIgnoreMS(tracks);
    ampMat = tracksMat(:,4:8:end);
    
    %amplitude per track
    ampMeanPerTraj = nanmean(ampMat,2);
    
    %average properties per motion class
    [ampMeanPerClass,diffCoefMeanPerClass,confRadMeanPerClass] = deal(NaN(5,1));
    for i = 1 : 2
        indxClass = find(trajClass == (i-1));
        ampMeanPerClass(i) = mean(ampMeanPerTraj(indxClass));
        diffCoefMeanPerClass(i) = mean(trajDiffCoef(indxClass));
        confRadMeanPerClass(i) = mean(trajConfRad(indxClass));
    end
    for i = 3 : 4
        indxClass = find(trajClass == (i-1));
        ampMeanPerClass(i) = mean(ampMeanPerTraj(indxClass));
        diffCoefMeanPerClass(i) = mean(trajDiffCoef(indxClass));
    end
    ampMeanPerClass(5) = mean(ampMeanPerTraj(isnan(trajClass)));
    
    %average amplitude in first and last 20 frames
    tmp1 = ampMat(:,1:20);
    tmp2 = ampMat(:,end-19:end);
    ampMeanFL20 = [nanmean(tmp1(:)) nanmean(tmp2(:))];
    
    %merge and split statistics
    statsMS = calcStatsMS_noMotionInfo(tracks,5,1,1);
    
    %results for output
    resSummary(iM).diffSummary = diffSummary;
    resSummary(iM).diffCoefMeanPerClass = diffCoefMeanPerClass;
    resSummary(iM).confRadMeanPerClass = confRadMeanPerClass;
    resSummary(iM).ampMeanPerClass = ampMeanPerClass;
    resSummary(iM).ampMeanFL20 = ampMeanFL20;
    resSummary(iM).statsMS = statsMS;
    
end

%% Sorting and Saving

%go over each case and put its results together
for iCase = 1 : numCases
    
    %get parameters from input
    caseTimeList = caseParam(iCase).timeList;
    caseIndx = caseParam(iCase).indx;
    caseName = caseParam(iCase).name;
    caseMin0 = caseParam(iCase).indx0min;
    
    %sort time and add column for relative time
    offset = caseTimeList(caseMin0);
    [caseTimeList,indxSort] = sort(caseTimeList);
    caseTimeList = [caseTimeList caseTimeList-offset]; %#ok<AGROW>
    
    %collect and sort results
    caseResSummary = resSummary(caseIndx);
    caseResSummary = caseResSummary(indxSort);
    
    %name variables properly for saving
    eval(['timeList_' caseName ' = caseTimeList;'])
    eval(['resSummary_' caseName ' = caseResSummary;'])
    
    %save results
    file2save = fullfile(dir2save,['resSummary_' caseName]); %#ok<NASGU>
    eval(['save(file2save,''timeList_' caseName ''',''resSummary_' caseName ''');']);
    
end
