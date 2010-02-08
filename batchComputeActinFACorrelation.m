function batchComputeActinFACorrelation(varargin)
%      BATCHCOMPUTEACTINFACORRELATION(forceRedo) Compute the correlation
%      between Actin speed and F:
%      - average Actin speed along Actin tracks
%      - average TM speed along Actin tracks.
%      - average protrusion value along Actin tracks.
% 'forceRun' forces to recompute results.

if nargin >= 1 && ~isempty(varargin{1})
    rootDirectory = varargin{1};
else
    % Ask for the root directory.
    rootDirectory = uigetdir('', 'Select a root directory:');

    if ~ischar(rootDirectory)
        return;
    end
end

if nargin >= 2 && ~isempty(varargin{2})
    forceRun = varargin{2};
else
    forceRun = zeros(9, 1);
end

if nargin >= 3 && ~isempty(varargin{3})
    batchMode = varargin{3};
else
    batchMode = 1;
end

% Get every path from rootDirectory containing ch488 & ch560 subfolders.
paths = getDirectories(rootDirectory, 2, {'ch488', 'ch560'});

disp('List of directories:');

for iMovie = 1:numel(paths)
    disp([num2str(iMovie) ': ' paths{iMovie}]);
end

disp('Process all directories (Grab a coffee)...');

nMovies = numel(paths);

movieData = cell(nMovies, 1);

for iMovie = 1:nMovies
    movieName = ['Movie ' num2str(iMovie) '/' num2str(numel(paths))];
    
    path = paths{iMovie};
   
    currMovie = movieData{iMovie};
    
    %% STEP 1: Create the initial movie data

    try
        fieldNames = {...
            'bgDirectory',...
            'roiDirectory',...
            'tifDirectory',...
            'stkDirectory',...
            'analysisDirectory'};
        
        subDirNames = {'bg', 'roi', 'tif', 'stk', 'analysis'};
        
        channels = cell(numel(fieldNames), 1, 2);
        channels(:, 1, 1) = cellfun(@(x) [path filesep 'ch488' filesep x],...
            subDirNames, 'UniformOutput', false);
        channels(:, 1, 2) = cellfun(@(x) [path filesep 'ch560' filesep x],...
            subDirNames, 'UniformOutput', false);
        currMovie.channels = cell2struct(channels, fieldNames, 1);
        
        % We put every subsequent analysis in the ch488 analysis directory.
        currMovie.analysisDirectory = currMovie.channels(1).analysisDirectory;
        
        % Add these 2 fields to be compliant with Hunter's check routines:
        currMovie.imageDirectory = currMovie.channels(1).roiDirectory;
        currMovie.channelDirectory = {''};
        
        % STEP 1.1: Get the number of images
        
        n1 = numel(dir([currMovie.channels(1).roiDirectory filesep '*.tif']));
        n2 = numel(dir([currMovie.channels(2).roiDirectory filesep '*.tif']));
        
        assert(n1 > 0 && n1 == n2);
        
        currMovie.nImages = n1;
        
        % STEP 1.2: Load physical parameter from
        load([currMovie.channels(2).analysisDirectory filesep 'fsmPhysiParam.mat']);
        currMovie.pixelSize_nm = fsmPhysiParam.pixelSize;
        currMovie.timeInterval_s = fsmPhysiParam.frameInterval;
        clear fsmPhysiParam;
        
        % STEP 1.3: Get the mask directory
        currMovie.masks.directory = [currMovie.channels(2).analysisDirectory...
            filesep 'edge' filesep 'cell_mask'];
        currMovie.masks.channelDirectory = {''};
        currMovie.masks.n = numel(dir([currMovie.masks.directory filesep '*.tif']));
        currMovie.masks.status = 1;
        
        % STEP 1.4: Update from already saved movieData
        if exist([currMovie.analysisDirectory filesep 'movieData.mat'], 'file') && ~forceRun(1)
            currMovie = load([currMovie.analysisDirectory filesep 'movieData.mat']);
            currMovie = currMovie.movieData;
        end
    catch errMess
        disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);
        disp(['Error in movie ' num2str(iMovie) ': ' errMess.message '(SKIPPING)']);
        continue;
    end
    
    %% STEP 2: Get the contour
    
