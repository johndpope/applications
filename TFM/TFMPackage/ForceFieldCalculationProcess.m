classdef ForceFieldCalculationProcess < DataProcessingProcess
    % Concrete process for calculating a force field
    %
    % Sebastien Besson, Aug 2011
    properties (SetAccess = protected)  
        tMapLimits_
    end
    
    methods
        function obj = ForceFieldCalculationProcess(owner,varargin)
            
            if nargin == 0
                super_args = {};
            else
                % Input check
                ip = inputParser;
                ip.addRequired('owner',@(x) isa(x,'MovieData'));
                ip.addOptional('outputDir',owner.outputDirectory_,@ischar);
                ip.addOptional('funParams',[],@isstruct);
                ip.parse(owner,varargin{:});
                outputDir = ip.Results.outputDir;
                funParams = ip.Results.funParams;
                
                % Define arguments for superclass constructor
                super_args{1} = owner;
                super_args{2} = ForceFieldCalculationProcess.getName;
                super_args{3} = @calculateMovieForceField;
                if isempty(funParams)
                    funParams=ForceFieldCalculationProcess.getDefaultParams(owner,outputDir);
                end
                super_args{4} = funParams;
            end
            
            
            obj = obj@DataProcessingProcess(super_args{:});
            
        end
        
        function status = checkChannelOutput(obj,varargin)
            
            status = logical(exist(obj.outFilePaths_{1},'file'));
            
        end
        
        function varargout = loadChannelOutput(obj,varargin)
            
            outputList = {'forceField','tMap'};
            ip =inputParser;
            ip.addRequired('obj',@(x) isa(x,'ForceFieldCalculationProcess'));
            ip.addOptional('iFrame',1:obj.owner_.nFrames_,@(x) all(obj.checkFrameNum(x)));
            ip.addOptional('iOut',1,@isnumeric);
%             ip.addOptional('iFrame',1:obj.owner_.nFrames_,@(x) ismember(x,1:obj.owner_.nFrames_));
%             ip.addParamValue('output',outputList{1},@(x) all(ismember(x,outputList)));
            ip.addParamValue('output',outputList,@(x) all(ismember(x,outputList)));
            ip.parse(obj,varargin{:})
            iFrame = ip.Results.iFrame;
            iOut = ip.Results.iOut;
            
            % Data loading
            output = ip.Results.output;
            if ischar(output), output = {output}; end
            s = load(obj.outFilePaths_{iOut},output{1});
            
%             if numel(iFrame)>1,
            varargout{1}=s.(output{1})(iFrame);
