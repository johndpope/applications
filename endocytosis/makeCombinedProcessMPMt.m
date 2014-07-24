function [children,parents,restrictions,genProc] = makeCombinedProcessMPMt(imagesize, numf, plotOn,varargin)
% make simulated MPM (with specified number of frames and imagesize) as a
% superposition of clustered and random processes
% INPUT:
% imagesize     image size, in format [sx,sy]
% numf          number of frames
% varargin      variable number of inputs; each input is a vector that
%               specifies a process; all vectors have the form
%               [ type   density    other descriptors ]
%               the individual descriptors are as follows
%       IF type = 1     random process
%                       density = point density per frame (this parameter
%                       is actually the lambda for the poisson distrubuted
%                       number of random events per frame)
%                       reshuffle = 1 if point density per frame is to be
%                       consevred given restrictions
%       IF type = 2     Cox cluster process (points are distributed
%                       with Gaussian intensity profile around parent)
%                       density = density of parent points per frame,
%                       additional descriptors for this process are
%                       lambda = average number of children per parent
%                       NOTE that child initiation around the parent is a
%                       Poisson process!!
%                       lag = time lag before parent can produce another
%                       child
%                       sigma = sigma of Gaussian distance distribution of
%                       children around parent
%                       sigmaDiff (optional) = sigma of random frame-to-
%                       frame displacement of parents (default =0)
%                       minParentDistance = minimum interparent distance
%                       (default = 0)
%                       reshuffle = 1 if point density per frame is to be
%                       consevred given restrictions
%       IF type = 3     Matern cluster process (points are distributed
%                       randomly in a disc around parent)
%                       other parameters: as in Cox cluster, sigma here is
%                       the radius of the disc
%       IF type = 4     inclusion process: the points generated by the
%                       processes above are restricted to the area INSIDE
%                       randomly distributed discs
%                       density = density of disc centers
%                       radius_raft = radius of discs
%                       percentRestrict = percent of points inside
%                       exclusion area that are restricted
%                       sigmaDiff = sigma of disc diffusion
%                       minParentDistance = minimum interparent distance
%                       (default = 0)...will not apply if restrictions are
%                       part of different populations
%       IF type = 5     exclusion process: the points generated by the
%                       processes above are restricted to the area OUTSIDE
%                       randomly distributed discs
%                       Parameters as for type=4
%
% Example:
% [mpm_total] = makeCombinedProcessMPMt([400 400], 300, [1 0.0002], [2 0.002 0.1 3 0.5]);
% creates a distribution that's a superposition of
% A: a random distribution with 0.0002*(400^2)=32 objects per frame, plus
% B: a Cox-clustered distribution with 320 parents, which move 0.5*randn pix
% per frame, where each parent has poissrnd(0.1) children, distributed with
% sigma=3 pix around the parent
%
% last modified: Dinah Loerke, July 1, 2009

%calculate simulation area
sx = imagesize(1);
sy = imagesize(2);
imarea = sx*sy;
% for simulating parent positions a larger area is used to avoid edge
% effects
sxLarge = sx+20;
syLarge = sy+20;
imareaLarge = sxLarge*syLarge;
% a buffer needs to be applied in order to match the positions in the small
% image to those on the larger image
buffer = (sxLarge-sx)/2;

%read process types
proc = arrayfun(@(x)varargin{x}(1),1:length(varargin));
% processes with numbers 1-3 are point-generating processes, whereas
% numbers 4-5 are point-restricting (or excluding) processes
pos_generate = find(proc<=3);
pos_restrict = find(proc>3);

%if no point generating processes specified...stop, there is nothing to
%simulate
if isempty(pos_generate)
    error('no point-generating processes specified');
end

%allocate space
children = [];

%% INTERPRET INPUTS FOR POINT GENERATING PROCESSES
% loop over all point-generating processes
genProc = repmat(struct('type',[],'intensity',[],'reshuffle',...
    [],'radius',[],'timeLag',[],'percentRestrict',[],'numChild',[],...
    'diffusion',[],'minDistance',[],'lifetime',[]),1,length(pos_generate));
