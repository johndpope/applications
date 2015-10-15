function [ toPlot] = GCAReformatVeilStatsSplitMovie(toPlot,varargin)
% Here just want the groupData with the names and the relevant project
% lists for now.

%% Input 

%% INPUTPARSER
% for now check movieData separately.
%%Input check
ip = inputParser;

ip.CaseSensitive = false;
ip.addRequired('toPlot'); 
ip.addParameter('clearOldFields',false);
defaultOutputDirectory = pwd ; 
ip.addParameter('OutputDirectory',defaultOutputDirectory); 
ip.addParameter('percentileThresh',0); 
ip.addParameter('splitMovie',false); 

ip.parse(toPlot,varargin{:});

%% 




if ip.Results.clearOldFields 
    params = fieldnames(toPlot);
    params = params(~strcmpi(params,'info')); % keep the info
    toPlot = rmfield(toPlot,params);
end

    params{1} = 'mednVeloc';
    params{2} = 'persTime';
    params{3} = 'maxVeloc'; 
    params{4} = 'minVeloc' ; 
    params{5} = 'Veloc';
   % params{6} = 'percentage'; 
    
    analType{1} = 'protrusionAnalysis';
    analType{2} = 'retractionAnalysis';
    
    ylabel{1,1} = {'Median Velocity ' ; 'of Protrusion Event ' ; '(nm/sec)'};  
    ylabel{1,2} = {'Median Velocity ' ; 'of Retraction Event ' ; '(nm/sec)'}; 
    ylabel{2,1} = {'Persistence' ; 'of Protrusion Event ' ; '(s)'}; 
    ylabel{2,2} = {'Persistence' ; 'of Retraction Event ' ; '(s)'};
    ylabel{3,1} = {'Max Velocity ' ; 'of Protrusion Event ' ; '(nm/sec)'};
    ylabel{3,2} = {'Max Velocity ' ; 'of Retraction Event ' ; '(nm/sec)'};
    ylabel{4,1} = {'Min Velocity ' ; 'of Protrusion Event ' ; '(nm/sec)'}; 
    ylabel{4,2} = {'Min Velocity ' ; 'of Retraction Event ' ; '(nm/sec)'};
    ylabel{5,1} = {'Mean Velocity ' ; 'of Protrusion Event ' ; '(nm/sec)'};
    ylabel{5,2} = {'Mean Velocity ' ; 'of Retraction Event ' ; '(nm/sec)'};
%     ylabel{6,1} = {'Percentage of Windows' ; 'Protruding'}; 
%     ylabel{6,2} = {'Percentage of Windows' ; 'Retracting'}; 
%     
    ylim{1} = 100; 
    ylim{2} = 60; 
    ylim{3} = 100; 
    ylim{4} = 100; 
    ylim{5} = 100; 
    ylim{6}= 1; 
    
    
