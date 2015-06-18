function [filoBranch,TSFigsFinal] = GCAReconstructFilopodia(img,veilStemMaskC,varargin)
% GCAReconstructFilopodia: (Step VI of GCA PACKAGE)
% This function rebuilds and records the filopodia network around a
% veil/stem mask (in the case of the neurite) or any binary cell mask 
% where small scale (often low fidelity) protrusion detections have been 
% removed. 
% 
% STEP I: It applies a small scale steerable ridge filter followed 
%         by NMS (non-maximum suppression) to detect filopodia. 
%         It then reconstructs the filopodia network from this 
% 
%% INPUT: REQUIRED AND OPTIONAL
%
%   img: (REQUIRED) : RxC double array
%      of image to analyze where R is the height (ny) and C is the width
%     (nx) of the input image
%
%  veilStemMaskC: (REQUIRED)  RxC logical array (binary mask)
%      of veil/stem reconstruction where R is the height (ny) and C is the width
%      (nx) of the  original input image
%
%  protrusionC: (OPTIONAL) : structure with fields:
%    .normals: a rx2 double of array of unit normal
%      vectors along edge: where r is the number of
%      coordinates along the veil/stem edge
%
%    .smoothedEdge: a rx2 double array of edge coordinates
%       after spline parameterization:
%       where r is the number of coordinates along the veil/stem edge
%      (see output: output.pixel_tm1_output in prSamProtrusion)
%     Default : [] , NOTE: if empty the field
%                    filoInfo(xFilo).orientation for all filodpodia attached
%                    to veil will be set to NaN (not calculated)- there will be a warning if
%                    to the user if this is the case
%    Output from the protrusion process (see getMovieProtrusion.m)
%
%% PARAMS
%    
% %% PARAMS: STEERABLE FILTER: RIDGE FINDING %%
%
%    'FiloScale' (PARAM) : Positive scalar or vector
%        Sigmas (standard deviation of the Gaussian kernel) to use for
%        the steerable filter estimation of the small-scale ridges. Note if a vector
%        is specified, responses for all scales are calculated and the
%        scale with the largest steerable filter
%        response at each point is chosen for the final backbone estimation.
%        Default: [1.5] (in pixels)
%        See gcaMultiscaleSteerableDetector.m
%
%    'FilterOrderFilo' (PARAM) : Scalar 2 or 4
%        4 provides better orientation selectivity than 2
%        and is less sensitive to noise, at a small trade-off in
%        computational cost. 
%        Default: 4
%        See gcaMultiscaleSteerableDetector.m
%
%
% %% PARAMS: RIDGE CLEANING %% 
%
%    'multSTDNMSResponse': (PARAM) Scalar   
%         
%    'minCCRidgeOutsideVeil' : Scalar (Default 3 Pixels)
%
%
% %% PARAMS: RIDGE LINKING %%  
%
%    % FILO CANDIDATE BUILDING %
%      'maxRadiusLink' (PARAM) : Scalar 
%         Maximum radius for connecting linear endpoints points of two 
%         filopodia candidates in the initial candidate building step of the 
%         algorithm.
%         Default: 5
%         See gcaAttachFilopodiaStructuresMain.m 
%
%    % TRADITIONAL FILO/BRANCH LINKING %
%      'maxRadiusLinkFiloOutsideVeil' (PARAM): Scalar  
%         Maximum radius for connecting endpoints of candidate filopodia ridges 
%         to the current iteration of the  high confidence seed. 
%         Default : 
% 
% 
%    % EMBEDDED ACTIN SIGNAL LINKING %
%      'maxRadiusLinkEmbedded' (PARAM) : Scalar 
%          Only embedded ridge candidate end points that are within this max 
%          search radius around each seed ridge endpoint are considered for matching.
%          Default: 10 Pixels
%          (Only applicable if 'detectEmbedded' set to 'true')
%          See: gcaAttachFilopodiaStructuresMain.m 
%                   gcaReconstructEmbedded.m 
%                       gcaConnectEmbeddedRidgeCandidates.m 
%
%      'geoThreshEmbedded' (PARAM) : Scalar 
%          Only embedded ridge candidates meeting this geometric criteria
%          will be considered. 
%          Default: 0.9 
%          (Only applicable if 'detectEmbedded' set to 'true')
%          See: gcaAttachFilopodiaStructuresMain.m 
%                   gcaReconstructEmbedded.m 
%                       gcaConnectEmbeddedRidgeCandidates.m 
%
%% OUTPUT: 
% adds a field to filoBranch. called filoInfo
% filoInfo is a R structure x 1 structure with fields providing information
% regarding each "filopodia" (ie independent ridge segment): where R is the
% number of filopodia segments reconstructed in iFrame.  
% Currently 'filopodia' can be 
% IDed into select branch groups. 
% groups via the field groupCount. 
% (My version notes addition : Nested fields were avoided here to facilitate the data
% extraction in later steps (ie each filopodia was given an field ID 
% specifying branch order rather than nesting the structure)

%% Input Parser 
ip = inputParser;

ip.CaseSensitive = false;
ip.KeepUnmatched = true;

ip.addRequired('img');
ip.addRequired('veilStemMaskC');

%OPTIONAL
ip.addOptional('protrusionC',[],@(x) iscell(x)); % if restarting


% PARAMS: STEERABLE FILTER: RIDGE FINDING
% Pass to gcaMultiscaleSteerableDetector.m
ip.addParameter('FilterOrderFilo',4,@(x) ismember(x,[2,4]));
ip.addParameter('FiloScale',1.5);

% RIDGE CLEANING
ip.addParameter('multSTDNMSResponse',3);
ip.addParameter('minCCRidgeOutsideVeil',3);

% CANDIDATE BUILDING %
% Pass to: gcaAttachFilopodiaStructuresMain.m
ip.addParameter('maxRadiusLink',5); 
ip.addParameter('geoThresh',0.9, @(x) isscalar(x));  

% TRADITIONAL FILOPODIA/BRANCH RECONSTRUCT           
% Pass to: gcaAttachFilopodiaStructuresMain.m
ip.addParameter('maxRadiusConnectFiloBranch',5); 


% EMBEDDED ACTIN SIGNAL LINKING %
ip.addParameter('detectEmbedded',true)
% Pass to: gcaAttachFilopodiaStructuresMain.m
  ip.addParameter('maxRadiusLinkEmbedded',10); 
  ip.addParameter('geoThreshEmbedded',0.9,@(x) isscalar(x)); 
   ip.addParameter('curvBreakCandEmbed',0.05,@(x) isscalar(x)); 
% TROUBLE SHOOT FLAG 
ip.addParameter('TSOverlays',true);

ip.parse(img,veilStemMaskC,varargin{:});
p = ip.Results;
p = rmfield(p,{'img','veilStemMaskC','protrusionC'}); 
%% Initiate 
countFigs = 1; 

%% STEP I: Detect Thin Ridge Structures 
    
[maxRes, maxTh ,maxNMS ,scaleMap]= gcaMultiscaleSteerableDetector(img,ip.Results.FilterOrderFilo,ip.Results.FiloScale); 

% (NOTE: MB, possibly make this output verbose only?) 
filoBranchC.filterInfo.maxTh = maxTh;
filoBranchC.filterInfo.maxRes = maxRes;
filoBranchC.filterInfo.scaleMap = scaleMap; 

%% STEP II :  PREPARE HIGH CONFIDENCE RIDGE 'SEEDS' FOR SUBSEQUANT ITERATIVE MATCHING STEPS
%% Estimate the background of the image based on intensity (permissive definition) and 
% delete small ridge filter signal from these regions in order to not waste
% energy on unimportant regions. 

[maskBack,~,~] = gcaEstimateBackgroundArea(img); 

%% Take out the first gaussian mode of ridge response intensities (assume it is background) 
    % Determine Threshold
    forValues = maxNMS.*~maskBack; % take out background response based on fluorescence intensity
    valuesFilter = forValues(forValues~=0);  
    [respNMSMean,respNMSSTD]   = fitGaussianModeToPDF(valuesFilter); 
    cutoffTrueResponse = respNMSMean+ip.Results.multSTDNMSResponse*respNMSSTD; % can make this a variable 
    n1 = hist(valuesFilter,100);
    
    % Filter NMS based on Threshold: This will form the basis for your
    % candidate ridges
    canRidges = maxNMS.*~maskBack;
    canRidges(canRidges<cutoffTrueResponse) = 0; 
    filoBranchC.filterInfo.ThreshNMS = canRidges; 
    
    canRidges = bwmorph(canRidges,'thin',inf ); 
%% OPTIONAL TS PLOT : Show Histogram to see if cut-off reasonable given the distribution
        if ip.Results.TSOverlays == true % plot the histogram with cut-off overlay so can see what losing 
         
          TSFigs(countFigs).h = figure('visible','off'); 
       
          TSFigs(countFigs).name = 'SmallRidgeNMSThreshold'; 
           
          hist(valuesFilter,100); 
          hold on 
          line([cutoffTrueResponse cutoffTrueResponse],[0,max(n1)],'color','r','Linewidth',2); 
          title('Red line 3*std of first mode'); 
          countFigs = countFigs+1; % close figure 
        end
%% Eliminate Ridge Junctions
% Notes: ridge junctions are typically not reliably detected in the NMS and
% if they are (we should re-check the NMS code - it is debatable if they
% should exist at all)- it is often ambigious as to whether these are a
% cross-over, a branch-point, or noise. Therefore we break them here so we
% can appropriately assign these junction pixels to individual filopdodia in the
% subsequent matching steps.

% Initiate the cleaned array.
canRidgeClean =  canRidges; 

% Break the junctions
nn = padarrayXT(double(canRidgeClean~=0), [1 1]);
sumKernel = [1 1 1];
nn = conv2(sumKernel, sumKernel', nn, 'valid');
nn1 = (nn-1) .* (canRidgeClean~=0);
junctionMask = nn1>2;
canRidgeClean(junctionMask) =0;

%% Filter Small Size Connected Component Ridge Pieces
% typically keep this very small as do not want to remove signal 
% < 3 pixel connected components are just typically less 
% well suited to orientation measurements required in the next steps
CCRidges = bwconncomp(canRidgeClean,8); % FIRST PLACE WHERE I BEGIN TO FILTER out signal
csize = cellfun(@(c) numel(c), CCRidges.PixelIdxList);
nsmall = sum(csize<=ip.Results.minCCRidgeOutsideVeil);% 
CCRidges.NumObjects = CCRidges.NumObjects-nsmall;
CCRidges.PixelIdxList(csize<=ip.Results.minCCRidgeOutsideVeil) = []; % was 3 pixels

% MASK OF CLEANED RIDGES MINUS ALL JUNCTIONS
cleanedRidgesAll = labelmatrix(CCRidges)>0;
%% Optional TS Figure : Ridge Signal Cleaning Steps 
 if ip.Results.TSOverlays == true % plot the histogram with cut-off overlay so can see what losing 
         
          TSFigs(countFigs).h = figure('visible','on'); 
       
          TSFigs(countFigs).name = 'RidgeSignalCleaning'; 
          imshow(-img,[]) ; 
          hold on 
          spy(canRidges,'b'); 
          spy(cleanedRidgesAll,'r'); 
          text(5,5,'Ridges Before Cleaning','Color','b','FontSize',10);
          text(5,20,'Ridges After Cleaning', 'Color','r','FontSize',10); 
          countFigs = countFigs +1; 
 end 



%% Run Main Function that performs the reconstructions
[reconstruct,filoInfo,TSFigs2] = gcaAttachFilopodiaStructuresMainFixInput(img,cleanedRidgesAll,veilStemMaskC,filoBranchC,p);

TSFigsFinal = [TSFigs; TSFigs2]; 

filoBranch.filoInfo = filoInfo; % 
filoBranch.reconstructInfo = reconstruct;


end % 


        
        
        




