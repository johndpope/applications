function [nuclei,movieInfo,Pix]=cellDICDetect(imageFileList,outerR,innerR,closeR,sigmaGauss,edgeFilter,minSize,sigmaCanny)
%read in Stack of images:
if nargin < 1 || isempty(imageFileList)
   [filename, pathname] = uigetfile({'*.TIF';'*.tif';'*.jpg';'*.png';'*.*'}, ...
       'Select First Phase Contrast Image');
   
   if ~ischar(filename) || ~ischar(pathname)
       return;
   end
   
   imageFileList = getFileStackNames([pathname filesep filename]);
else
    isValid = 1;
    for frame = 1:numel(imageFileList)
        isValid = isValid && exist(imageFileList{frame}, 'file');
    end
    if ~isValid
        error('Invalid input files.');
    end
end

if nargin<2 || isempty(outerR)
    outerR=10; %10
end

if nargin<3 || isempty(innerR)
    innerR=9;  %9
end

if nargin<4 || isempty(closeR)
    closeR=8; %8
end

if nargin<5 || isempty(sigmaGauss)
    sigmaGauss=2; %2
end

% These values are only needed if the segmentation is used (which is not by
% default)

if nargin < 6 || isempty(edgeFilter)
    edgeFilter='sobel';
elseif ~strcmp(edgeFilter,'sobel') && ~strcmp(edgeFilter,'canny') && ~strcmp(edgeFilter,'prewitt') && ~strcmp(edgeFilter,'none')
    display('This filter is not supported');
    return;
end

if nargin< 7 || isempty(minSize)
    minSize=300;
end

% This is only used for the canny filter:
if nargin < 8 || isempty(sigmaCanny)
    sigmaCanny=2;
end

doBoth=1;
doPlot=0;

% All image files need to be precessed. If the cell sheet fills up the
% whole field of view (or some other problem occurs), then, this list is
% shortened:
toDoList=1:length(imageFileList);