%             else
%                 varargout{1}=s.(output{1});
%             end
        end
                
        function h=draw(obj,varargin)
            % Function to draw process output
            
            outputList = obj.getDrawableOutput();
            drawLcurve = any(strcmpi('lcurve',varargin));
            rendertMap = any(strcmpi('tMap',varargin));
            if drawLcurve %Lcurve
                ip = inputParser;
                ip.addRequired('obj',@(x) isa(x,'Process'));
                ip.addParamValue('output',outputList(1).var,...
                    @(x) any(cellfun(@(y) isequal(x,y),{outputList.var})));
                ip.KeepUnmatched = true;
                ip.parse(obj,varargin{:})
                data=obj.outFilePaths_{4,1};
            elseif rendertMap % forceMap
                % Input parser
                ip = inputParser;
                ip.addRequired('obj',@(x) isa(x,'Process'));
                ip.addRequired('iChan',@isnumeric);
                ip.addRequired('iFrame',@isnumeric);
                ip.addParamValue('output',outputList(2).var,...
                    @(x) any(cellfun(@(y) isequal(x,y),{outputList.var})));
                ip.KeepUnmatched = true;
                ip.parse(obj,varargin{1:end})
                iFrame=ip.Results.iFrame;
                data=obj.loadChannelOutput(iFrame,2,'output',ip.Results.output);
                if iscell(data), data = data{1}; end
            else % forcefield
                % Input parser
                ip = inputParser;
                ip.addRequired('obj',@(x) isa(x,'Process'));
                ip.addRequired('iFrame',@isnumeric);
                ip.addParamValue('output',outputList(1).var,...
                    @(x) any(cellfun(@(y) isequal(x,y),{outputList.var})));
                ip.KeepUnmatched = true;
                ip.parse(obj,varargin{1},varargin{2:end})
                iFrame=ip.Results.iFrame;
                
                data=obj.loadChannelOutput(iFrame,1,'output',ip.Results.output);
            end
            iOutput= find(cellfun(@(y) isequal(ip.Results.output,y),{outputList.var}));
            if ~isempty(outputList(iOutput).formatData),
                data=outputList(iOutput).formatData(data);
            end
            try
                assert(~isempty(obj.displayMethod_{iOutput,1}));
            catch ME
                obj.displayMethod_{iOutput,1}=...
                    outputList(iOutput).defaultDisplayMethod();
            end
            
            % Delegate to the corresponding method
            tag = ['process' num2str(obj.getIndex) '_output' num2str(iOutput)];
            drawArgs=reshape([fieldnames(ip.Unmatched) struct2cell(ip.Unmatched)]',...
                2*numel(fieldnames(ip.Unmatched)),1);
            h=obj.displayMethod_{iOutput}.draw(data,tag,drawArgs{:});
        end
        
        function setTractionMapLimits(obj,tMapLimits)
            obj.tMapLimits_ = tMapLimits;
        end
        
        function output = getDrawableOutput(obj)
            output(1).name='Force  field';
            output(1).var='forceField';
            output(1).formatData=@(x) [x.pos x.vec(:,1)/mean((x.vec(:,1).^2+x.vec(:,2).^2).^0.5) x.vec(:,2)/mean((x.vec(:,1).^2+x.vec(:,2).^2).^0.5)];
            output(1).type='movieOverlay';
%             output(1).defaultDisplayMethod=@(x) VectorFieldDisplay('Color','r');
            output(1).defaultDisplayMethod=@(x) VectorFieldDisplay('Color',[75/255 0/255 130/255]);
            
            output(2).name='Traction map';
            output(2).var='tMap';
            output(2).formatData=[];
            output(2).type='image';
            output(2).defaultDisplayMethod=@(x)ImageDisplay('Colormap','jet',...
                'Colorbar','on','Units',obj.getUnits,'CLim',obj.tMapLimits_);
            if ~strcmp(obj.funParams_.solMethodBEM,'QR')
                output(3).name='Lcurve';
                output(3).var='lcurve';
                output(3).formatData=[];
                output(3).type='movieGraph';
                output(3).defaultDisplayMethod=@FigFileDisplay;
            end
        end
        
        
    end
    methods (Static)
        function name =getName()
            name = 'Force Field Calculation';
        end
        function h = GUI()
            h= @forceFieldCalculationProcessGUI;
        end
        function funParams = getDefaultParams(owner,varargin)
            % Input check
            ip=inputParser;
            ip.addRequired('owner',@(x) isa(x,'MovieData'));
            ip.addOptional('outputDir',owner.outputDirectory_,@ischar);
            ip.parse(owner, varargin{:})
            outputDir=ip.Results.outputDir;
            
            % Set default parameters
            funParams.OutputDirectory = [outputDir  filesep 'forceField'];
            funParams.YoungModulus = 8000;
            funParams.PoissonRatio = .5;
            funParams.method = 'FastBEM';
            funParams.meshPtsFwdSol = 4096;
            funParams.regParam=1e-4;
            funParams.solMethodBEM='1NormReg';
            funParams.basisClassTblPath='';
            funParams.LcurveFactor=10;
            funParams.thickness=34000;
            funParams.useLcurve=true;
        end
        function units = getUnits(varargin)
            units = 'Traction (Pa)';
        end
    end
end