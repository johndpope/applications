
function [ output_args ] = GCAAnalysisExtractFilopodiaMeasurementsMovie(movieData,varargin)
%GCAAnalysisExtractFilopodiaParamsMovie
%   This function makes the default filopodia filter sets and extracts all
%   default filopodia parameters
%% INPUT
%
%   movieData - The MovieData object describing the movie, as created using
%   movieSelectorGUI.m
%
%   Parameter Structure Field Names:
%
% Generic Fields: (Input/Output Fields Needed for Wrapper)
%       ('OutputDirectory' -> Optional. A character
%       string specifying the directory to save the filopodia measurements to.
%       If not input, the output will be saved in the same directory
%       as the movieData, in a sub-directory called
%       'GrowthConeAnalyzer' filesep 'GCAMeasurementExtraction' filesep
%       'WholeNeurite'  
%
%       ('ChannelIndex'-> Positive integer scalar or vector) The integer
%       indices of the channel(s) on which to perform the filopodia
%       reconstruct
%       This index corresponds to the channel's location in the array
%       movieData.channels_. If not input, all channels will be analyzed
%
%       ('ProcessIndex' -> Positive integer scalar or vector)
%       This parameter specifies the output process to use for performing the
%       estimation
%       This allows a previously processed image (ie shade corrected or
%       background subtracted to potentially be input). If not input, the
%       backbone information will be calculated from the channels (ie raw
%       images)
%% Check input

% for now check movieData separately.
if nargin < 1 || ~isa(movieData,'MovieData')
    error('The first input must be a valid MovieData object!')
end
%%Input check
ip = inputParser;

ip.CaseSensitive = false;

% PARAMETERS

% defaultOutDir = [movieData.outputDirectory_ filesep 'MEASUREMENT_EXTRACTION']; 
      
ip.addParameter('InputDirectory',[],@(x) ischar(x)); 
ip.addParameter('OutputDirectory',[],@(x) ischar(x));

ip.addParameter('SubRegionInDir',[],@(x) ischar(x)); 
ip.addParameter('SubRegionOutDir',[],@(x) ischar(x)); 

ip.addParameter('SubRegionFlag',false,@(x) islogical(x)); 
ip.addParameter('SubRegionName',[],@(x) ischar(x) || isempty(x)); 

ip.addParameter('ChannelIndex',1);
ip.addParameter('ProcessIndex',0);
ip.addParameter('Rewrite',false); 

ip.parse(varargin{:});
p = ip.Results;

%% set up directories 



if isempty(ip.Results.InputDirectory)
    if ip.Results.SubRegionFlag
        if isempty(ip.Results.SubRegionInDir)
            inDir = [movieData.outputDirectory_ filesep 'SegmentationPackage' ...
                  filesep 'GCASubRegions' filesep 'GC' filesep 'filopodia'];
        else
            inDir = ip.Results.SubRegionInDir;
        end % ip.Results.Subregions
    else
        inDir = [movieData.outputDirectory_ filesep 'SegmentationPackage' ...
            filesep 'StepsToReconstruct' filesep ...
            'VII_filopodiaBranch_fits' filesep 'Channel_1'];
    end % if ip.Results.SubRegions
else
    inDir = ip.Results.InputDirectory ;
end

if isempty(ip.Results.OutputDirectory)
    if ip.Results.SubRegionFlag
        if ~isempty(ip.Results.SubRegionName)
            outDir = [movieData.outputDirectory_ filesep 'GCAMeasurementExtraction' filesep  ip.Results.SubRegionName];
        else
            [~,subRoiRegionName] = upDirectory(inDir,3);
            [~,subRoiRegionName2] = upDirectory(inDir,2); 
            outDir = [movieData.outputDirectory_ filesep 'GCAMeasurementExtraction' filesep subRoiRegionName filesep subRoiRegionName2];
        end
    else
        outDir = [movieData.outputDirectory_ filesep...
            'GCAMeasurementExtraction' filesep 'WholeNeurite' ];
    end
else
    outDir = ip.Results.OutputDirectory;
end


% defaultOutDir = [movieData.outputDirectory_ filesep...
%    'GCAMeasurementExtraction' filesep 'WholeNeurite' ];

%% Init:
nFrames = movieData.nFrames_;
nChan = numel(p.ChannelIndex);
channels = p.ChannelIndex;


%% Loop for each channel
for iCh = 1:nChan
    
    %% Load the segmenatation analysis
    display('Please Be Patient This File Takes a While to Load...');
    %load([movieData.outputDirectory_ filesep 'filopodia_fits' filesep 'Filopodia_Fits_Channel_' num2str(channels(iCh)) filesep 'analInfoTestSave.mat']);
    load([inDir filesep 'filoBranch.mat'])
    
    display('Finished Loading'); 
    
    % Check to make sure everything run completely eventually will just look at
    % the movieData process.
    for iFrame = 1:numel(filoBranch) -1
        filoInfo = filoBranch(iFrame).filoInfo;
        % arrayfun(@(x)
        % test if the field associated with endpoint coordinate is empty
        % 1 if missing fits 0 if not
        missingFits(iFrame,1)= sum(arrayfun(@(x) isempty(x.Ext_endpointCoordFitPix),filoInfo));
    end

%% Start formatting analInput (SubRegional analInput first)

if ip.Results.SubRegionFlag
    analInput(1).filterType = 'ConnectToVeil_LengthInt'; 
    analInput(1).paramFunc{1} = 'filoLength'; 
    analInput(1).paramName{1} = 'filoLengthToVeil'; 
    analInput(1).paramInput{1} = 'Ext_'; 
    
    analInput(1).paramFunc{2} = 'filoLength';
    analInput(1).paramName{2} = 'filoLengthEmbedded';
    analInput(1).paramInput{2} = 'Int_';
    
     % Total Length Actin Bundle
    analInput(1).paramFunc{3} = 'filoLength';
    analInput(1).paramName{3} = 'filoLengthFullActinBundle';
    analInput(1).paramInput{3} = 'Tot';
    
     % Intensity To Veil
    analInput(1).paramFunc{4} = 'filoAvgIntensity'; % function ID
    analInput(1).paramName{4} = 'filoIntensityToVeil'; % paramName for output
    analInput(1).paramInput{4} = 'Ext'; % other information for function
    
    % Intensity Embed
    analInput(1).paramFunc{5} = 'filoAvgIntensity';
    analInput(1).paramName{5} = 'filoIntensityEmbedded';
    analInput(1).paramInput{5}  = 'Int';
    
    analInput(2).filterType = 'ConnectToVeil_DensityOrient';
    
    % Orientation
    analInput(2).paramFunc{1} = 'filoOrient';
    analInput(2).paramName{1} = 'filoOrient';
    analInput(2).paramInput{1} = [];
    
    % Curvature
    analInput(2).paramFunc{2} = 'filoCurvature';
    analInput(2).paramName{2} = 'filoCurvature';
    analInput(2).paramInput{2} = [];
    
    
else
    %% Whole Neurite Measurements
    %% Filter I 'ConnectToVeil_LengthInt' : Veil Measurements that require good fitting (Length and Intensity)  
    
        % Filopodia/Branch Length (0 and 1st Order) : Note should probably 
        % separate to make Actin bundle lengths verus 1st order branches 
        analInput(1).filterType =   'ConnectToVeil_LengthInt';
        analInput(1).paramFunc{1} = 'filoLength'; % % function ID
        analInput(1).paramName{1} = 'filoLengthToVeil'; % paramName-
        x.filoPart = 'Ext_';
        x.outPercent = false;

        analInput(1).paramInput{1} = x; 

        % Veil Embedded Actin Bundle (Life-Act Only) : Length 
        analInput(1).paramFunc{2} = 'filoLength';
        analInput(1).paramName{2} = 'filoLengthEmbedded';
        x.filoPart = 'Int_'; 
        x.outPercent = false; 
        analInput(1).paramInput{2} = x;

        % Full Actin Bundle (Life-Act Only) : Length 
        analInput(1).paramFunc{3} = 'filoLength';
        analInput(1).paramName{3} = 'filoLengthFullActinBundle';
        x.filoPart = 'Tot'; 
        x.outPercent = false; 
        analInput(1).paramInput{3} = x ;

        % Actin Bundle to Veil : Intensity 
        analInput(1).paramFunc{4} = 'filoAvgIntensity'; % function ID
        analInput(1).paramName{4} = 'filoIntensityToVeil'; % paramName for output
        analInput(1).paramInput{4} = 'Ext'; % other information for function

        % Veil Embedded Actin Bundle 
        analInput(1).paramFunc{5} = 'filoAvgIntensity';
        analInput(1).paramName{5} = 'filoIntensityEmbedded';
        analInput(1).paramInput{5}  = 'Int';

        % Percentage of total Actin Bundles Embedded 
        analInput(1).paramFunc{6} = 'percentOfActinBundlesVeilEmbedded'; % % function ID
        analInput(1).paramName{6} = 'percentTotalActinBundlesVeilEmbedded'; % paramName-    
        analInput(1).paramInput{6} = [];

        % Percentage of Each Actin Bundle Embedded
        analInput(1).paramFunc{7} = 'filoLength';
        analInput(1).paramName{7} = 'percentEachActinBundleEmbed';
        x.filoPart = 'Tot';
        x.outPercent = true; 
        analInput(1).paramInput{7} = x;
   
    %% Filter II: 'ConnectToVeil_DensityOrient':   Density Filo Veil: Measurements that do not require accurate fitting.
        analInput(2).filterType = 'ConnectToVeil_DensityOrient';

        % Density of Filopodia 
        analInput(2).paramFunc{1} = 'filoDensityAlongVeil';
        analInput(2).paramName{1} = 'filoDensityAlongVeil';

        load([movieData.outputDirectory_ filesep 'SegmentationPackage' filesep ...
            'StepsToReconstruct' filesep 'III_veilStem_reconstruction' filesep 'Channel_1'...
            filesep 'veilStem.mat']);
        analInput(2).paramInput{1} = veilStem ;

        % Orientation of Filopodia 
        analInput(2).paramFunc{2} = 'filoOrient';
        analInput(2).paramName{2} = 'filoOrientation';
        analInput(2).paramInput{2} = [];

        % Curvature of Filopodia 
        analInput(2).paramFunc{3} = 'filoCurvature';
        analInput(2).paramName{3} = 'filoMaxCurvature';
        analInput(2).paramInput{3} = [];
   %% Filter III: 'Branch2ndOrder_LengthInt'   
    
       % Length/Int 2nd Order Filo/Branches
       % Note my definitions are 0 filo attached to veil no branch
       % 1 filo attached to veil with a branch
       % 2 branch attached to filo type 1
       analInput(3).filterType = 'Branch2ndOrder_LengthInt';

       analInput(3).paramFunc{1} = 'filoOrient';
       analInput(3).paramName{1} = 'branchOrientation_2ndOrder';
       analInput(3).paramInput{1} = [];

       analInput(3).paramFunc{2} = 'filoLength';
       analInput(3).paramName{2} = 'branchLength_2ndOrder';
       x.filoPart = 'Ext_';
       x.outPercent = false; 
       analInput(3).paramInput{2} = x;
       %analInput(3).paramInput{2} = 'Ext_';

       analInput(3).paramFunc{3} = 'filoCurvature';
       analInput(3).paramName{3} = 'branchMaxCurvature_2ndOrder';
       analInput(3).paramInput{3} = [];

       analInput(3).paramFunc{4} = 'filoAvgIntensity';
       analInput(3).paramName{4} = 'branchIntensity_2ndOrder';
       analInput(3).paramInput{4} = 'Ext';
   
   %%  Filter IV: 'Branch2ndOrder_Density_NoZero'
       analInput(4).filterType = 'Branch2ndOrder_Density_NoZero';
       analInput(4).paramFunc{1} = 'distanceToBranch';
       analInput(4).paramName{1} = 'branchDistanceFromVeil'  ;
       analInput(4).paramInput{1} = [];

       analInput(4).paramFunc{2} =  'filoDensityAlongBranch';
       analInput(4).paramName{2} = 'branchDensity_2ndOrder';
       analInput(4).paramInput{2} = [];
   
end
%% Wrap through for each analysis type
for iAnalType = 1:length(analInput);
    
    newFiloDir = [outDir filesep 'Descriptor'...
        filesep 'Filopodia' filesep analInput(iAnalType).filterType ];
    % check for the filter directory
    if exist([newFiloDir filesep 'filoFilterSet.mat'])
        display([newFiloDir filesep 'filoFilterSet.mat Found']);
        
        % overwrite filter only if user specifies
        if ip.Results.Rewrite == true
            display(['Overwriting ' newFiloDir]);
            rmdir(newFiloDir,'s')
            mkdir(newFiloDir);
            % get the filopodia filter for analInput
            [filoFilterSet,filterParams] = GCACreateFilopodiaFilterSetWithEmbedResidTest(filoBranch,analInput(iAnalType).filterType); 
            %[filoFilterSet,filterParams] = GCACreateFilopodiaFilterSetWithEmbed(filoBranch,analInput(iAnalType).filterType);
            % save the filter set used
            save([newFiloDir filesep 'filoFilterSet.mat'],'filoFilterSet','filterParams');
        else % load the file
            load([newFiloDir filesep 'filoFilterSet.mat']);
            % eventually check the filter so that know that it is from the same analysis 
            
        end % ip.Results.Rewrite
        
    else % make the new directory and make the filter
        mkdir(newFiloDir);
        [filoFilterSet,filterParams] = GCACreateFilopodiaFilterSetWithEmbedResidTest(filoBranch,analInput(iAnalType).filterType); 
        %[filoFilterSet,filterParams] = GCACreateFilopodiaFilterSetWithEmbed(filoBranch,analInput(iAnalType).filterType);
        % save the filter set used
        filterParams.InputDirectory = inDir; 
        save([newFiloDir filesep 'filoFilterSet.mat'],'filoFilterSet','filterParams');
    end
    
    
    % perform the various assocatied parameter extraction by calling the
    % associated function
    nParams  = numel(analInput(iAnalType).paramFunc);
    
    for iParamExtract = 1:nParams
        run = true;
        % Make the output directory: Each extraction has its own folder for now so have a place to
            % save associated plots and movies- will collect in a later
            % step (the movies can take a while to run... ) 
            
        nameParam = ['meas_'  analInput(iAnalType).paramName{iParamExtract}];
        analOutputDir = [newFiloDir filesep  analInput(iAnalType).paramFunc{iParamExtract}];
        
        % check for the .measC file and overwrite if necessary
        if exist([analOutputDir filesep nameParam '.mat' ])
            display([analOutputDir filesep nameParam '.mat file found']);
            if ip.Results.Rewrite
                display(['Overwriting ' analOutputDir filesep nameParam '.mat']);  %give the user some feedback
            else
                run = false; % don't run
                display(['Skipping: ' nameParam]);
            end
        else % need to make the directory
            if ~isdir(analOutputDir)
                mkdir(analOutputDir)
            end
        end
        
        if run
            % check for the measC file
            
            % Call the extraction function : all of these extraction functions have names starting with
            % GCAAnalysisExtract_ '
            % some are very short however I found it useful to keep each
            % extraction as a separate function- all output will be a cell of
            % iFrames holding the distribution of values
            % for that parameter
            paramFuncC = str2func(['GCAAnalysisExtract_' analInput(iAnalType).paramFunc{iParamExtract}]);
            inputC =  analInput(iAnalType).paramInput{iParamExtract};
            
            if ~isempty(inputC)
                measC =  paramFuncC(filoBranch,filoFilterSet, inputC);
            else
                measC = paramFuncC(filoBranch,filoFilterSet);
            end
                     
            timeStamp = clock;
            save([analOutputDir filesep nameParam '.mat' ],'measC','timeStamp','inDir');
            
        end  % if run
    end % iParamExtract % iterate over all params using the same filter set
    
    
end % iAnal % iterate over all analysis groups with the same filter set

%     else % some of the fits have not been run
%         startProblemFrame = find(missingFits);
%         display(['Fits for ' movieData.outputDirectory_ 'were not fully run (starting at frame '  num2str(startProblemFrame) ...
%             ' ): SKIPPING ' ]);        
%     end % sum missing
end  % for iCh
end