for frame=toDoList
    text=['Detect sheet edges in ',num2str(toDoList(end)),' images'];
    progressText(frame/toDoList(end),text);
    
    currImage=double(imread(imageFileList{frame}));    
    [rowsOrg, colsOrg]=size(currImage);
    
    %**********************************************************************
    % 1.Step: crop non-zero part of the image                             *
    %**********************************************************************
    % Crop an inner part of the image, the boundary might contain zero
    % pixels. The following lines find the largest rectangle with non-zero
    % values that fits into the image (with equal spacing to the bundary).
    realIm=(currImage~=0);
    bwBD=bwboundaries(realIm,8,'noholes');
    % one should first finde the maximum, anyways:
    bwBD=bwBD{1};
    
    if doPlot==1
        figure, imshow(currImage,[]), title('Gradient magnitude (gradmag)')
        colormap gray;
        hold on
        plot(bwBD(:,2),bwBD(:,1),'*b')
        hold off;
    end
    
    distVals=[bwBD(:,1),bwBD(:,2),rowsOrg-bwBD(:,1),colsOrg-bwBD(:,2)];
    Pix(frame)=max(min(distVals,[],2));
    
    Icrop =currImage((1+Pix(frame)):(rowsOrg-Pix(frame)),(1+Pix(frame)):(colsOrg-Pix(frame)));
    I=Icrop;
    
    if nargin > 5 || doBoth
        %**********************************************************************
        % Use Segmentation to track the cells. This is done if nargin>5       *
        %**********************************************************************
        
        % calculate the gradient information in the image:
        if strcmp(edgeFilter,'sobel') || strcmp(edgeFilter,'prewitt')
            hy = fspecial(edgeFilter); %'prewitt' % perform very much the same!
            hx = hy';
            Iy = imfilter(double(I), hy, 'replicate');
            Ix = imfilter(double(I), hx, 'replicate');
            gradmag = sqrt(Ix.^2 + Iy.^2);
        elseif strcmp(edgeFilter,'canny')
            [gradmag] = steerableFiltering(I,1,sigmaCanny);
        elseif strcmp(edgeFilter,'none')
            gradmag=zeros(size(I));
        end
        
        if doPlot==1
            figure, imshow(gradmag,[]), title('Gradient magnitude')
            colormap gray;
        end
        
        se   = strel('disk', closeR);
        Gc = imclose(gradmag,se);
        if doPlot==1
            figure, imshow(Gc,[]), title('Gradient image closed')
            colormap gray;
        end
        
        % segment the image:
        % maskBlobs =blobSegmentThresholdGeneral(Gc,'rosin',1,1,minSize,doPlot,'my');
        % maskBlobs =blobSegmentThresholdGeneral(Gc,'minmax',1,1,minSize,doPlot,'my');
        % maskBlobs =blobSegmentThresholdGeneral(gradmag,'minmax',1,1,minSize,doPlot,'my');
        maskBlobs =blobSegmentThresholdGeneral(Gc,'rosin',1,1,minSize,doPlot,'my');
        
        
        % Now we have the candidate clusters. Some of which will contain
        % several cells that we now want to tell apart.
        CCsegm       = bwconncomp(maskBlobs);
        centoidsSegm = regionprops(CCsegm, 'centroid');
        nucPosSegm   = round(vertcat(centoidsSegm(:).Centroid));
        
    end
    if nargin<=5 || doBoth
        %**********************************************************************
        % Use tricky filters to track the cells. This is done if nargin<=5    *
        %**********************************************************************
        
        hDonut=donutFilter(outerR,innerR);
        Idonut=imfilter(I,hDonut);
        if doPlot==1
            figure, imshow(Idonut,[]), title('Donut filter applied')
            colormap gray;
        end
        
        % Close the inner holes in the center of the donuts:
        se   = strel('disk', closeR);
        IDc = imclose(Idonut,se);
        if doPlot==1
            figure, imshow(IDc,[]), title('Closed donut filtered image')
            colormap gray;
        end
        
        IDcg=filterGauss2D(IDc,sigmaGauss);
        if doPlot==1
            figure, imshow(IDcg,[]), title('Gauss filtered, closed, donut filtered image')
            colormap gray;
        end
        
        se   = strel('disk', closeR);
        Imax = locmax2d(IDcg, se.getnhood, 1);
        
        if doPlot==1
            figure, imshow(Imax,[]), title('Show ALL local maxima')
            colormap gray;
        end
        
        % cut off the maxima in the noise (this is unstable):
        % [~, level1]=cutFirstHistMode(Imax(Imax(:)>0),0);
        % level1=thresholdFluorescenceImage(Imax(Imax(:)>0),1);
        
        % This might be more stable. First find the BG-value (max in the
        % intensity histogram):
        numBins=round(sqrt(numel(IDcg)));
        [counts,bin]=hist(IDcg(:),numBins);
        [~,maxID]=max(counts);
        % Then the BG-value is about:
        bgVal=bin(maxID);
        % The typical maximum value is at ~0.95% value of the prob. dist:
        pVal=0.95;
        cumProb=cumsum(counts);
        upperPercentile=find(cumProb/cumProb(end)>pVal,1);
        avSig=bin(upperPercentile);
        % set the cut off in the middle of signal and noise.
        level2=bgVal+(avSig-bgVal)*0.5;
        
        
        if doPlot==1
            countsPlot=hist(Imax(Imax(:)>0),100);
            figure; hist(Imax(Imax(:)>0),100);
            hold on
            % plot([level1 level1],[0 max(countsPlot)],'-r')
            plot([level2 level2],[0 max(countsPlot)],'-g')
            hold off
        end
        
        % take level2 to cut off:
        Imax(Imax(:)<level2)=0;
        Imax(Imax(:)>0)=1;
        
        % Show the first set of maxima:
        se   = strel('disk', 4);
        ImaxDil = imdilate(Imax,se);
        %if doPlot==1
        Idspl=Icrop;
        Idspl(ImaxDil == 1) = 0;
        figure(1), imagesc(Idspl), title(['Show only filtered local maxima, frame= ',num2str(frame)])
        hold on
        %end
        
        CCfltr       = bwconncomp(Imax);
        centoidsfltr = regionprops(CCfltr, 'centroid');
        nucPosfltr   = round(vertcat(centoidsfltr(:).Centroid));
    end
    
    if doBoth && ~isempty(nucPosSegm)
        %**********************************************************************
        % Combine the two results                                             *
        %**********************************************************************
        
        % the filter usually yields the better results for the cluster but the
        % segmentation works more reliable on the few crawling faint (since
        % huge lamella) cells. Find the cells from the segmentation that have
        % no corresponding partner in the filter results and add only those:
        
        c2cDist=createDistanceMatrix(nucPosfltr,nucPosSegm);
        % the minimal distance to any fltr cell:
        minDist=min(c2cDist);
        
        % find the cells that are far of:
        goodId= minDist>3*outerR;
        
        % append those to the new nucPosfltr:
        nucPosfltr=vertcat(nucPosfltr,nucPosSegm(goodId,:));
        
        plot(nucPosSegm(goodId,1),nucPosSegm(goodId,2),'or');
    end
    hold off
    %**********************************************************************
    % Step: Prepare the output                                            *
    %**********************************************************************
    
    try 
        nuclei(frame).pos=nucPosfltr+Pix(frame);
    catch
        nuclei(frame).pos=nucPosSegm+Pix(frame);
    end           
    
    nuclei(frame).img=false(size(currImage));    
    linId=sub2ind(size(currImage),nuclei(frame).pos(:,2),nuclei(frame).pos(:,1));
    nuclei(frame).img(linId)=true;
    
    movieInfo(frame).xCoord(:,1)=nuclei(frame).pos(:,1);
    movieInfo(frame).xCoord(:,2)=outerR/2;
    movieInfo(frame).yCoord(:,1)=nuclei(frame).pos(:,2);
    movieInfo(frame).yCoord(:,2)=outerR/2;
    movieInfo(frame).amp(:,1)=currImage(linId);
    movieInfo(frame).amp(:,2)=0;    