for iproc = 1:length(pos_generate)
    
    % current generating parameters
    cvec = varargin{pos_generate(iproc)};
    
    %first put in common entires for all processes
    % first position: distribution type
    genProc(iproc).type = cvec(1);
    % second position: intensity of the process (number of points or
    % parents
    genProc(iproc).intensity = cvec(2);
    % third value (optional) is determines whether point
    % density is to be conserved given restrictions
    if length(cvec) > 2
        genProc(iproc).reshuffle = cvec(3);
    else
        genProc(iproc).reshuffle = 0;
    end
    
    % fourth value (optional) is the restriction radius
    % after a nucleation has taken place
    if length(cvec) > 3
        genProc(iproc).radius = cvec(4);
    else
        genProc(iproc).radius = 0;
    end
    
    
    % fifth value is the time restriction imposed after
    % nucleation on furthe nucleations
    if length(cvec) > 4
        genProc(iproc).timeLag = cvec(5);
    else
        genProc(iproc).timeLag = 0;
    end
    
    % sixth value (optional) is the percent of points the area restricts
    if length(cvec)>5
        genProc(iproc).percentRestrict = cvec(6);
    else
        genProc(iproc).percentRestrict = 1;
    end
    
    % third value is number of daughters per mother
    if length(cvec)>6
        genProc(iproc).numChild = cvec(7);
    else
        genProc(iproc).numChild = 0;
    end
    % fifth value (optional) is sigma of parent diffusion (also
    % in pixel)
    if length(cvec)>7
        genProc(iproc).diffusion = cvec(8);
    else
        genProc(iproc).diffusion = 0;
    end
    
    if length(cvec)>8
        genProc(iproc).minDistance = cvec(9);
    else
        genProc(iproc).minDistance = 0;
    end
    
    %eight value (optional) maximum lifetime of parent, used to
    %simulate parent turnover
    if length(cvec)>9
        genProc(iproc).lifetime = cvec(10);
        % since a lifetime of zero makes no sense switch to and
        % infinite lifetime
        if  genProc(iproc).lifetime == 0
            genProc(iproc).lifetime = inf;
        end
    else
        genProc(iproc).lifetime = Inf;
    end
    
    if length(cvec)>10
        genProc(iproc).clusterRadius = cvec(11);
    else
        genProc(iproc).clusterRadius = 0;
    end
    
    if length(cvec)>11
        genProc(iproc).diffusionRadius = cvec(12);
    else
        genProc(iproc).diffusionRadius = 0;
    end
    
end

%% NOW LOOP OVER ALL RESTRICTING PROCESSES
%if any restriction processes are specified
if ~isempty(pos_restrict)
    % loop over all point-restricting processes
    for i=1:length(pos_restrict)
        % current generating parameters
        cvec = varargin{pos_restrict(i)};
        % first position: distribution type
        vi_type = cvec(1);
        % second position: intensity of the process (number of points or
        % parents
        vi_int = cvec(2);
        switch vi_type
            % distribution is raft-shaped inclusion or exclusion, i.e. a
            % restriction of previous data rather than added new data
            case {4,5}
                
                % third value is radius of disc (in pixel)
                radius_raft = cvec(3);
                
                % fourth value (optional) is the percent of points the area restricts
                if length(cvec)>3
                    percentRestrict = cvec(4);
                else
                    percentRestrict = 1;
                end
                
                % fifth value (optional) is sigma of raft diffusion (also
                % in pixel)
                if length(cvec)>4
                    sigma_diff = cvec(5);
                else
                    sigma_diff = 0;
                end
                
                % sixth value (optional) is the minimum distance between
                % the centroids of parent processes
                if length(cvec)>5
                    minDist = cvec(6);
                else
                    minDist = 0;
                end
                
                %generate mpm for point restricting process...that is, x
                %and y posiiton of each point restricting process
                %for each frame of the simulation
                %parents processes are simulated over a larger area to
                %avoid edge effects
                [mpm_restrict] = generateRestrictions(numf,[sxLarge syLarge],vi_int,minDist,sigma_diff,buffer);
                %NOTE: minDist will only apply for a single population of
                %processes; there will be no minDist between members of
                %different populations
                
                %how many restrictions do we have thus far?
                if exist('restrictions','var')
                    numRestrictions = length(restrictions);
                else
                    numRestrictions = 0;
                end
                %add values for each restriction created
                restrictions(numRestrictions+1:numRestrictions+size(mpm_restrict,1)) = ...
                    struct('radius',num2cell(repmat(radius_raft,size(mpm_restrict,1),1)),...
                    'percentRestrict',num2cell(repmat(percentRestrict,size(mpm_restrict,1),1)),...
                    'type',num2cell(repmat(vi_type,size(mpm_restrict,1),1)),...
                    'sigma_diff',num2cell(repmat(sigma_diff,size(mpm_restrict,1),1)),...
                    'minDist',num2cell(repmat(minDist,size(mpm_restrict,1),1)),...
                    'groupNumber',num2cell(repmat(i,size(mpm_restrict,1),1)),...
                    'xpos',num2cell(mpm_restrict(:,1:2:end),2),...
                    'ypos',num2cell(mpm_restrict(:,2:2:end),2));
                
                
            otherwise
                error('unknown process identification number');
        end % of case/switch
    end % of for i-loop
end %if restriction  process exists

%% POINT GENERATING PROCESSES
%now that we have simulted all point restricting processes for each frame,
%we go frame by frame into point generating processes and keep those points
%which are not restricted

%for every frame
for t=1:numf
    
    if t ~= 1 && exist('parents','var') && ~isempty(parents)
        %diffuse all parents for this frame
        % fill subsequent time positions
        %designate space
        %        mpmMothers = nan(length(parents),2);
        %get parent positions from last frame
        %NOTE: these are indexed in the following way for speed
        %get all parent xpositions
        mpmx = [parents.xpos];
        %get all parent y positions
        mpmy = [parents.ypos];
        %pick out x and y positions for all parents for the last frame
        %(hence the t-1) and put into one mpm
        %         mpm_mother_first = [mpmx(1:length(mpmx)/length(parents):end)' mpmy(1:length(mpmx)/length(parents):end)'];
        mpm_mother_prev = [mpmx(t-1:length(mpmx)/length(parents):end)' mpmy(t-1:length(mpmx)/length(parents):end)'];
        %         %find parents that are dead and take them out
        %         mpm_mother_prev = mpm_mother_prev([parents.currentParentLifetime] <= [parents.lifetime],:);
        %         mpm_mother_first = mpm_mother_first([parents.currentParentLifetime] <= [parents.lifetime],:);
        %         %diffuse parents
        %         mpm_generatedMothers = diffuseParentMPM(mpm_mother_prev,...
        %             [parents([parents.currentParentLifetime] <= [parents.lifetime]).diffusion]',...
        %             [parents([parents.currentParentLifetime] <= [parents.lifetime]).diffusionRadius]',...
        %             mpm_mother_first);
        %         %add these new positions back into mpm, which makes the
        %         %positions for dead parents NaNs
        %         mpmMothers([parents.currentParentLifetime] <= [parents.lifetime],:) = mpm_generatedMothers;
        %add these back unto parents structure array for
        %long-term storage
        for ipar = 1:length(parents)
            parents(ipar).xpos(t) = mpm_mother_prev(ipar,1);
            parents(ipar).ypos(t) = mpm_mother_prev(ipar,2);
            %update parent life count
            parents(ipar).currentParentLifetime = parents(ipar).currentParentLifetime+1;
        end
        %delete mpmMothers
        clear mpmMothers
        % redraw dead parents
        if any([parents.lifetime] ~= Inf)
            parents = redrawParentMPM(parents,[sxLarge syLarge],buffer,t);
        end
    end
    
    % loop over all point-generating processes
    for i=1:length(genProc)
        
        %get number of points and set parents if necessary
        switch genProc(i).type
            %random process
            case {1}
                nump = poissrnd(genProc(i).intensity * imarea);
                % distribution is cluster (of raft or Cox type)
            case { 2, 3}
                
                %if parent process we follow instead the number of parents
                %because this is the number we set instead of the child density
                % number of points is intensity times area
                nump = round(genProc(i).intensity * imareaLarge);
                
                % in the first frame, define the positions of the parent
                % points; in subsequent frames, re-use the original parent
                % positions or let them diffuse as specified
                % NOTE: to avoid edge effects, parent points have to be
                % simulated outside of the image, too
                if nump == 0
                    error('not enough parents in frame')
                    %initiate parents
                elseif t == 1
                    % initieate timer for lifetime of parent and for time
                    parentTimer = round(repmat([genProc(i).lifetime-1 numf-1],nump,1).*rand(nump,2))+1;
                    % initiate parent positions
                    mpm_generatedMothers = makeParentMPM(nump,[sxLarge syLarge],genProc(i).minDistance, buffer);
                    mpm_generatedMothers(1:size(mpm_generatedMothers,1),3:2*numf) = nan;
                    %how many restrictions do we have thus far?
                    if exist('parents','var')
                        numParents = length(parents);
                    else
                        numParents = 0;
                    end
                    %add values for each parent created
                    parents(1+numParents:size(mpm_generatedMothers,1)+numParents) = ...
                        struct('numChild',num2cell(repmat(genProc(i).numChild,size(mpm_generatedMothers,1),1)),...
                        'timeLag',num2cell(repmat(genProc(i).timeLag,size(mpm_generatedMothers,1),1)),...
                        'radius',num2cell(repmat(genProc(i).radius,size(mpm_generatedMothers,1),1)),...
                        'percentRestrict',num2cell(repmat(genProc(i).percentRestrict,size(mpm_generatedMothers,1),1)),...
                        'type',num2cell(repmat(genProc(i).type,size(mpm_generatedMothers,1),1)),...
                        'diffusion',num2cell(repmat(genProc(i).diffusion,size(mpm_generatedMothers,1),1)),...
                        'minDistance',num2cell(repmat(genProc(i).minDistance,size(mpm_generatedMothers,1),1)),...
                        'lifetime',num2cell(repmat(genProc(i).lifetime,size(mpm_generatedMothers,1),1)),...
                        'clusterRadius',num2cell(repmat(genProc(i).clusterRadius,size(mpm_generatedMothers,1),1)),...
                        'diffusionRadius',num2cell(repmat(genProc(i).diffusionRadius,size(mpm_generatedMothers,1),1)),...
                        'currentParentLifetime',num2cell(parentTimer(:,1)),...
                        'currentTimeSinceLastChild',num2cell(parentTimer(:,2)),...
                        'groupNumber',num2cell(repmat(i,size(mpm_generatedMothers,1),1)),...
                        'xpos',num2cell(mpm_generatedMothers(:,1:2:end),2),...
                        'ypos',num2cell(mpm_generatedMothers(:,2:2:end),2),...
                        'redrawn',[]);
                end
                %Saffarian hotspot process (outdated...must fix)
            case 2.1
                
                %if parent process we follow instead the number of parents
                %because this is the number we set instead of the child density
                % number of points is intensity times area
                nump = poissrnd(genProc(i).intensity * imareaLarge);
                
        end %of switch
        
        % if specified, generate more points
        % while per frame density for point generating process is not
        % met
        looplimit = 150;
        %initiate looping counter for reshuffle function so that points are
        %not redrwan forever if they can't be fit unto the frame due to
        %restrictions
        loopcount = 0;
        %clear currChildren so that children are not accounted for twice
        %later (should not be necessary, but just to make sure)
        clear currChildren
        while nump ~= 0 && (loopcount == 0 || genProc(i).reshuffle && loopcount < looplimit)
            
            % GENERATE POINTS
            switch genProc(i).type
                % distribution is random
                case 1
                    % generate random distribution
                    mpm = [1+(sx-1)*rand(nump,1) 1+(sy-1)*rand(nump,1)];
                    %add values for each parent created
                    currChildren(1:size(mpm,1)) = ...
                        struct('reshuffle',num2cell(repmat(genProc(i).reshuffle,size(mpm,1),1)),...
                        'timeLag',num2cell(repmat(genProc(i).timeLag,size(mpm,1),1)),...
                        'parentID',num2cell(repmat(0,size(mpm,1),1)),...
                        'type',num2cell(repmat(genProc(i).type,size(mpm,1),1)),...
                        'radius',num2cell((repmat(genProc(i).radius,size(mpm,1),1))),...
                        'nucleationFrame',num2cell((repmat(t,size(mpm,1),1))),...
                        'percentRestrict',num2cell((repmat(genProc(i).percentRestrict,size(mpm,1),1))),...
                        'groupNumber',num2cell(repmat(i,size(mpm,1),1)),...
                        'xpos',num2cell(mpm(:,1),2),...
                        'ypos',num2cell(mpm(:,2),2));
                    % saffarian process
                case 2.1
                    % generate random distribution
                    cmpm = [1+(sx-1)*rand(nump,1) 1+(sy-1)*rand(nump,1)];
                    
                    for ichild = 1:genProc(i).numChild
                        cmpm = cmpm + genProc(i).clusterRadius*randn(size(cmpm));
                        px0 = (cmpm(:,1)>1);
                        py0 = (cmpm(:,2)>1);
                        pxi = (cmpm(:,1)<sx);
                        pyi = (cmpm(:,2)<sy);
                        cmpm = cmpm(px0 & py0 & pxi & pyi,:);
                        currChildren((ichild-1)*size(cmpm,1)+1:ichild*size(cmpm,1)) = ...
                            struct('reshuffle',num2cell(repmat(genProc(i).reshuffle,size(cmpm,1),1)),...
                            'timeLag',num2cell(repmat(genProc(i).timeLag,size(cmpm,1),1)),...
                            'parentID',num2cell(repmat(0,size(cmpm,1),1)),...
                            'type',num2cell(repmat(genProc(i).type,size(cmpm,1),1)),...
                            'radius',num2cell((repmat(genProc(i).radius,size(cmpm,1),1))),...
                            'nucleationFrame',num2cell(t+(ichild-1)*genProc(i).timeLag,2),...
                            'percentRestrict',num2cell((repmat(genProc(i).percentRestrict,size(cmpm,1),1))),...
                            'groupNumber',num2cell(repmat(i,size(cmpm,1),1)),...
                            'xpos',num2cell(cmpm(:,1),2),...
                            'ypos',num2cell(cmpm(:,2),2));
                    end
                    % distribution is cluster (of raft or Cox type)
                case { 2, 3}
                    % generate daughters
                    if genProc(i).type==2
                        [cmpm, parents([parents.groupNumber]==i)] = makeCoxProcessMPM(parents([parents.groupNumber]==i),imagesize,t,'cox');
                    else
                        [cmpm, parents([parents.groupNumber]==i)] = makeCoxProcessMPM(parents([parents.groupNumber]==i),imagesize,t,'raft');
                    end
                    
                    if ~isempty(cmpm)
                        %add values for each parent created
                        currChildren(1:size(cmpm,1)) = ...
                            struct('reshuffle',num2cell(repmat(genProc(i).reshuffle,size(cmpm,1),1)),...
                            'timeLag',num2cell(repmat(genProc(i).timeLag,size(cmpm,1),1)),...
                            'parentID',num2cell(cmpm(:,3),2),...
                            'type',num2cell(repmat(genProc(i).type,size(cmpm,1),1)),...
                            'radius',num2cell((repmat(genProc(i).radius,size(cmpm,1),1))),...
                            'nucleationFrame',num2cell((repmat(t,size(cmpm,1),1))),...
                            'percentRestrict',num2cell((repmat(genProc(i).percentRestrict,size(cmpm,1),1))),...
                            'groupNumber',num2cell(repmat(i,size(cmpm,1),1)),...
                            'xpos',num2cell(cmpm(:,1),2),...
                            'ypos',num2cell(cmpm(:,2),2));
                    else
                        currChildren = [];
                    end
            end % of switch/case
            
            if ~isempty(currChildren)
                %RESTRICT POINTS IF RESTRICTIONS ARE PRESENT
                if exist('restrictions','var') && ~isempty(restrictions)
                    [currChildren] = makeExcludedOrIncludedMPM(currChildren,restrictions,t);
                end
                if t~=1 && ~isempty(children) && any([children.type] == 1 & [children.radius] ~= 0)
                    [currChildren] = restrictMPMBasedOnResources(currChildren,children([children.radius] ~= 0 & [children.type] == 1),t);
                end
                if exist('parents','var') && ~isempty(parents) && any([parents.radius] ~= 0)
                    [currChildren] = makeExcludedOrIncludedMPM(currChildren,parents([parents.radius]~=0),t);
                end
            end
            
            %STORE GENERATED POINTS
            children = [children currChildren];
            %             if length(children) == 0
            %                keyboard
            %             end
            % CALCULATE HOW MANY POINTS ARE MISSING
            switch genProc(i).type
                %
                case 1
                    nump = nump - length(currChildren);
                case 2.1
                    nump = 0;
                otherwise
                    %if parent process the density is the process
                    %density times the image area times the average
                    %number of children per parent
                    nump = round(genProc(i).intensity * imarea * genProc(i).numChild) - length(currChildren);
            end
            %update loop count
            loopcount = loopcount + 1;
        end %of while density not met
        
        if loopcount  == looplimit
            disp('could not reach specified point density');
        end
        
    end % of for i-loop for point generating processes
end % of for t


%% plot results
if plotOn
    %     figure, hold on
    %
    %     for t=1:numf
    %         plot([children([children.nucleationFrame] == t).xpos],...
    %             [children([children.nucleationFrame] == t).ypos],'b.')
    %         hold on
    %         parentx = [parents.xpos];
    %         parenty = [parents.ypos];
    %         plot(parentx(t:length(parentx)/length(parents):end),...
    %             parenty(t:length(parenty)/length(parents):end),'rx')
    %
    %         hold off;
    %         axis([1 sx 1 sy]);
    %         pause(0.1);
    %
    %     end
    figure, hold on
    plot([children.xpos],[children.ypos],'b.')
    
end %of if plot is on


end % of function


%%       ==================================================================


function [mpm_daughters,parents] = makeCoxProcessMPM(parents,imagesize,t,processType)

sx = imagesize(1);
sy = imagesize(2);
% NOTE: the mother points can lie outside the specified image size (in
% simulations, this can be necessary to avoid edge effects) - in any case,
% the daughter points are only retained if they come to lie inside the
% image

vec_nump = poissrnd([parents.numChild]);
if ~strcmp(processType,'saffarian')
    vec_nump([parents.currentTimeSinceLastChild] < [parents.timeLag]) = 0; %2*vec_nump([parents.currentTimeSinceLastChild] < [parents.timeLag]);
end
% initialize daughter points
cmpm_daughters = [];
%loop over all mother points
for ipar=1:length(parents)
    % current number of daughters from poisson distribution
    numd = vec_nump(ipar);
    %saffarian hotspot is the same as cox, but with a fixed number of
    %children that nucleate a fixed amount of time in space
    if  strcmp(processType,'saffarian')
        numd = parents(ipar).numChild;
    end
    
    if numd>0
        %generate vector length of mother-daughter distance
        if strcmp(processType,'cox') || strcmp(processType,'saffarian')
            %randn if cox
            lenDis = (parents(ipar).clusterRadius)*randn(numd,1);
        elseif strcmp(processType,'raft')
            %rand if raft
            lenDis = parents(ipar).clusterRadius*rand(numd,1);
        end
        %generate angle NOTE rand
        angle = 2*pi*rand(numd,1);
        %resulting endpoint for this daughter point
        endx = repmat(parents(ipar).xpos(t),numd,1) + lenDis .* sin(angle);
        endy = repmat(parents(ipar).ypos(t),numd,1) + lenDis .* cos(angle);
        cmpm = [endx endy repmat(ipar,numd,1) repmat(t-1,numd,1)+[1:numd]'];
        cmpm_daughters = [cmpm_daughters ; cmpm];
        %mark frame in which redrawn
        parents(ipar).currentTimeSinceLastChild = 0;
    else
        parents(ipar).currentTimeSinceLastChild = parents(ipar).currentTimeSinceLastChild + 1;
    end
    
end

if ~isempty(cmpm_daughters)
    px0 = (cmpm_daughters(:,1)>1);
    py0 = (cmpm_daughters(:,2)>1);
    pxi = (cmpm_daughters(:,1)<sx);
    pyi = (cmpm_daughters(:,2)<sy);
    mpm_daughters = cmpm_daughters(px0 & py0 & pxi & pyi,:);
else
    mpm_daughters = [];
end

end % of function

%%  =======================================================================
function [mpmNew] = makeParentMPM(nump,area,minDist, buffer, existingParentMPM)

%This function takes an existing parent mpm and makes a given number of
%additional parents in a given area at a given minimum distance from each
%other and from the existing parent mpm
%NOTE: The buffer is used to match up parents in the larger frame to the
%children in the smaller frame (see begining of function)
%NOTE: New parents are placed to be beyond the minimum distance from older
%parents and themselves; older parent positions are kept


sxLarge = area(1);
syLarge  = area(2);

% generate random distribution of mothers, in area with
% a buffer of +10 on all sides of the image
x_mother = 1+(sxLarge-1)*rand(nump,1) - buffer;
y_mother = 1+(syLarge-1)*rand(nump,1) - buffer;
mpmNew = [x_mother y_mother];


%calculate distance between new pareants and old parents
if nargin < 5 || isempty(existingParentMPM)
    new2oldDist = [];
else
    new2oldDist = distMat2(mpmNew,existingParentMPM);
end
%calculate distance between new parents
new2newDist = distMat2(mpmNew,mpmNew);
new2newDist(new2newDist==0) = nan;
parentDistance = [new2oldDist new2newDist];
%if any of these distances are smaller than minimum
%specified parent distance then redraw those
%only allow this to loop for so long
loopcount = 0;
while any(min(parentDistance,[],2) < minDist) && loopcount ~=50
    %find parents within minimum distance
    findParent = find(min(parentDistance,[],2) < minDist);
    %redraw new parents within minimum distance
    x_redraw = 1+(sxLarge-1)*rand(length(findParent),1) - buffer;
    y_redraw = 1+(syLarge-1)*rand(length(findParent),1) - buffer;
    %store redrawn values
    mpmNew(findParent,:) = [x_redraw y_redraw];
    %update loop count
    loopcount = loopcount + 1;
    %calculate distance between new pareants and old parents
    if nargin == 5
        new2oldDist = distMat2(mpmNew,existingParentMPM);
    end
    %calculate distance between new parents
    new2newDist = distMat2(mpmNew,mpmNew);
    new2newDist(new2newDist==0) = nan;
    parentDistance = [new2oldDist new2newDist];
end

%stop after 50 loops
if loopcount == 1000
    error('could not place all parents beyond minimum distance from each other')
end

end %of function make parent mpm

%%  =======================================================================
function [mpm_mother_curr] = diffuseParentMPM( mpm_mother_prev,sigma_diff, confRad, mpm_mother_first)
%Note: does not yet work with parent turn over...since these are given new
%positions, the reference positions should be the positions that the parent
%was originally changed to, not those of the first frame.
findBoundaries = 1:length(mpm_mother_prev);
while ~isempty(findBoundaries)
    mpm_mother_curr(findBoundaries,:) = mpm_mother_prev(findBoundaries,:) + ...
        repmat(sigma_diff(findBoundaries),1,2).*rand(length(findBoundaries),2);
    distances = distMat2(mpm_mother_curr,mpm_mother_first);
    findBoundaries = find(diag(distances,0) > confRad);
end
end % of function diffuse parents

%%  =======================================================================
function [mpm_restrict] = generateRestrictions(nFrame,imageSize,restrictionDensity,minDist,diffusivity,buffer)
% number of points is intensity times area
area = imageSize(1)*imageSize(2);
nump = round(restrictionDensity * area);
%create variable space
mpm_restrict = nan(nump,2*nFrame);
%for each frame
for iframe = 1:nFrame
    if iframe == 1
        % in the first frame, define the positions of the raft
        % points; in subsequent frames, re-use the original raft
        % positions or let them diffuse as specified
        % NOTE: to avoid edge effects, rafts have to be
        % simulated outside of the image, too
        [mpm_raft_start] = makeParentMPM(nump,imageSize,minDist, buffer);
        mpm_restrict(:,1:2) = mpm_raft_start;
    else
        mpm_raft_prev = mpm_restrict(:,2*iframe-3:2*iframe-2);
        mpm_restrict(:,iframe*2-1:iframe*2) = diffuseParentMPM( mpm_raft_prev,repmat(diffusivity,size(mpm_raft_prev,1),1));
    end
end %for each frame
end %of function

%%  =======================================================================
function [children] = makeExcludedOrIncludedMPM(children,restrictions,t);

%determine how many unique restrictions we have
radUnique = unique([restrictions.radius]);
perResUnique = unique([restrictions.percentRestrict]);
typeUnique = unique([restrictions.type]);
clusterUnique = unique([restrictions.clusterRadius]);

% determine distances of all daughter points from the central point of
% this restriction
xpos = [restrictions.xpos];
ypos = [restrictions.ypos];
dm = distMat2([[children.xpos]' [children.ypos]'],...
    [xpos(t:length(xpos)/length(restrictions):end)'...
    ypos(t:length(xpos)/length(restrictions):end)']);

%for each type
for iclus = clusterUnique
    for itype = typeUnique
        %for each unique radius
        for irad = radUnique
            %for each unique percent bein restricted
            for iper = perResUnique
                %find closest restriction
                dm_min = min(dm(:,[restrictions.radius] == irad & [restrictions.percentRestrict] == iper & [restrictions.type] == itype),[],2);
                %if any restrictions apply
                if ~isempty(dm_min)
                    % inclusive: exclude points that are outside radius from any
                    % restrictions
                    if itype == 4
                        error('not implemented yet')
                        fpos_stat = find(dm_min > irad);
                        % exclusive: exclude points that are within radius from
                        % rafts
                    elseif itype == 5
                        fpos_stat = find(dm_min <= irad);
                    elseif itype == 2 || itype == 3
                        fpos_stat = find([children.type]' == 1 & dm_min <= irad);
                    else
                        error('restriction not recognized')
                    end
                    
                    %number of points to exclude is the total number of points that are
                    %found within/outside exclusion multiplied by the percent to be
                    %excluded
                    if ~isempty(fpos_stat)
                        fpos_stat = randsample(fpos_stat,round(length(fpos_stat)*iper));
                        children(fpos_stat) = [];
                    end %of is any restrictions apply
                end %of for each percentRestrict
            end %of for each radius
        end %of for each type
    end %of for each cluster
end %of function
end

%% ========================================================================
function [currPoints] = restrictMPMBasedOnResources(currPoints,children,t)

%find points that still have the restriction
restrictionsID = find([children.timeLag] -repmat(t,1,length(children)) +[children.nucleationFrame] >= 0);
children = children(restrictionsID);

%determine how many unique restrictions we have
radUnique = unique([children.radius]);
perResUnique = unique([children.percentRestrict]);

%measure distance from points to restrictions
% determine distances of all daughter points from the central point
dm = distMat2([[currPoints.xpos]',[currPoints.ypos]'],...
    [[children.xpos]',[children.ypos]']);

%for each unique radius
for irad = radUnique
    %for each unique percent bein restricted
    for iper = perResUnique
        %find closest restriction
        dm_min = min(dm(:,[children.radius] == irad & [children.percentRestrict] == iper),[],2);
        %if any restrictions apply
        if ~isempty(dm_min)
            fpos_stat = find(dm_min <= irad);
            %number of points to exclude is the total number of points that are
            %found within/outside exclusion multiplied by the percent to be
            %excluded
            fpos_stat = randsample(fpos_stat,round(length(fpos_stat)*iper));
            currPoints(fpos_stat) = [];
        end %of is any restrictions apply
    end %of for each percentRestrict
end %of for each radius


end %of function

%% ========================================================================
function parents = redrawParentMPM(parents,area, buffer,t)
%this function takes a one frame-long mpm and a lifetime vector
%each row of the mpm corresponds to the same row in the lifetime vector
%parents that have outlived their usefulness are redrawn

%for each unique max parent lifetime
for ilife = unique([parents.lifetime])
    %for each unique parent minDist
    for minDist = unique([parents.minDistance])
        %find parents to redraw
        findParents = find([parents.currentParentLifetime] - 1 > ilife...
            & [parents.lifetime] == ilife & [parents.minDistance] == minDist);
        %NOTE: the minus one is there because lifetimes in each frame are
        %updated before parents are redrawn
        
        % determine points that will be used to determine minDistance to
        % place new parents
        xpos = [parents.xpos];
        ypos = [parents.ypos];
        mpm = [xpos(t:length(xpos)/length(parents):end)'...
            ypos(t:length(xpos)/length(parents):end)'];
        
        %redraw parents
        [mpmNewParents]= makeParentMPM(length(findParents),area,minDist, buffer,mpm);
        %update positions of parents to be redrawn with new positions
        for ipar = 1:size(mpmNewParents)
            parents(findParents(ipar)).xpos(t) = mpmNewParents(ipar,1);
            parents(findParents(ipar)).ypos(t) = mpmNewParents(ipar,2);
            %reset time counters for parents that disappear
            parents(findParents(ipar)).currentParentLifetime = 0;
            parents(findParents(ipar)).currentTimeSinceLastChild = 0;
            %mark frame in which redrawn
            parents(findParents(ipar)).redrawn = [parents(findParents(ipar)).redrawn t];
        end
    end %of for each unique minDist
end %of for each unique max parent lifetime
end %of function