% Collect
for iGroup = 1:numel(toPlot.info.names)
    
    projListC = toPlot.info.projList{iGroup};
    
    [nplots,~] = size(projListC);
    if ip.Results.splitMovie
        % Grouping Var1 : grouping per condition
        % create the grouping variable for pooling full group data
        % [1,(Repeated 2*nCellsProj1 times), 2(Repeated
        % 2*nCellsProj2)....[n,(Repeated 2*ncellsProjN times)]
        grpVar{iGroup} = repmat(iGroup,nplots*2,1); %
        
        % create the grouping variable for examining data per cell
        
        % Grouping Var2  :   grouping per cell
        % [1,1,2,2,3,3,...numCellsTotal,numCellsTotal]
        g = arrayfun(@(x) repmat(x,2,1),1:nplots,'uniformoutput',0);
        grpVar2{iGroup} = size(vertcat(toPlot.info.projList{1:iGroup-1}),1) + vertcat(g{:});
        
        % Grouping Var3 : grouping per treatment
        g3 = repmat([1,2],1,nplots)';
        grpVar3{iGroup} = g3 + 2*(iGroup-1);
        
    end
    
    for iAnal = 1:2
        for iParam= 1:numel(params)
            [nProjs, ~]= size(projListC);
            % initialize mat
            %dataMat = nan(7000,nProjs); % over initialize
            count = 1; 
            for iProj = 1:size(projListC,1)
                folder = [projListC{iProj,1} filesep 'GrowthConeAnalyzer']; 
% 
%                 toLoad1 = [folder filesep 'protrusion_samples_ProtrusionBased_windSize_5ReInit61' filesep ...  
%                     'EdgeVelocityQuantification_CutMovie_1'  filesep ... 
%                     'EdgeMotion.mat'  ];
%                 toLoad2 = [folder filesep 'protrusion_samples_ProtrusionBased_windSize_5ReInit61' filesep ...  
%                     'EdgeVelocityQuantification_CutMovie_2' filesep 'EdgeMotion.mat'  ];
              
                 toLoad1 = [folder filesep 'protrusion_samples_ConstantNumber_windSize_5ReInit61' filesep ...  
                     'EdgeVelocityQuantification_CutMovie_1'  filesep ... 
                     'EdgeMotion.mat'  ];
                 toLoad2 = [folder filesep 'protrusion_samples_ConstantNumber_windSize_5ReInit61' filesep ...  
                     'EdgeVelocityQuantification_CutMovie_2' filesep 'EdgeMotion.mat'  ];





%                 
%                 toLoad1 = [folder filesep 'protrusion_samples_ProtrusionBased_windSize_5ReInit61' filesep ...  
%                     'EdgeVelocityQuantification_CutMovie_1'  filesep ... 
%                     'EdgeMotion.mat'  ];
%                 toLoad2 = [folder filesep 'protrusion_samples_ProtrusionBased_windSize_5ReInit61' filesep ...  
%                     'EdgeVelocityQuantification_CutMovie_2' filesep 'EdgeMotion.mat'  ];


% toLoad1= [folder filesep 'SegmentationPackage/GCASubRegions/GC/subRegion_windows/ConstantNumber' ... 
%    filesep  'EdgeVelocityQuantification_CutMovie_1' filesep 'EdgeMotion.mat']; 
% 
% toLoad2 = [folder filesep 'SegmentationPackage/GCASubRegions/GC/subRegion_windows/ConstantNumber' ... 
%     filesep  'EdgeVelocityQuantification_CutMovie_2' filesep 'EdgeMotion.mat']; 





                if exist(toLoad1,'file')~=0
                   first =  load(toLoad1);
                   last = load(toLoad2);                   
                
                    % want to collect prot persTime, retract persTime,prot mednvel in
                    % my old format for boxplot so i have the values groupable and I
                    % can do myown stats on them.
                    
                    valuesC1 =  first.analysisResults.(analType{iAnal}).total.(params{iParam}); % collect all the prot and or retract params
                    valuesC1 = valuesC1(~isnan(valuesC1));
%                     compare{1}=  valuesC1; 
                    
                    valuesC2 = last.analysisResults.(analType{iAnal}).total.(params{iParam}); 
                    valuesC2 = valuesC2(~isnan(valuesC2)); 
%                     compare{2} = valuesC2; 
%                     compareBoth = reformatDataCell(compare); 
%                     figure; 
%                     boxplot(compareBoth); 
                    
                    if ip.Results.percentileThresh >0 
                        allVals  = [valuesC1;valuesC2];
                        thresh = prctile(allVals,ip.Results.percentileThresh); 
                        valuesC1 = valuesC1(valuesC1 > thresh); 
                        valuesC2= valuesC2(valuesC2 > thresh); 
                        
                    end 
                    
                    if ip.Results.splitMovie
                        % for now just save each as an individual cell
                        data{count} = valuesC1;
                        data{count+1} = valuesC2;
                        
                        count = count+2;
                    else
                        
                        data{count} = [valuesC1;valuesC2];
                        count = count +1;
                    end
                    
                    
%                     [H,pValue] = permTest(compare{1},compare{2}); 
%                     % if make compare plot 
%                     compare = reformatDataCell(compare);
%                     setAxis('on') 
%                     forLabels{1} = 'First 5 min'; 
%                     forLabels{2} = 'Last 5 min'; 
%                     title(['PValue' num2str(pValue,'%03d')]); 
%                     boxplot(compare,'notch','on','labels',forLabels, 'outlierSize',1); 
                                     
%                     saveas(gcf, [MD.outputDirectory_ filesep 'protrusion_samples_ProtrusionBased_windSize_5ReInit61' filesep 'CompareBeginEnd']);
%                     saveas(gcf,[MD.outputDirectory_ filesep 'protrusion_samples_ProtrusionBased_windSize_5ReInit61' filesep 'CompareBeginEnd.png']); 
%                     
                    % combine                   
                    
                else 
                    display(['No File Found for ' projListC{iProj,1}]); 
                end
            end
            
            
            dataMat = reformatDataCell(data); 
            if ip.Results.percentileThresh >0 
                add = ['greaterThan' num2str(ip.Results.percentileThresh) 'th_Perc']; 
            else 
                add = []; 
            end 
            toPlot.([analType{iAnal} '_' params{iParam} '_' add]).dataMat{iGroup} = dataMat;
            toPlot.([analType{iAnal} '_' params{iParam} '_' add ]).yLabel = ylabel{iParam,iAnal}; 
            toPlot.([analType{iAnal} '_' params{iParam} '_' add ]).ylim = ylim{iParam}; 
            
            
            
           % toPlot.grpVar = 
            clear data dataMat
            
        end % iAnal
        
    end % iParam
    
    
    % collect the larger boxplot
    
    
    
    % plot the boxplots
    %         subplot(nrows,3,iProj)
    %
    %
    %
    %         subplot(nrows,3,iProj);
    %         name = strrep(projListC{iProj,2},'_',' ');
    %
    
    
    %     saveas(gcf,[saveDir filesep 'protrusionMaps_Group' groupData.names{iGroup} '.eps'],'psc2');
    %     saveas(gcf,[saveDir filesep 'protrusionMaps_Group' groupData.names{iGroup} '.fig']);
    
%      toPlot.info.groupingPoolWholeMovie = vertcat(grpVar{:});
%      toPlot.info.groupingPerCell= vertcat(grpVar2{:});
%      toPlot.info.groupingPoolBeginEndMovie = vertcat(grpVar3{:}); 
    if ip.Results.splitMovie == false
        toPlot.info.groupingPerCell = 1:size(vertcat(toPlot.info.projList{:}),1);
        toPlot.info.groupingPoolWholeMovie = toPlot.info.grouping;
    else
        toPlot.info.groupingPoolWholeMovie = vertcat(grpVar{:});
        toPlot.info.groupingPerCell= vertcat(grpVar2{:});
        toPlot.info.groupingPoolBeginEndMovie = vertcat(grpVar3{:});
    end
    


    % toPlot.info.colors = groupData.color;
    % toPlot.info.projList = groupData.projList;
    %toPlot.info.names = groupData.names;
    %if ~isempty(saveDir)
        
        save([ip.Results.OutputDirectory filesep 'toPlotVeil.mat'],'toPlot');
    %end
    close gcf
    
   
end





