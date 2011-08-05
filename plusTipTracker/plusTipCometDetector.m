function [movieInfo]=plusTipCometDetector(projData,timeRange,bitDepth,savePlots,scales, multFactor4Thresh)
% plusTipCometDetector locates plus tip comets (or other blobs) in a movie stack
%
%SYNOPSIS [movieInfo]=plusTipCometDetector(projData,timeRange,bitDepth,savePlots)%
%INPUT  projData           : structure containing fields .anDir, which gives
%                           the full path to the roi_x directory
%                           and .imDir, which gives the full path to the
%                           folder containing the images for overlay.
%                           if given as [], program will query user for
%                           roi_x directory.
%       timeRange         : row vector of the form [startFrame endFrame]
%                           indicating time range to plot. if not given or
%                           given as [], tracks from the whole movie will
%                           be displayed.
%       bitDepth          : bit depth of the images - should be 12, 14, or 16
%       savePlots         : 1 to save overlay plots of detection results,
%                           0 if not
%       scales            : [low high] std for diff of Gaussians (opt)
%
%OUTPUT movieInfo         : nFrames-structure containing x/y coordinates
%       stdList           : nFrames-vector containing the standard
%                           deviation of the difference of Gauss-filtered
%                           images corresponding to each frame. this is
%                           based on either the user-selected ROI (if
%                           provided) or a region estimated to be within the
%                           cell from the background point (if ROI wasn't
%                           provided). both the ROI and bg point are saved
%                           during setupRoiDirectories.m

warningState = warning;
warning('off','MATLAB:divideByZero')

%%%%%% OPTIONS TO CHANGE MANUALLY%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
removeSatPixels = 0; % put one if you want to turn on this option
troubleShoot = 0; % put 1 if you would like detection to generate filterDiff
% images etc

%Filter Parameters
sigma1 = 1; % set by resolution of the microscope, the larger the number
% the more high spatial frequencies EXCLUDED from image.
sigma2  = 4; % smaller numbers result in MORE background subtraction (ie
% more low spatial frequencies are being considered background and
% subtracted from the sigma1 filtered image).
% NOTE: Larger differences between sigma1 and sigma2 result in a larger
% number of spatial frequencies preserved after filtering.

%Thresh Parameters
threshMultFactor = 3;
multFactor4StepSize = 1;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% CHECK INPUT AND SET UP DIRECTORIES

% get projData in correct format
if nargin<1 || isempty(projData)
    % if not given as input, ask user for ROI directory
    % assume images directory is at same level
    projData.anDir=uigetdir(pwd,'Please select ROI directory');
    homeDir=pwd;
    cd(projData.anDir);
    cd('..');
    projData.imDir=[pwd filesep 'images'];
    cd(homeDir)
else
    if ~isfield(projData,'imDir') || ~isfield(projData,'anDir')
        error('--plusTipCometDetector: first argument should be a structure with fields imDir and anDir');
    end
end

% Get list of Images in Image Directory and count them.
%NOTE: LIST OF IMAGES WILL BE
% IN ORDER FOUND IN DIRECTORY! DOES NOT YET SORT TIF FILES BY NUMBER!
[listOfImages] = searchFiles('.tif',[],projData.imDir,0);
nImTot = size(listOfImages,1);
%listOfImages =cellfun(@(x) strrep(x,' ','_'),listOfImages,'uniformoutput',0);
%listOfImages =cellfun(@(x) strrep(x,'tif.tif','tif'),listOfImages,'uniformoutput',0);

%Sort Images: Image sorting is required for image names where the number
% is not padded by zeros. Here we quickly sort images by number.
% If the numbers of the image namer are padded, use listOfImages.

imageName1 = [char(listOfImages(1,2)) filesep char(listOfImages(1,1))];

[path body no ext ] = getFilenameBody(imageName1);

if length(no)>1
    padded = 1;
else
    padded = 0;
end

