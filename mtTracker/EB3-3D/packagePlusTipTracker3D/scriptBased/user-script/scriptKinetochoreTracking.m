%% %% USER INPUT 

%% LOADING MOVIES INFORMATION (TWO OPTIONS)
%% Loading MovieList file
% MovieList paths: 
MLPath='/work/gdanuser/proudot/project/EB3-3D-track/data-analysis/four-phases/';

% MovieList FileName (the combination of condition you want to compare). 
movieListFileNames={'prometaphaseCells.mat'};
MLPath='/project/cellbiology/gdanuser/december/philippe/externBetzig/analysis/proudot/anaProject/sphericalProjection/prometaphase/cell1_12_half_volume_double_time';
movieListFileNames={'movieList.mat'};
% Build the array of MovieList (automatic)
aMovieListArray=cellfun(@(x) MovieList.loadMatFile([MLPath filesep x]), movieListFileNames,'unif',0);
aMovieListArray=aMovieListArray{:};

%% PROCESS MANAGEMENT 
%  - 1 to (re-)run the algorithm
%  - 0 to load previously computed results (if any)
runDetection=0;     
runSpindleRef=0;
runTracking=0; 
runAmiraWrite=0;      
 

%% Parameter
detectionMethod='pointSourceAutoSigmaFit';

% method used to detect poles
EB3poleDetectionMethod=['simplex_scale_003'];

