function movieData = getMovieWindows(movieData,paramsIn)
%GETMOVIEWINDOWS creates sampling windows for every frame of the input movie
%
% movieData = getMovieWindows(movieData);
%
% movieData = getMovieWindows(movieData,paramsIn);
% 
% 
% Divides the masked area of the movie in each frame up into sampling
% windows and saves them to disk. The windows are initially generated using
% getMaskWindows.m and then propagated through subsequent frames of the
% movie by a variety of methods.
%
%
% Input:
% 
%   movieData - a MovieData object describing the movie to be windowed. 
%
%   paramsIn - Optional. A structure containing the parameters to use for
%   windowing the movie. Optional parameters include:
%
%       (Parameter field name -> Possible values)
%
%       ('ChannelIndex' -> Positive integer scalar or vector) Optional. The
%       integer index of the channel(s) to use masks from to create
%       windows. A given movie may only have one set of windows, but these
%       may be based on the masks from multiple channels. If multiple
%       channels are specified, the intersection of their masks will be
%       used as the mask for windowing.
%
%       ('MethodName' -> character array) This is a character array
%       describing the method to use to propagate the windows from one
%       frame to the next. The possible values are:
%
%           'ConstantWidth' These windows are drawn time-independently
%           in each frame. The windows will always be paraSize pixels in
%           width at the mask edge (or at the depth specified by
%           startPoint). To maintain this constant width, the number of
%           windows will vary as the length of the mask edge varies.
%           That is, if the mask edge length increases the number of
%           windows will increase. The windows will always occupy a
%           constant distance from the mask edge.
%
%           'ConstantNumber' - The windows are drawn time-independently in
%           each frame by dividing the mask edge up into a constant number
%           of segments. Their size in the direction parallel to the mask
%           edge will therefore be proportional to the length of the mask
%           edge divided by nWinPerp. Therefore their width will vary as
%           the length of the mask edge varies. The windows will always
%           maintain a constant distance from the mask edge.
%
%           'ProtrusionBased' - The outermost band of windows will follow
%           the protrusion vectors for the mask edge. The protrusion
%           calculations must already have been run. The inner bands of
%           windows will still be based on maximal gradient ascent of the
%           distance transform, using the outermost windows for start
%           points. The windows are time-dependent and may change width
%           along the mask edge or even collapse to lines during the movie
%           depending on how the mask moves/changes shape and the algorithm
%           used to calculate the protrusion vectors. However, the windows
%           will still always occupy a constant distance from the mask
%           edge.
% 
%           'PDEBased' - The protrusion vectors are used as a
%           boundary condition to solve a PDE in the mask interior.
%           This allows the protrusion vectors to be 'interpolated' into
%           the interior of the mask and all of the windows then follow
%           this vector field. Using this method the windows are
%           time-dependent and will change both their width along the mask
%           edge AND their width perpindicular to the cell edge. As a
%           result they will NOT occupy a constant distance from the mask
%           edge if it is moving. This method also has additional
%           parameters:
%
%                 ('MeshQuality' -> Positive integer, between 1-5) This
%                 specifies the quality of the triangular mesh used to
%                 solve the laplacian equation for protrusion vector
%                 interpolation. Higher numbers will DRASTICALLY increase
%                 the time required to propagate windows, but will increase
%                 the accuracy of the interpolation.
% 
%                 ('PDEPar' -> EITHER 1x3 Cell Array OR Character Array) If
%                 specified as a 1x3 cell array, this contains the
%                 coefficients to use for the PDE. The elements of this
%                 vector correspond to the c, a and f coefficients
%                 respectively used by assembpde.m and adaptmesh.m. If
%                 specified as a character array, it is the name of the
%                 physical model to use for window propagation. The
%                 available models are:
%
%                   'Viscous' - Retains only the viscous terms of the
%                   Navier-Stokes equations describing an incompressible
%                   Newtonian fluid.
%
%                   'ViscousConvective' - Uses both the viscous and the
%                   non-linear convective acceleration terms of the
%                   incompressible Navier-Stokes equations for a Newtonian
%                   fluid.
%
%                   'ViscoElastic' - Simple visco-elastic model, based on
%                   Navier equation for elastic solid. Assumes instant
%                   relaxation, no dependence on past.
%
%                 ('NonlinearSolver->'on'/'off') This determines whether
%                 the non-linear solver is used to find the PDE solution.
%                 If a physical model is specified, this parameter is
%                 automatically set. If the coefficients themselves are
%                 specfied, and any of these coefficients depend on the PDE
%                 solution value or its first derivative, this option must
%                 be set to 'on' or an error will be generated.
%
%       ('ParaSize'->Positive Scalar or Vector) The width of the windows in
%       the direction parallel to the mask edge, in pixels. Default is 10
%       pixels. See getMaskWindows.m for more details. Note that depending
%       on the propagation method, the windows may only be exactly this
%       size at the first frame of the movie, and frames where
%       re-initialization occurs. See propagation method descriptions and
%       the ReInit parameter description for details.
%
%       ('PerpSize'->Positive Scalar or Vector) The width of the windows in
%       the direction perpindicular to the mask edge. Default is 10 pixels.
%       Note that depending on the propagation method, the windows may
%       only be exactly this size at the first frame of the movie, and
%       frames where re-initialization occurs. See propagation method
%       descriptions and the ReInit parameter description for details.
% 
%       ('ReInit' -> A positive integer) - This specifies the number of
%       frames to propagate windows before re-initializing them to their
%       starting sizes/number. The default is Inf, which means that
%       no-reinitialization is done. Not that this option will have no
%       effect on the time-independent window propagation methods (Constant
%       Width, Constant Number).
% 
%       ('StartPoint' > 1x2 or 2x1 positive vector) Specifies the location
%       of the "origin" of the windows. See getMaskWindows.m for more
%       details. Note that, depending on the propagation method and ReInit
%       option settings, this may only be true on certain frames.        
%
%       ('MinSize' -> Positive Scalar) The minimum size, in pixels, of
%       objects to windows. There must be only one object in the mask
%       larger than this size.
%       Default is 10.
%
%       ('OutputDirectory' -> character string)
%       Optional. A character string specifying the directory to save the
%       windows to. Windows for different channels will be saved as
%       sub-directories of this directory.
%       If not input, the windows will be saved to the same directory as the
%       movieData, in a sub-directory called "windows"
%
%       ('SegProcessIndex' -> Positive integer scalar) This specifies the
%       index of the segmentation process to use masks from for creating
%       windows. This is only necessary if more than one segmentatin
%       process exists. If not specified, and more than one segmentation
%       process exists, the user will be asked, unless batch mode is
%       enabled, in which case an error will be generated.
%
%       ('BatchMode' - True/False) If true, all graphical output (figures,
%       progress bars) will be suppressed.
% 
%
% Output:
% 
%   movieData - Updated MovieData object, with the parameters used logged
%   in the "Processes" field. 
% 
%   Additionally, the windows will be written to the directory specified by
%   OutputDirectory. The windows are in the format described by
%   getMaskWindows.m, with each frame stored as a separate .mat file.
% 
% 
% Hunter Elliott
% 4/2008
% Re-written 7/2010
%
%% ------ Parameters -------%%

pString = 'windows_frame_'; %Prefix for naming window files.

%% ------ Input ------ %%

if nargin < 1 || isempty(movieData)
    error('You must input a movieData object!')
end

if ~isa(movieData,'MovieData')
    error('The first input must be a valid MovieData object!')
end

if nargin < 2 || isempty(paramsIn)
    paramsIn = [];
end

%Check if the movie has been windowed before
iProc = movieData.getProcessIndex('WindowingProcess',1,false);
if isempty(iProc)
    iProc = numel(movieData.processes_)+1;
    movieData.addProcess(WindowingProcess(movieData,movieData.outputDirectory_));
end

%Parse input, store in parameter structure
p = parseProcessParams(movieData.processes_{iProc},paramsIn);

%Make sure the movie has been segmented, and find the desired process.
if isempty(p.SegProcessIndex)
    iSegProc = movieData.getProcessIndex('SegmentationProcess',1,~p.BatchMode);
elseif isa(movieData.processes_{p.SegProcessIndex},'SegmentationProcess')
    iSegProc = p.SegProcessIndex;
else
    error('The process specified by SegProcessIndex is not a valid SegmentationProcess! Check input!')
end
if isempty(iSegProc)
    error('The movie could not be windowed, because it has not been segmented yet!')
else
    %Make sure the index is stored in the parameter structure if it wasn't
    %input - we'll need this in other functions.
    p.SegProcessIndex = iSegProc;
end

%Make sure the channels which are to be used in windowing have valid masks
hasMasks = movieData.processes_{iSegProc}.checkChannelOutput(p.ChannelIndex);
if ~all(hasMasks)
    error('The movie could not be windowed, because some of the channels which were selected to use masks from did not have valid masks!');
end

if strcmp(p.MethodName,'PDEBased') || strcmp(p.MethodName,'ProtrusionBased')
    usesProt = true;
    %These methods need protrusion vectors - make sure that the protrusion
    %vectors are available and load them    
    iProtProc = movieData.getProcessIndex('ProtrusionProcess',1,~p.BatchMode);
    if isempty(iProtProc) || ~movieData.processes_{iProtProc}.checkChannelOutput
        error(['The method ' p.MethodName ...
            ' requires protrusion vectors, but the input movie does not have valid protrusion vectors!'])               
    end    
else
    usesProt = false;
end


%Check the inputs for the PDE - based propagation method if selected
if strcmp(p.MethodName,'PDEBased') 
    
    if ~isfield(p,'PDEPar') || isempty(p.PDEPar)
        error('For the PDEBased method, you must specify PDE coefficients or a model name in the PDEPar option! Please check input!')
    end

    %Set up the coefficients for the physical models.
    if ischar(p.PDEPar)
        
        switch p.PDEPar
            
            
            case 'Viscous'
                     
                %Currently assumes viscosity = 1
                
                c = zeros(2,2,2,2);
                c(1,1,1,1) = 1;
                c(1,1,2,2) = 1;
                c(2,2,1,1) = 1;
                c(2,2,2,2) = 1;
                
                a = zeros(2);
                
                f = zeros(2,1);
                
                p.PDEPar = {c(:) a(:) f(:)};
                
                p.NonLinearSolver = 'off';
                
            case 'ViscousConvective'
                
                %Currently assumes that both density and viscosity = 1
                
                %Viscous Term
                c = zeros(2,2,2,2);
                c(1,1,1,1) = 1;
                c(1,1,2,2) = 1;
                c(2,2,1,1) = 1;
                c(2,2,2,2) = 1;
                
                %Covective Acceleration term
                a = vertcat('ux(1,:)','ux(2,:)','uy(1,:)','uy(2,:)');
                                
                f = zeros(2,1);
                
                p.PDEPar = {c(:) a f(:)};
                
                p.NonLinearSolver = 'on';
                
            case 'ViscoElastic'
                
                mu = 1;%Shear modulus
                lambda = 1;%Lame's first parameter
                
                %Coefficients for second derivatives.
                c1 = 2*mu+lambda;
                c2 = lambda + mu;
                c3 = mu;
                
                c = zeros(2,2,2,2);
                c(1,1,1,1) = c1;
                c(1,2,1,2) = c2;
                c(1,1,2,2) = c3;
                
                c(2,2,2,2) = c1;
                c(2,1,2,1) = c2;
                c(2,2,1,1) = c3;
                        
                a = zeros(2);
                f = zeros(2,1);
                
                p.PDEPar = {c(:),a(:),f(:)};
                p.NonLinearSolver = 'off';
                
                
            otherwise
                
                error(['"' p.PDEPar '" is not a recognized model name! Check the PDEPar input!'])
                
        end
        
    
    elseif ~iscell(p.PDEPar) || ~isequal([1 3],size(p.PDEPar)) ...        
            || any(cellfun(@(x)(isempty(x)),p.PDEPar))
            error('You must specify all 3 coefficients in the PDEPar input, or a character array with a  model name!')                       
    end
    
    
end




%% ---------  Init  ----------- %%

nFrames = movieData.nFrames_;
nChan = numel(p.ChannelIndex);
imSize = movieData.imSize_;

%Get the mask directories and file names
maskDir = movieData.processes_{iSegProc}.outFilePaths_(p.ChannelIndex);
maskNames = movieData.processes_{iSegProc}.getOutMaskFileNames(p.ChannelIndex);



%Go through and load and check all the masks prior to windowing
disp('Loading and checking all masks...')

maskArray = true([imSize nFrames]);
for iFrame = 1:nFrames;
    
    %Open and combine masks from the selected channels
    
    for iChan = 1:nChan        
        maskArray(:,:,iFrame) = maskArray(:,:,iFrame) & ...
            imread([maskDir{iChan} filesep maskNames{iChan}{iFrame}]);                
    end       
    
    %Remove very small objects
    maskArray(:,:,iFrame) = bwareaopen(maskArray(:,:,iFrame),p.MinSize);
    
    %Check the remaining number of objects in the mask    
    CC = bwconncomp(maskArray(:,:,iFrame));
           
    if CC.NumObjects > 1
        error(['There is more than one object larger than MinSize in the mask for frame ' ...
            num2str(iFrame) ' - windowing aborted!']);
    end
    
    if ~isequal(maskArray(:,:,iFrame),imfill(maskArray(:,:,iFrame),'holes'))
        error(['There was a hole in mask for frame ' num2str(iFrame) ' - windowing aborted!']);
    end
    
    if nnz(maskArray(:,:,iFrame)) == 0 || nnz(maskArray(:,:,iFrame)) == numel(maskArray(:,:,iFrame))
        error(['Mask for frame ' num2str(iFrame) ' has nothing in it - windowing aborted!']);
    end   
    
end
disp('All masks okay! Starting windowing...')



if ~p.BatchMode
    wtBar = waitbar(0,'Please wait, creating windows ...');
end        

%Create format string for zero-padding file names
fString = ['%0' num2str(floor(log10(nFrames))+1) '.f'];

%Set up and store the output directories for the windows
mkClrDir(p.OutputDirectory)
movieData.processes_{iProc}.setOutFilePath(p.OutputDirectory),

%Load the protrusion vectors if necessary
if usesProt
    protrusion = movieData.processes_{iProtProc}.loadChannelOutput;
    %Separate into individual arrays for readability    
    smoothedEdge = protrusion.smoothedEdge;
    protrusion = protrusion.protrusion;
end

nBandMax = 0;
nSliceMax = 0;


%% --------- Windowing -------- %%



for iFrame = 1:nFrames

        
    
    switch p.MethodName

        case 'ConstantWidth'                

            windows = getMaskWindows(maskArray(:,:,iFrame),p.PerpSize,...
                p.ParaSize,'StartPoint',p.StartPoint,'DoChecks',false);

        case 'ConstantNumber'
            
            if iFrame == 1
                %Create windows based on size in frame 1
                windows = getMaskWindows(maskArray(:,:,iFrame),p.PerpSize,...
                    p.ParaSize,'StartPoint',p.StartPoint,'DoChecks',false);
                %Preserve this number throughout movie.
                nWinPara = numel(windows);                
            else
                windows = getMaskWindows(maskArray(:,:,iFrame),p.PerpSize,...
                    [],'StartPoint',p.StartPoint,'NumParallel',nWinPara,...
                    'DoChecks',false);                
            end
            
        case 'ProtrusionBased'
            
            if iFrame == 1 || mod(iFrame,p.ReInit) < 1
                %(Re)Initialize the windows to this frame
                
                %Since we need to propagate the startpoints anyaways, we
                %just get them ourselves here.               
                
                %Get the zero-contour of the mask, and post-process it in
                %the same way as getMaskWindows.m
                zeroCont = contourc(double(maskArray(:,:,iFrame)),[0 0]);
                zeroCont = separateContours(zeroCont);
                zeroCont = cleanUpContours(zeroCont,4);
                if numel(zeroCont) > 1
                    error('Problem with mask - mask must contain only one object, and that object may not have holes in it! Check masks!')
                end
                zeroCont = zeroCont{1};
                %Calculate the cumulative distance along the contour
                distAlong = [0 cumsum(sqrt(diff(zeroCont(1,:)) .^2 + diff(zeroCont(2,:)) .^2))];
                %Get the desired distance values based on the window size
                distVals = 0:p.ParaSize:distAlong(end);
                %If the size isn't an even multiple of the contour length,
                %we need to add an additional start point.
                if distVals(end) ~= distAlong(end)
                    distVals = [distVals distAlong(end)]; %#ok<AGROW>
                end
                %Get the start points from the zero contour
                [~,iStartPts] = arrayfun(@(x)(min(abs(distAlong-distVals(x)))),1:numel(distVals));
                startPts = zeroCont(:,iStartPts)';                
              
            else
                              
                iBestProt = correspondingIndices(startPts',smoothedEdge{iFrame-1}');                    
                startPts = smoothedEdge{iFrame-1}(iBestProt,:) + protrusion{iFrame-1}(iBestProt,:);
                    
            end
            
            %Get the new windows with these start points.                
            windows = getMaskWindows(maskArray(:,:,iFrame),p.PerpSize,...
                [],'StartPoint',startPts,'StartContour',1,'DoChecks',false);
                                                             

        case 'PDEBased'
            
            if iFrame == 1 || mod(iFrame,p.ReInit) < 1
                %(Re) Initialize the windows to this frame
                windows = getMaskWindows(maskArray(:,:,iFrame),p.PerpSize,...
                    p.ParaSize,'StartPoint',p.StartPoint,'DoChecks',false);
                
            else
            
                %Check if the mask object touches the edge of the image. If
                %so, we need to close the boundary prior to finding a
                %solution.
                if any(any([maskArray([1 end],:) maskArray(:,[1 end])']))
                    tmp = {smoothedEdge{iFrame-1}'};
                    %Close the edge to get a full boundary
                    tmp = closeContours(tmp,bwdist(~maskArray(:,:,iFrame-1)));
                    smoothedEdge{iFrame-1} = tmp{1}';
                    %We need to add elements to the protrusion vectors so
                    %they agree with the new closed contour
                    nPtsClosed = size(tmp{1},2);
                    protrusion{iFrame-1} = vertcat(protrusion{iFrame-1},...
                                   zeros(nPtsClosed-size(protrusion{iFrame-1},1),2));
                end
                
                                
                %Propagate these windows based on the PDE solution given
                %the protrusion vectors as a boundary condition.                                
                iStrtPt = 1;                                                                
                while 1
                    
                    try
                        %Get point indices, repeating one point to completely
                        %close the curve.
                        iBoundPts = [iStrtPt:size(smoothedEdge{iFrame-1},1) 1:iStrtPt];
                        %Get the vector field
                        [X,Y] = solvePDEVectorBoundary(...
                            smoothedEdge{iFrame-1}(iBoundPts,:),...
                            protrusion{iFrame-1}(iBoundPts,:),...
                            p.PDEPar,imSize,p.MeshQuality,p.NonLinearSolver);                    
                        
                        break
                        
                    catch errMess
                        
                        if strcmp(errMess.identifier,'PDE:pdevoron:GeomError') && iStrtPt < 5                               
                            
                            %This is an ugly workaround for a bug in the PDE
                            %toolbox which occasionally causes a geometry error
                            %on valid geometry. Circularly permuting the
                            %boundary and boundary condition (which is mathematically                            
                            %equivalent) somehow avoids this error...
                            iStrtPt = iStrtPt + 1;
                            
                        else
                            rethrow(errMess)
                        end
                        
                    end
                end
                %Displace the inner windows with this vector field
                windows = displaceWindows(windows,X,Y,...
                        smoothedEdge{iFrame-1}',smoothedEdge{iFrame}',...
                        protrusion{iFrame-1}');                    

            end            
            


        otherwise

            error(['"' p.MethodName '" is not a recognized window propagation method!'])                                
    end

    nSliceMax = max([nSliceMax, numel(windows)]);    
    nBandMax = max([nBandMax cellfun(@(x)(numel(x)),windows)]);
        
    %Save the windows to the output directory!
    save([p.OutputDirectory filesep pString '_frame_' num2str(iFrame,fString) '.mat'],'windows');

    if ~p.BatchMode && mod(iFrame,5)
        %Update the waitbar (occasionally to minimize slowdown)
        waitbar(iFrame / nFrames,wtBar)
    end
   
end


%% ----------- Output ----------- %%

if ~p.BatchMode && ishandle(wtBar)
    close(wtBar);
end

%Update the movie data, save it
movieData.processes_{iProc}.setDateTime;
%Store the maximum number of bands and slices
%later for array initialization
movieData.processes_{iProc}.setWinStats(nSliceMax,nBandMax);
%Make sure the final parameters are stored in the process for later use.
movieData.processes_{iProc}.setPara(p); 
movieData.save; %Save the new movieData to disk

disp('Finished windowing!')