if padded == 0
    %Initialize Cells for Sorting
    %path = path of file, body = body of filename, ex/home/mb228/orchestra/groups/lccb-comet/Pellman/Mijung/7-28-10_EB_for_Maria/EB1_4_Cropped/roi_2t = extension of filename
    %(tif etc) (all of these require a cell because they are strings)
    % num = number of filename (do not want in cell so can sort)
    pathCell = cell(nImTot,1);
    bodyCell = cell(nImTot,1);
    extCell = cell(nImTot,1);
    num = zeros(nImTot,1);
    
    %Sort List
    % For each frame get the image name from listOfImages
    for iFrame =  1:nImTot;
        imageName = [char(listOfImages(iFrame,2)) filesep char(listOfImages(iFrame,1))];
        
        %Call "getFilenameBody" from common dir to split filename into path,
        %body, no, and ext. Put path, body and ext into appropriate cell/number vector for that
        %frame
        [path body no ext ] = getFilenameBody(imageName);
        
        
        pathCell(iFrame) = cellstr(path);
        bodyCell(iFrame) = cellstr(body);
        extCell(iFrame) = cellstr(ext);
        
        % output "no" is a string so convert to number to sort
        num(iFrame)  = str2double(no);
        
    end
    %Sort number vector numerically
    sortednum = sort(num);
    
    %Convert number vector to cell
    sortednum_cell = num2cell(sortednum);
    
    %Create Sorted Image List
    sortedImages = [pathCell, bodyCell, sortednum_cell, extCell];
else
end


% check timeRange input, assign start and end frame
if nargin<2 || isempty(timeRange)
    startFrame = 1;
    endFrame = nImTot;
elseif isequal(unique(size(timeRange)),[1 2])
    if timeRange(1)<=timeRange(2) && timeRange(2)<=nImTot
        startFrame = timeRange(1);
        endFrame = timeRange(2);
    else
        startFrame = 1;
        endFrame = nImTot;
    end
    
else
    error('--plusTipCometDetector: timeRange should be [startFrame endFrame] or [] for all frames')
end

nFrames = endFrame-startFrame+1;

% Get image dimensions, max intensity from first image
% If image filename padded use listOfImages
if padded == 1;
    fileNameIm = [char(listOfImages(1,2)) filesep char(listOfImages(1,1))];
else % use sortedImages
    fileNameIm = [char(sortedImages(1,1)) filesep char(sortedImages(1,2)),...;
        num2str(sortednum(1)) char(sortedImages(1,4))];
end

img = double(imread(fileNameIm));
[imL,imW] = size(img);
maxIntensity = max(img(:));

% get bit depth if not given
if nargin < 3 || isempty(bitDepth)
    imgData = imfinfo(fileNameIm);
    bitDepth = imgData.BitDepth;
    disp(['bitDepth estimated to be' bitDepth])
end

% check bit depth to make sure it is 12, 14, or 16 and that its dynamic
% range is not greater than the provided bitDepth
if sum(bitDepth==[12 14 16])~=1 || maxIntensity > 2^bitDepth-1
    error('--plusTipCometDetector: bit depth should be 12, 14, or 16');
end

% check input for savePlots
if nargin<4 || isempty(savePlots)
    savePlots = 1;
end

% check input for sigma values of gaussians
if nargin<5 || isempty(scales)
    scales=[sigma1 sigma2];
end

% check input for multiple factor
if nargin<6 || isempty(multFactor4Thresh)
    multFactor4Thresh = threshMultFactor;
end

% make feat directory if it doesn't exist from batch
featDir = [projData.anDir filesep 'feat'];
if isdir(featDir)
    rmdir(featDir,'s')
end
mkdir(featDir)
mkdir([featDir filesep 'filterDiff']);

if savePlots==1
    mkdir([featDir filesep 'overlayImages']);
    mkdir([featDir filesep 'overlayImages' filesep 'tifs']);
    mkdir([featDir filesep 'filterDiff' filesep 'tifs']);
end