for k=1:length(aMovieListArray)
    ML=aMovieListArray(k);
    
    %% loop over each different cell in each condition
    for i=1:length(ML.movieDataFile_)
        MD=MovieData.loadMatFile(ML.movieDataFile_{i});
        disp(['Processing movie: ' MD.getFullPath]);
        dataAnisotropy=[MD.pixelSize_ MD.pixelSize_ MD.pixelSizeZ_];
        
        %% detect
        outputDirDetect=[MD.outputDirectory_ filesep 'Kin'  filesep 'detection' filesep];mkdir(outputDirDetect);
        if(runDetection)
            [detectionsLabRef,lab]=detectEB3(MD,'type',detectionMethod,'showAll',false,'channel',2)
            save([outputDirDetect filesep 'detectionLabRef.mat'],'detectionsLabRef');
            amiraWriteMovieInfo([outputDirDetect filesep 'Amira' filesep 'amiraVertexLabRef' filesep  'detectionsLabRef.am'], detectionsLabRef,'scales',dataAnisotropy);
            mkdir([outputDirDetect filesep 'detectionMaskLabRef']);
            for tidx=1:length(detectionsLabRef)
                stackWrite(lab{tidx},[outputDirDetect filesep 'detectionMaskLabRef' filesep 'detect_T_' num2str(tidx,'%05d') '.tif']);
            end
        else
            if (exist([outputDirDetect filesep 'detectionLabRef.mat'], 'file') == 2)
                tmp=load([outputDirDetect 'detectionLabRef.mat']);
                detectionsLabRef=tmp.detectionsLabRef;
            else
                error('Detection files not found. Please run detection beforehand');
            end
        end

        detectionsStageRef=detectionsLabRef;
        driftFilename=[MD.outputDirectory_ filesep 'regFile' filesep 'driftParameter.mat'];
        if (exist(driftFilename, 'file') == 2)
            driftParameter=load(driftFilename);
            displacements=driftParameter.displacements;
            jumpIdx=driftParameter.jumpIdx;
            parfor i=1:MD.nFrames_
                jIdx=find((jumpIdx<i));
                for j=jIdx
                    detectionsStageRef(i).xCoord(:,1)=detectionsStageRef(i).xCoord(:,1)+displacements{j}.T(4,1);
                    detectionsStageRef(i).yCoord(:,1)=detectionsStageRef(i).yCoord(:,1)+displacements{j}.T(4,2);
                    detectionsStageRef(i).zCoord(:,1)=detectionsStageRef(i).zCoord(:,1)+displacements{j}.T(4,3);
                end
            end
            save([outputDirDetect filesep 'detectionStageRef.mat'],'detectionsStageRef');
            amiraWriteMovieInfo([outputDirDetect filesep 'Amira' filesep 'amiraVertexStageRef' filesep 'detectionsStageRef.am'], detectionsStageRef,'scales',dataAnisotropy);
            tmp=load([outputDirDetect filesep 'detectionStageRef.mat']);
            detectionsStageRef=tmp.detectionsStageRef;
        else
            disp('Movie has not been registered: stage is considered static in the laboratory frame of reference.');
        end
        
        
        
        %% Pole detection
        outputDirPoleDetect=[MD.outputDirectory_ filesep 'EB3' filesep 'poles' filesep EB3poleDetectionMethod filesep];mkdir(outputDirPoleDetect);
        if(runSpindleRef)
            poleData=load([outputDirPoleDetect filesep 'poleDetection.mat']);
            poleMovieInfo=poleData.poleMovieInfo;
                        
            %% Set detection in the spindle referential
            [dist,sphCoord,poleId,inliers,originProb,minProb,sphCoordBest,detectionsSpindleRef]=poleDist(poleMovieInfo,detectionsStageRef,'anisotropy',dataAnisotropy,'angleRef','poles');
            save([outputDirDetect filesep 'dist.mat'],'dist','minProb','poleId','inliers');
            save([outputDirDetect filesep 'sphericalCoordBothPoles.mat'],'sphCoord');
            save([outputDirDetect filesep 'detectionSpindleRef.mat'],'detectionsSpindleRef');
            
            amiraWriteMovieInfo([outputDirDetect filesep 'Amira' filesep 'amiraVertexLabRef' filesep 'detectionsLabRef.am'],detectionsLabRef, ...
                'scales',dataAnisotropy,'prop',{{'minProb',minProb},{'azimuth',sphCoordBest.azimuth},{'elevation',sphCoordBest.elevation},{'poleId',cellfun(@(x,y) x.*y,inliers,poleId,'unif',0)}});
            amiraWriteMovieInfo([outputDirDetect filesep 'Amira' filesep 'amiraVertexSpindleRef' filesep 'detectionsSpindleRef.am'],detectionsSpindleRef, ...
                'scales',dataAnisotropy,'prop',{{'minProb',minProb},{'azimuth',sphCoordBest.azimuth},{'elevation',sphCoordBest.elevation},{'poleId',cellfun(@(x,y) x.*y,inliers,poleId,'unif',0)}});
            if (exist([outputDirDetect filesep 'detectionStageRef.mat'], 'file') == 2)
                amiraWriteMovieInfo([outputDirDetect filesep 'Amira' filesep  'amiraVertexStageRef' filesep 'detectionsStageRef.am'],detectionsStageRef, ...
                    'scales',dataAnisotropy,'prop',{{'minProb',minProb},{'azimuth',sphCoordBest.azimuth},{'elevation',sphCoordBest.elevation},{'poleId',cellfun(@(x,y) x.*y,inliers,poleId,'unif',0)}});
            end
        else
            load([outputDirDetect filesep 'detectionSpindleRef.mat']);
            load([outputDirDetect filesep 'sphericalCoordBothPoles.mat']);
            load([outputDirDetect filesep 'dist.mat']);
        end
        
        
        %% Tracking
        outputDirTrack=[MD.outputDirectory_ filesep 'Kin' filesep 'track' filesep ];mkdir(outputDirTrack);
        if runTracking
            [gapCloseParam,costMatrices,kalmanFunctions,probDim,verbose]=kinTrackingParam();
            watch_KF_iter=0;
            saveResults.dir =  outputDirTrack ; %directory where to save input and output
            saveResults.filename = 'trackResults.mat'; %name of file where input and output are saved
            
            [tracksFinal,kalmanInfoLink,errFlag] = ...
                trackCloseGapsKalmanSparse(detectionsStageRef, ...
                costMatrices,gapCloseParam,kalmanFunctions,...
                probDim,saveResults,verbose);
            
            %% Convert tracks final in a user-friendlier format
            %  (using the registered Frame of Ref and the lab FoR)
            tracksLabRef=TracksHandle(tracksFinal,detectionsLabRef);
            save([outputDirTrack filesep  'tracksLabRef.mat'],'tracksLabRef')
            tracksStageRef=TracksHandle(tracksFinal,detectionsStageRef);
            save([outputDirTrack filesep 'tracksStageRef.mat'],'tracksStageRef')
            tracksSpindleRef=TracksHandle(tracksFinal,detectionsSpindleRef);
            save([outputDirTrack filesep  'tracksSpindleRef.mat'],'tracksSpindleRef')
        else
            if (exist([outputDirTrack  filesep 'tracksLabRef.mat'], 'file') == 2)
                load([outputDirTrack  filesep 'tracksLabRef.mat']);
                load([outputDirTrack  filesep 'tracksStageRef.mat']);
                load([outputDirTrack  filesep 'tracksSpindleRef.mat']);
            else
                error('ERROR: no tracking file found.');
            end
        end
        
        if(runAmiraWrite)
            
            %% Tracks in the lab FoR.
            amiraWriteTracks([outputDirTrack filesep 'Amira' filesep 'AmiraTrackLabRef' filesep 'tracksLabRef.am'],tracksLabRef,'MD',MD);
            amiraWriteTracks([outputDirTrack filesep 'Amira' filesep  'AmiraTrackLabRef20plus' filesep 'trackLabRef20plus.am'],tracksLabRef([tracksLabRef.lifetime]>20),'MD',MD);
            
            %% Tracks in the Stage FoR.
            amiraWriteTracks([outputDirTrack filesep 'Amira' filesep  'AmiraTracksStageRef' filesep 'tracksLabRef.am'],tracksStageRef,'MD',MD);
            amiraWriteTracks([outputDirTrack filesep 'Amira' filesep  'AmiraTrackStageRef20plus' filesep 'trackLabRef20plus.am'],tracksStageRef([tracksStageRef.lifetime]>20),'MD',MD);
            
            %% Tracks in the spindle FoR.
            amiraWriteTracks([outputDirTrack filesep 'Amira' filesep  'AmiraTrackSpindleRef' filesep 'trackSpindleRef.am'],tracksSpindleRef,'MD',MD);
            amiraWriteTracks([outputDirTrack filesep 'Amira' filesep  'AmiraTrackSpindleRef20plus' filesep 'trackSpindleRef20plus.am'],tracksSpindleRef([tracksSpindleRef.lifetime]>20),'MD',MD);
            
        end
        
    end
end