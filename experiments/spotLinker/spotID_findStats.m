function [sxyz, samp, deltamp,goodTime,centerOfMass,plotData]=spotID_findStats(spots,verbose,findGoodTime,saveFile,timeLapse,projName)
%spotID_findStats finds data statistics of spotlist spots for spotID
%
% SYNOPSIS  [sigma.xyz, sigma.amp, deltamp]=spotID_findStats(spots)
%
% INPUT spots : list of coordinates and amplitudes of spots generated by spotID
%
% OUTPUT sigma.xyz : std of difference in coordinates between spots of two consecutive frames
%        sigma.amp : std of difference in intensities between spots of two consecutive frames
%        deltamp   : mean decrease of amplitude between spots of two consecutive frames (increase possible, but unlikely)
%        goodTime  : vector of timepoints to keep
%        centerOfMass: mean of all spot coordinates
%        plotData  : struct containing figure handle and xData to plot intList
%
% DEPENDS ON distMat2
%
% CALLED BY spotID
%
% SUBFUNCTIONS distMatVectors
%   
% c: 23/09/02	Jonas

%-------------initialization


dxyz=[];
damp=[];
plotData=[];

for t=1:size(spots,2)
    ampList(t)=sum(spots(t).amp);
end
ampList=ampList';
goodRows=find(ampList);

%do fit anyway, but do not necessarily throw away bad frames


if length(goodRows)<size(spots,2)/10
    error(['only ',num2str(length(goodRows)),' good data points from spot detector (<10%) - deletion of current project recommended'])
end

%suppress maxFunEvalWarning
options = optimset('Display','off');

%linear fit (not scaled with real time) - discontinued
parameters.xdata=goodRows-1; %frame1=time0
parameters.ydata=ampList(goodRows);
uLin0=[parameters.xdata,ones(length(goodRows),1)]\ampList(goodRows);
[uLin,sigmaLMS,ssqLin]=leastMedianSquare('(ydata-(u(1)+u(2)*xdata)).^2',uLin0,options,parameters);

%exponential fit a*exp(-t/tau)
uExp0(1)=median(parameters.ydata(1:5)); %a0
uExp0(2)=median((parameters.xdata(end-5+[1:5])-parameters.xdata(1:5))./(log(parameters.ydata(1:5))-log(parameters.ydata(end-5+[1:5])))); %tau0
[uExp,sigmaExp,ssqExp]=leastMedianSquare('(ydata-(u(1)*exp(-xdata/u(2)))).^2',uExp0,options,parameters);
sigmaExp0=sqrt(sum((uExp0(1)*exp(-parameters.xdata/uExp0(2))-parameters.ydata).^2)/(length(parameters.xdata)-1));

% sliding window (uses the same starting values as exp fit)
% first estimate an exponential fit (done above). Then calculate a sliding
% window that goes from expFit-1*sigma via tangent point to exp fit to
% expFit-1*sigma. If the tangent is not lower than expFit-1*sigma at start
% (yExp1S) or end (yExpNS), we take the first or the last point as
% start/end for the window. Else we have to use fzero to calculate the ends

yExpi=uExp0(1)*exp(-parameters.xdata/uExp0(2)); %exponential init fit
yExpip=-uExp0(1)/uExp0(2)*exp(-parameters.xdata/uExp0(2)); % exponential init slope
yExp1S=uExp0(1)*exp(-parameters.xdata(1)/uExp0(2))-sigmaExp0; % xData does not necessarily start with 1!
yExpNS=uExp0(1)*exp(-parameters.xdata(end)/uExp0(2))-sigmaExp0;
tStart=zeros(size(parameters.xdata));
tStartT=zeros(size(parameters.xdata));
tEnd=zeros(size(parameters.xdata));
tEndT=zeros(size(parameters.xdata));