end

save('xCellDetect.mat','movieInfo','toDoList','outerR','innerR','closeR','sigmaGauss','edgeFilter','minSize','sigmaCanny','-v7.3');

% Track the cells:
[tracksFinal]=scriptTrackNuclei(movieInfo,outerR,1.5*outerR,pwd);
close all

% Make a movie of the tracks overlaid to the analyzed images:
overlayTracksMovieNew(tracksFinal,[],10,1,'xCellMovie',[],1,0,0,[],0,1,[],0,0,imageFileList,[],[],1)

% sort out good tracks (defined by minimal track length), convert to simple
% x-y-coordinate matrix, calculate velocities:
minTrackLength=6;
timeWindow=6;
display('Filter tracks for minimal track length:...')
[tracksMatxCord,tracksMatyCord,velMatxCord,velMatyCord,velMatMag]=conv2CordMatVelMat(tracksFinal,[],minTrackLength,timeWindow,toDoList);
display(['Calculated velocities are averaged over: ',num2str(timeWindow),' frames!'])
display('done!')
figure;
[counts,bins]=hist(velMatMag(:)/timeWindow,0.5:10.5);
totCounts=sum(counts);
countsNorm=counts/totCounts;
bar(bins,countsNorm,'style','hist')
title('Velocity probablity distribution')
xlabel(['cell velocity [pix/frame] averaged over ',num2str(timeWindow,'%.0f'),' frames']);
ylabel('probablity')
saveas(gcf,['cell_velocity_hist','.eps'],'psc2');

return;
%This is for fusing histograms of two conditions:
counts1=countsNorm; counts1_200=countsNorm;
counts2=countsNorm; counts2_200=countsNorm; 

countsTot=horzcat(counts1(:),counts2(:))
countsTot=horzcat(counts1_200(:),counts2_200(:));
bar(bins,countsTot,2)
title('Comparison of velocity probablity distribution')
xlabel(['cell velocity [pix/frame] averaged over ',num2str(timeWindow,'%.0f'),' frames']);
ylabel('probablity')
set(gca,'XTick',0:10)
XLim([0 10])
saveas(gcf,['cell_velocity_hist_comp','.eps'],'psc2');
saveas(gcf,['cell_velocity_hist_comp','.fig'],'fig');

velMatMagDrg_200=velMatMag(:)/timeWindow;
velMatMagDrg    =velMatMag(:)/timeWindow;

velMatMagCtr_200=velMatMag(:)/timeWindow;
velMatMagCtr    =velMatMag(:)/timeWindow;