% look for region of interest info from project setup step
if ~exist([projData.anDir filesep 'roiMask.tif'],'file')...
        && ~exist([projData.anDir filesep 'masks'],'dir');
    % not roi selected; use the whole image
    roiMask = ones(imL,imW);
    roiYX=[1 1; imL 1; imL imW; 1 imW; 1 1];
    multMasks = 0;
else
    %if there exists a folder called masks in the current roi dir
    if exist([projData.anDir filesep 'masks'],'dir');
        % set the mask to the mask of image 1 (first mask in list)
        roiMask = double(imread([projData.anDir filesep 'masks' filesep 'roiMask1.tif']));
        % tell the program that there is a mask for each image
        % so it will know to update it when going through the detection
        multMasks = 1;
        
    else % only one mask to load, load it here
        roiMask = double(imread([projData.anDir filesep 'roiMask.tif']));
        multMasks = 0;
    end % if exist
    
    % load roi edge pixels
    roiYX=load([projData.anDir filesep 'roiYX']);
    roiYX=roiYX.roiYX;
    
    % for some reason the donut mask will open not as 1 and 0s but as
    % 255 (an 8 bit image) and 0s, Check for this and correct so the donut mask will
    % run through detection (added MB 09/2010)
    if isempty(find(roiMask==1,1))
        roiMask(roiMask==255) = 1;
    else % keep the same
    end % isempty
    
end % if ~exist

% string for number of files
s1 = length(num2str(endFrame));
strg1 = sprintf('%%.%dd',s1);


%% START DETECTION

% initialize structure to store info for tracking
[movieInfo(1:nImTot,1).xCoord] = deal([]);
[movieInfo(1:nImTot,1).yCoord] = deal([]);
[movieInfo(1:nImTot,1).amp] = deal([]);
[movieInfo(1:nImTot,1).int] = deal([]);
[movieInfo(1:nImTot,1).ecc] = deal([]);

%If thresh different than default ask user if they would like to continue
%forString = 'Multiplication Factor for Thresh is Set at ';
%forString2 = num2str(multFactor4Thresh);
%forString3 = ' Do You Want To Continue?';
%qstring = [forString forString2 forString3];
%if multFactor4Thresh ~= 3
%reply = questdlg(qstring);
%else
%   reply = 'yes';
%end

%if strcmpi(reply,'yes')

% get difference of Gaussians image for each frame and standard deviation
% of the cell background, stored in stdList
stdList=nan(nImTot,1);
count=1;
progressText(0,'Filtering images for comet detection');