warning off MATLAB:fzero:UndeterminedSyntax
waitbarHandle=mywaitbar(0,[],length(parameters.xdata),'fitting intensities...');
try
    for ti=1:length(parameters.xdata)
        %find tStart
        if yExpi(ti)-(parameters.xdata(ti)-parameters.xdata(1))*yExpip(ti)<yExp1S % *0.95 %to make sure 
            tStartT(ti)=fzero(inline('uExp(1)*((-(t-ti)/uExp(2)+1)*exp(-ti/uExp(2))-exp(-t/uExp(2)))+sigmaExp','t','ti','uExp','sigmaExp'),...
                [parameters.xdata(1),parameters.xdata(ti)],options,parameters.xdata(ti),uExp0,sigmaExp0);
            [dummy,tStart(ti)]=min(abs(parameters.xdata-tStartT(ti)));
        else
            tStartT(ti)=parameters.xdata(1);
            tStart(ti)=1;
        end
        %find tEnd
        if yExpi(ti)+(parameters.xdata(end)-parameters.xdata(ti))*yExpip(ti)<yExpNS % *(1-sign(yExpNS)*0.05) %to make sure
            tEndT(ti)=fzero(inline('uExp(1)*((-(t-ti)/uExp(2)+1)*exp(-ti/uExp(2))-exp(-t/uExp(2)))+sigmaExp','t','ti','uExp','sigmaExp'),...
                [parameters.xdata(ti),parameters.xdata(end)],options,parameters.xdata(ti),uExp0,sigmaExp0);
            [dummy,tEnd(ti)]=min(abs(parameters.xdata-tEndT(ti)));
        else
            tEndT(ti)=parameters.xdata(end);
            tEnd(ti)=length(parameters.xdata);
        end
        uLin02(1)=yExpi(tStart(ti));
        uLin02(2)=yExpip(ti);
        parWindow.xdata=parameters.xdata(tStart(ti):tEnd(ti));
        parWindow.ydata=parameters.ydata(tStart(ti):tEnd(ti));
        [uLin2(ti,:),sigmaLMS2(ti,1)]=leastMedianSquare('(ydata-(u(1)+u(2)*xdata)).^2',uLin02,options,parWindow);
        mywaitbar(ti/length(parameters.xdata),waitbarHandle,length(parameters.xdata));
    end
catch
    if findstr(lasterr,['Error using ==> get',char(10),'Invalid handle'])
        error('evaluation canceled by user');
    else
        rethrow(lasterror) %or any other action to be executed on an error within the loop
    end
end
close(waitbarHandle);

%linear fit for sigma
uLin03(1)=sigmaLMS2(1);
uLin03(2)=(sigmaLMS2(end)-sigmaLMS2(1))/length(parameters.xdata);
parWindow.xdata=parameters.xdata;
parWindow.ydata=sigmaLMS2;
[uLin3,sigmaLMS3]=leastMedianSquare('(ydata-(u(1)+u(2)*xdata)).^2',uLin03,options,parWindow);
smSig=uLin3(1)+uLin3(2)*parameters.xdata;
%median of sigma
smSig2=median(sigmaLMS2)*ones(size(parameters.xdata));

raw=uLin2(:,1)+parameters.xdata.*uLin2(:,2);
sm1=raw;sm1(2:end-1)=sqrt(raw(1:end-2).*raw(3:end));
sm2=raw;
sm2(3:end-2)=sqrt(raw(1:end-4).*raw(5:end));
sm3=(raw.*sm1.*sm2).^(1/3);

%don't use time on axis; use frame number
if timeLapse==1.001 %no data properties, time not known
    xPlot=goodRows; %if timepoints are plotted, they should start with 1!
    timePerFrame='unknown';
else %time is known - still plot timepoints and not secs: you have to compare with labelgui
    xPlot=goodRows; %if timepoints are plotted, they should start with 1!
    timePerFrame=num2str(timeLapse);
    %xPlot=(parameters.xdata)*timeLapse;
end
if verbose>1|saveFile==1 %only draw figure if necessary
    %sigH=figure;plot(xPlot,sigmaLMS2,'-b',xPlot,smSig2,'-r');
    figH=figure;
    if ~isempty(projName)
        set(figH,'Name',projName);
    end
    plot(xPlot,ampList(goodRows),'.k',xPlot,raw,'-b',xPlot,raw+2.5*sigmaLMS2,'--b',xPlot,raw-2.5*sigmaLMS2,'--b',...
        xPlot,sm3,'-r',xPlot,sm3+2.5*smSig2,'--r',xPlot,sm3-2.5*smSig2,'--r');
    hold on
    plot(xPlot,uExp(1)*exp(-parameters.xdata/uExp(2)),'-m',...
        xPlot,uExp(1)*exp(-parameters.xdata/uExp(2))+2.5*sigmaExp,'--m',xPlot,uExp(1)*exp(-parameters.xdata/uExp(2))-2.5*sigmaExp,'--m');
    %plot(xPlot,uLin(2)*parameters.xdata+uLin(1),'-g',...
    %xPlot,uLin(2)*parameters.xdata+uLin(1)+2.5*sigmaLMS,'--g',xPlot,uLin(2)*parameters.xdata+uLin(1)-2.5*sigmaLMS,'--g');
    %title([num2str(uLin(2)),'*x+',num2str(uLin(1)),'; sigma=',num2str(sigmaLMS)]);
    title({['Exp. fit [per timestep]:    ',num2str(uExp(1)),'/',num2str(uExp(2)),'/',num2str(sigmaExp)];...
            ['         average timestep:  ',timePerFrame]});
    plotData.xData=xPlot;
    plotData.figH=figH;
    %plotData.sigH=sigH;