%     dContour = 15; % ~ 1um
%     dWin = 10;
%     iStart = 2;
%     iEnd = 10;
%     winMethod = 'e';    
    
    dContour = 1000 / currMovie.pixelSize_nm; % ~ 1um
    dWin = 2000 / currMovie.pixelSize_nm; % ~ 2um
    iStart = 2;
    iEnd = 4;
    winMethod = 'c';
    
    if ~isfield(currMovie,'contours') || ~isfield(currMovie.contours,'status') || ...
            currMovie.contours.status ~= 1 || forceRun(2)
        try
            disp(['Get contours of movie ' num2str(iMovie) ' of ' num2str(nMovies) '...']);
            currMovie = getMovieContours(currMovie, 0:dContour:500, 0, 1, ...
                ['contours_'  num2str(dContour) 'pix.mat'], batchMode);
            
            if isfield(currMovie.contours, 'error')
                currMovie.contours = rmfield(currMovie.contours,'error');
            end            
        catch errMess
            disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);
            currMovie.contours.error = errMess;
            currMovie.contours.status = 0;
        end
    end

    %% STEP 3: Calculate protusion

    if ~isfield(currMovie,'protrusion') || ~isfield(currMovie.protrusion,'status') || ...
            currMovie.protrusion.status ~= 1 || forceRun(3)
        try
            currMovie.protrusion.status = 0;

            currMovie = setupMovieData(currMovie);

            handles.batch_processing = batchMode;
            handles.directory_name = [currMovie.masks.directory];
            handles.result_directory_name = [currMovie.masks.directory];
            handles.FileType = '*.tif';
            handles.timevalue = currMovie.timeInterval_s;
            handles.resolutionvalue = currMovie.pixelSize_nm;
            handles.segvalue = 30;
            handles.dl_rate = 30;

            %run it
            [OK,handles] = protrusionAnalysis(handles);

            if ~OK
                currMovie.protrusion.status = 0;
            else
                if isfield(currMovie.protrusion,'error')
                    currMovie.protrusion = rmfield(currMovie.protrusion,'error');
                end
                
                %currMovie.protrusion.directory = [currMovie.masks.directory];
                % Workaround:
                currMovie.protrusion.directory = [currMovie.masks.directory filesep ...
                    'analysis_dl' num2str(handles.dl_rate)];
                
                currMovie.protrusion.fileName = 'protrusion.mat';
                currMovie.protrusion.nfileName = 'normal_matrix.mat';
                currMovie.protrusion.status = 1;
            end
            
            updateMovieData(currMovie);

            if isfield(currMovie.protrusion, 'error')
                currMovie.protrusion = rmfield(currMovie.protrusion,'error');
            end            
            
        catch errMess
            disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);
            currMovie.protrusion.error = errMess;
            currMovie.protrusion.status = 0;
        end
    end

    %% STEP 4: Create windows
    
    windowString = [num2str(dContour) 'by' num2str(dWin) 'pix_' num2str(iStart) '_' num2str(iEnd)];

    if ~isfield(currMovie,'windows') || ~isfield(currMovie.windows,'status')  || ...
            currMovie.windows.status ~= 1 || forceRun(4)
        try
            currMovie = setupMovieData(currMovie);

            disp(['Get windows of movie ' num2str(iMovie) ' of ' num2str(nMovies) '...']);
            currMovie = getMovieWindows(currMovie,winMethod,dWin,[],iStart,iEnd,[],[],...
                ['windows_' winMethod '_' windowString '.mat'], batchMode);
            
            if isfield(currMovie.windows,'error')
                currMovie.windows = rmfield(currMovie.windows,'error');
            end

        catch errMess
            disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);
            currMovie.windows.error = errMess;
            currMovie.windows.status = 0;
        end
    end
    
    %% STEP 5: Sample the protrusion vector in each window

    if ~isfield(currMovie,'protrusion') || ~isfield(currMovie.protrusion,'samples') || ...
            ~isfield(currMovie.protrusion.samples,'status') || ...
            currMovie.protrusion.samples.status ~= 1 || forceRun(5)
        try
            disp(['Get sampled protrusion of movie ' num2str(iMovie) ' of ' num2str(nMovies) '...']);
            currMovie = getMovieProtrusionSamples(currMovie,['protSamples_' ...
                winMethod '_' windowString  '.mat'], 10, 100, batchMode);
            
            if isfield(currMovie.protrusion.samples,'error')
               currMovie.protrusion.samples = rmfield(currMovie.protrusion.samples,'error');
           end
            
        catch errMess
            disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);           
            currMovie.protrusion.samples.error = errMess;
            currMovie.protrusion.samples.status = 0;
        end
        
    end 

    %% STEP 6: Split the windows into different files.

    if ~isfield(currMovie, 'windows') || ~isfield(currMovie.windows, 'splitted') || ...
            currMovie.windows.splitted ~= 1 || forceRun(6)
        splitWindowFrames(currMovie, [currMovie.analysisDirectory filesep 'windows'], batchMode);
        currMovie.windows.splitted = 1;
    end    
    
    %% STEP 7: Sample protrusion.
    if ~isfield(currMovie,'protrusion') || ~isfield(currMovie.protrusion,'samples') || ...
            ~isfield(currMovie.protrusion.samples,'status') || ...
            currMovie.protrusion.samples.status ~= 1 || forceRun(7)
        try
            disp(['Sampling protrusion in movie ' num2str(iMovie) ' of ' num2str(nMovies)]);
            currMovie = getMovieProtrusionSamples(currMovie,['protSamples_' ...
                winMethod '_' windowString  '.mat'],10,100, batchMode);
            
            if isfield(currMovie.protrusion.samples,'error')
               currMovie.protrusion.samples = rmfield(currMovie.protrusion.samples,'error');
           end
            
        catch errMess
            disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);           
            currMovie.protrusion.samples.error = errMess;
            currMovie.protrusion.samples.status = 0;
            continue;
        end
        
    end 
    
    %% STEP 8: Create the window labels.

    if ~isfield(currMovie, 'labels') || ~isfield(currMovie.labels, 'status') || ...
            currMovie.labels.status ~= 1 || forceRun(8)
        try
            currMovie = setupMovieData(currMovie);

            disp(['Get labels of movie ' num2str(iMovie) ' of ' num2str(nMovies) '...']);
            
            currMovie = getMovieLabels(currMovie, batchMode);

            if isfield(currMovie.labels,'error')
                currMovie.labels = rmfield(currMovie.labels,'error');
            end

        catch errMess
           disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);
           currMovie.labels.error = errMess;
           currMovie.labels.status = 0;
        end
    end

    %% STEP 9: FA Segmentation
    
    if ~isfield(currMovie, 'segmentation') || ~isfield(currMovie.segmentation, 'status') || ...
            currMovie.segmentation.status ~= 1 || forceRun(9)
        try
            currMovie = setupMovieData(currMovie);
            
            disp(['Get segmentation of movie ' num2str(iMovie) ' of ' num2str(nMovies) '...']);
            
            currMovie = getMovieSegmentation(currMovie, batchMode);
            
            if isfield(currMovie.segmentation, 'error')
                currMovie.segmentation = rmfield(currMovie.segmentation, 'error');
            end

        catch errMess
            disp([movieName ': ' errMess.stack(1).name ':' num2str(errMess.stack(1).line) ' : ' errMess.message]);
            currMovie.segmentation.error = errMess;
            currMovie.segmentation.status = 0;
        end            
    end 
    
    %% Save results
    try
        %Save the updated movie data
        updateMovieData(currMovie)
    catch errMess
        errordlg(['Problem saving movie data in movie ' num2str(iMov) ': ' errMess.message], mfileName());
    end
    
    movieData{iMovie} = currMovie;
    
    if exist('h', 'var') && ishandle(h)
        close(h);
    end
    
    disp([movieName ': DONE']);
end

end