for iFrame = startFrame:endFrame
    
    progressText(count/nFrames,'Filtering images for comet detection');
    
    % load image and normalize to 0-1
    
    if padded == 1;% If image filename padded use listOfImages
        fileNameIm = [char(listOfImages(iFrame,2)) filesep char(listOfImages(iFrame,1))];
    else % use sortedImages
        fileNameIm = [char(sortedImages(iFrame,1)) filesep char(sortedImages(iFrame,2)),...;
            num2str(sortednum(iFrame)) char(sortedImages(iFrame,4))];
    end
    
    
    img = double(imread(fileNameIm))./((2^bitDepth)-1);
    
    
    if removeSatPixels == 1
        img(img==1)= 0;
    else
    end
    
    % if there is a mask for each image file
    if multMasks == 1 && iFrame > 1
        % load new mask
        maskFilename = ['roiMask' num2str(iFrame) '.tif'];
        roiMask = double(imread([projData.anDir filesep 'masks' filesep maskFilename]));
    else
    end
    
    if isempty(find(roiMask==1,1))
        roiMask(roiMask==255) = 1;
    else % keep the same
    end % isempty
    
    % create kernels for gauss filtering
    blurKernelLow  = fspecial('gaussian', 21, scales(1));
    blurKernelHigh = fspecial('gaussian', 21, scales(2));
    
    % use subfunction that calls imfilter to take care of edge effects
    lowPass = filterRegion(img,roiMask,blurKernelLow); %
    highPass = filterRegion(img,roiMask,blurKernelHigh);
    
    % get difference of gaussians image
    filterDiff = lowPass-highPass;
    
    % if bg point was chosen and saved, get bgMask from first frame
    if iFrame==startFrame && exist([projData.anDir filesep 'bgPtYX.mat'])~=0
        bgPtYX=load([projData.anDir filesep 'bgPtYX.mat']);
        bgPtYX=bgPtYX.bgPtYX;
        [bgMask saveFig]=eb3BgMask(filterDiff,bgPtYX);
        print(saveFig,'-dtiff',[featDir filesep 'filterDiff' filesep 'bgMask.tif']);
        close(saveFig)
    end
    
    % if bg point wasn't chosen, use ROI
    if  exist([projData.anDir filesep 'bgPtYX.mat'])==0
        bgMask=logical(roiMask); %Note: not sure why she has logical here (it doesn't change anything as far as I can tell)
    end
    
    
    stdList(iFrame)=std(filterDiff(bgMask)); % (just removing not a numbers here from filterDiff so can take std)
    
    indxStr1 = sprintf(strg1,iFrame);
    save([featDir filesep 'filterDiff' filesep 'filterDiff' indxStr1],'filterDiff')
    save([featDir filesep 'stdList'],'stdList')
    
    count=count+1;
end

save([featDir filesep 'multFactor4Thresh'],'multFactor4Thresh')
save([featDir filesep 'multFactor4StepSize'],'multFactor4StepSize');
save([featDir filesep 'scales'],'scales');
% loop thru frames and detect
count=1;
progressText(0,'Detecting comets');
for iFrame = startFrame:endFrame
    
    progressText(count/nFrames,'Detecting comets');
    
    if iFrame==startFrame
        tic
    end
    
    indxStr1 = sprintf(strg1,iFrame);
    filterDiff=load([featDir filesep 'filterDiff' filesep 'filterDiff' indxStr1]);
    filterDiff=filterDiff.filterDiff;
    
    % thickness of intensity slices is average std from filterDiffs over
    % from one frame before to one frame after
    if iFrame==startFrame
        sF=iFrame;
    else
        sF=iFrame-1;
    end
    if iFrame==endFrame
        eF=iFrame;
    else
        eF=iFrame+1;
    end
    stepSize=multFactor4StepSize*mean(stdList(sF:eF));
    thresh= multFactor4Thresh*mean(stdList(sF:eF));
    
    
    
    
    % we assume each step size down the intensity profile should be on
    % the order of the size of the background std; here we find how many
    % steps we need and what their spacing should be. we also assume peaks
    % should be taller than 3*std
    nSteps = round((nanmax(filterDiff(:))-thresh)/(stepSize));
    threshList = linspace(nanmax(filterDiff(:)),thresh,nSteps);
    
    % compare features in z-slices startest from the highest one
    for p = 1:length(threshList)-1
        
        % slice1 is top slice; slice2 is next slice down
        % here we generate BW masks of slices
        if p==1
            slice1 = filterDiff>threshList(p);
        else
            slice1 = slice2;
        end
        slice2 = filterDiff>threshList(p+1);
        
        % now we label them using the "bwlabel" function from matlab which
        % labels connected components in a 2-D binary image
        featMap1 = bwlabel(slice1);
        featMap2 = bwlabel(slice2);
        
        % get the regionproperty 'PixelIdxList' using "regionprops" function in matlab
        featProp2 = regionprops(featMap2,'PixelIdxList');
        
        % loop thru slice2 features and replace them if there are 2 or
        % more features from slice1 that contribute
        for iFeat = 1:max(featMap2(:))
            pixIdx = featProp2(iFeat,1).PixelIdxList; % pixel indices from slice2
            featIdx = unique(featMap1(pixIdx)); % feature indices from slice1 using same pixels
            featIdx(featIdx==0) = []; % 0's shouldn't count since not feature
            if length(featIdx)>1 % if two or more features contribute...
                slice2(pixIdx) = slice1(pixIdx); % replace slice2 pixels with slice1 values
            end
        end
        
    end
    
    % label slice2 again and get region properties
    featMap2 = bwlabel(slice2);
    featProp2 = regionprops(featMap2,'PixelIdxList','Area');
    
    % here we sort through features and retain only the "good" ones
    % we assume the good features have area > 2 pixels
    goodFeatIdx = find(vertcat(featProp2(:,1).Area)>2);
    %    goodFeatIdxI = find(vertcat(featProp2(:,1).MaxIntensity)>2*cutOffValueInitInt);
    %    goodFeatIdx = intersect(goodFeatIdxA,goodFeatIdxI);
    
    % make new label matrix and get props
    featureMap = zeros(imL,imW);
    featureMap(vertcat(featProp2(goodFeatIdx,1).PixelIdxList)) = 1;
    [featMapFinal,nFeats] = bwlabel(featureMap);
    
    verDate=version('-date');
    if str2double(verDate(end-3:end))>=2008
        featPropFinal = regionprops(featMapFinal,filterDiff,'PixelIdxList','Area','WeightedCentroid','MaxIntensity','Eccentricity'); %'Extrema'
    else
        featPropFinal = regionprops(featMapFinal,'PixelIdxList','Area','Centroid');
        for iFeat=1:length(featPropFinal)
            featPropFinal(iFeat,1).WeightedCentroid=featPropFinal(iFeat,1).Centroid; % centroid's close enough...
            featPropFinal(iFeat,1).MaxIntensity=max(filterDiff(featPropFinal(iFeat,1).PixelIdxList)); % find maximum intensity
        end
    end
    
    if nFeats==0
        yCoord = [];
        xCoord = [];
        amp = [];
        featI = [];
        featE = [];
        
    else
        % centroid coordinates with 0.5 uncertainties for Khuloud's tracker
        yCoord = 0.5*ones(nFeats,2);
        xCoord = 0.5*ones(nFeats,2);
        temp = vertcat(featPropFinal.WeightedCentroid);
        yCoord(:,1) = temp(:,2);
        xCoord(:,1) = temp(:,1);
        
        % area
        featArea = vertcat(featPropFinal(:,1).Area);
        amp = zeros(nFeats,2);
        amp(:,1) = featArea;
        
        % intensity
        featInt = vertcat(featPropFinal(:,1).MaxIntensity);
        featI = zeros(nFeats,2);
        featI(:,1) = featInt;
        
        verDate=version('-date');
        
        if str2double(verDate(end-3:end))>=2008 % can only calculate eccentricity
            % if using version of matlab older than 2008
            
            %eccentricity
            featEcc = vertcat(featPropFinal(:,1).Eccentricity);
            featE = zeros(nFeats,2);
            featE(:,1) = featEcc;
            
        end
    end
    
    % make structure compatible with Khuloud's tracker
    movieInfo(iFrame,1).xCoord = xCoord;
    movieInfo(iFrame,1).yCoord = yCoord;
    movieInfo(iFrame,1).amp = amp;
    movieInfo(iFrame,1).int = featI;
    movieInfo(iFrame,1).ecc = featE;
    
    
    indxStr1 = sprintf(strg1,iFrame); % frame
    
    %plot feat outlines and centroid on image
    if savePlots==1
        
        if padded == 1;% If image filename padded use listOfImages
            fileNameIm = [char(listOfImages(iFrame,2)) filesep char(listOfImages(iFrame,1))];
        else % use sortedImages
            fileNameIm = [char(sortedImages(iFrame,1)) filesep char(sortedImages(iFrame,2)),...;
                num2str(sortednum(iFrame)), char(sortedImages(iFrame,4))];
        end
        %imgpn = double(imread(fileNameIm));
        img = double(imread(fileNameIm))./((2^bitDepth)-1);
        saveFig=figure('Visible','off');
        %clims = [0.01,0.5];
        imagesc(img)
        hold on
        scatter(xCoord(:,1),yCoord(:,1),'c.'); % plot centroid in cyan
        colormap gray
        plot(roiYX(2),roiYX(1),'w')
        axis equal
        print(saveFig,'-dtiff',[featDir filesep 'overlayImages' filesep 'tifs' filesep 'overlay' indxStr1 '.tif']);
        set(saveFig,'Visible','on'); % So that the fig is saved in visible state
        saveas(saveFig,[featDir filesep 'overlayImages' filesep 'overlay' indxStr1 '.fig']);
        close(saveFig)
        
        if troubleShoot == 1
            saveFig = figure('Visible','off');
            imagesc(filterDiff)
            %clims = [0.01,0.5]
            colormap gray
            hold on
            scatter(xCoord(:,1),yCoord(:,1),'g.'); % plot centroid in green
            plot(roiYX(2),roiYX(1),'w')
            axis equal
            colorbar ;
            print(saveFig,'-dtiff',[featDir filesep 'filterDiff' filesep 'tifs' filesep 'filterDiff' indxStr1 '.tif']);
            set(saveFig,'Visible','on'); % So that the fig is saved in visible state
            saveas(saveFig,[featDir filesep 'filterDiff' filesep 'filterDiff' indxStr1 '.fig']);
            close(saveFig)
            
            
            if iFrame == startFrame || iFrame == endFrame
                forTitle = ['Thresh = ', num2str(thresh)];
                saveFig = figure('Visible','off');
                surf(filterDiff)
                colormap;
                view(2)
                set(gca,'YDir','reverse');
                title(forTitle)
                set(saveFig,'Visible','on'); % So that the fig is saved in visible state
                saveas(saveFig,[featDir filesep 'filterDiff' filesep 'surf' indxStr1 '.fig']);
                close(saveFig)
            else
            end
        else
        end
    end
    
    count=count+1;
    
    
end
save([featDir filesep 'movieInfo'],'movieInfo');

%rmdir([featDir filesep 'filterDiff'],'s');

warning(warningState);


function filteredIm = filterRegion(im, mask, kernel)

im(mask~=1) = 0;
filteredIm = imfilter(im, kernel);
W = imfilter(double(mask), kernel);
filteredIm = filteredIm ./ W;
filteredIm(~mask) = nan;


function [bgMask saveFig]=eb3BgMask(filterDiff,bgPtYX)

% local max detection
fImg=locmax2d(filterDiff,[20 20],1);

% get indices of local maxima
idx=find(fImg);
[r c]=find(fImg);

% calculate percentiles of max intensities to use for rough idea of cell
% region
p1=prctile(fImg(idx),80);
p2=prctile(fImg(idx),90);

% get indices of those maxima within the percentile range ("good" features)
goodIdx=find(fImg(idx)>p1 & fImg(idx)<p2);

% get indices for nearest fifty points to user-selected point
D=createDistanceMatrix([bgPtYX(1) bgPtYX(2)],[r(goodIdx) c(goodIdx)]);
[sD,closeIdx]=sort(D);
closeIdx=closeIdx(1:min(50,length(closeIdx)));

% get convex hull and create ROI from that
K = convhull(c(goodIdx(closeIdx)),r(goodIdx(closeIdx)));
[bgMask,xi,yi]=roipoly(fImg,c(goodIdx(closeIdx(K))),r(goodIdx(closeIdx(K))));


saveFig = figure
imagesc(filterDiff);
colormap gray;
axis equal
hold on
scatter(bgPtYX(2),bgPtYX(1),'*y') % user-selected point
scatter(c(goodIdx),r(goodIdx),'.g') % all "good" features in green
scatter(c(goodIdx(closeIdx)),r(goodIdx(closeIdx)),'r') % nearest fifty to point in red
plot(xi,yi) % plot mask outline in blue