end

if findGoodTime
    %-------------throw away bad frames (large intensity drop)    
    goodGoodRows=goodRows(abs((ampList(goodRows)-sm3))<2.5*smSig2);
    goodTime=zeros(size(spots,2),1);
    goodTime(goodGoodRows)=1;
else
    goodTime=zeros(size(spots,2),1);
    goodTime(goodRows)=1;
end

%-------------find stats

t1=min(find(goodTime)); %number of frame 1 of 2
%calculate CoM for drift compensation
centerOfMass(t1,:)=mean(spots(t1).xyz,1);
for t2=t1+1:size(spots,2) %number of frame 2 of 2
    if goodTime(t2)
        
        centerOfMass(t2,:)=mean(spots(t2).xyz,1);
        deltaCoM=centerOfMass(t2,:)-centerOfMass(t1,:);
        %calculate distances
        dxyztmp=distMat2(spots(t1).xyz,spots(t2).xyz-ones(size(spots(t2).xyz,1),1)*deltaCoM);
        dxyz=[dxyz;dxyztmp(:)];
        damptmp=distMatVectors(spots(t1).amp,spots(t2).amp);
        damp=[damp;damptmp(:)];
        
        t1=t2;
    end
end

%prepare data for histograms
numberOfClassesXyz=1+log2(length(dxyz));
numberOfClassesAmp=1+log2(length(damp));
meanXyz=mean(dxyz)+eps; %becomes sigma.xyz, because there are only positive distances
meanAmp=mean(damp); %becomes deltamp (multiplied by 0.8, as linear fit usually was below mean(damp) )
sigmaXyz=std(dxyz);

% if ~findGoodTime
%     sigmaAmp=std(damp); %becomes sigma.amp
%     smSig2 = sigmaAmp;
% else
sigmaAmp=median(smSig2);
% end

%check if sigmas~=0 (can be a problem with synthetic data)
if sigmaXyz==0
    sigmaXyz=0.0001;
end
if sigmaAmp==0
    sigmaAmp=0.0001;
end


%----------------plot if option is selected

if verbose==1
    %% plot
    fig1=figure;
    subplot(1,2,1);
    hist(dxyz,numberOfClassesXyz);
    h = findobj(gca,'Type','patch');
    set(h,'FaceColor','g','EdgeColor','w')
    title(['XYZ meandiff, m=',num2str(meanXyz),', std=',num2str(sigmaXyz)]);
    
    subplot(1,2,2);
    histfit(damp,numberOfClassesAmp);
    h = findobj(gca,'Type','patch');
    set(h,'FaceColor','g','EdgeColor','w')
    title(['AMP meandiff, m=',num2str(meanAmp),', std=',num2str(sigmaAmp)]);
end

%----------------write output

sxyz=meanXyz;
samp=zeros(size(spots,2),1);
%make sure we do not get smSig2 == 0 below
samp(goodRows)=smSig2;
deltamp=zeros(size(spots,2),1);

% if findGoodTime
deltamp(goodRows(1:end-1))=sm3(2:end)-sm3(1:end-1);
% else
%     deltamp(goodRows(1:end-1)) = meanAmp;
% end

% test samp: if there are bad zeros: display warning
zeroSamp = find(samp(goodRows)==0);
if zeroSamp
    sprintf(['warning: sigmaAmp (samp) is zero %i times. Change to 1e-10'],length(zeroSamp))
    samp(goodRows(zeroSamp)) = 1e-10;
end
    
    
