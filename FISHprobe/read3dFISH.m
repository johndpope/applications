function [imageData, dataProperties] = read3dFISH()
%READ3DFISH Reads microscope images and give imagedata 3D stach with data
%properties
%   Input(optional): pathName

%   Output: imageData: Multichannel 3D stack (for findNuclei.m)
%           dataProperties (for singleNucleusSpotDetection.m)
% 
% 03/2016 Ning
% 
% p = inputparser;
% p.addOptional('history', '', @ischar);

autoloadBioFormats = 1;
% load the Bio-Formats library into the MATLAB environment
status = bfCheckJavaPath(autoloadBioFormats);
assert(status, ['Missing Bio-Formats library. Either add bioformats_package.jar '...
    'to the static Java path or add it to the Matlab path.']);


% load history
if ~isdeployed
    historyFile = fullfile( fileparts(mfilename('fullpath')),'imagePathHistory.mat' );
    if exist(historyFile, 'file')
        history = load(historyFile);
        pathName = history.pathName;
        [fileName, pathName] = uigetfile(bfGetFileExtensions, 'Select the file contaning multichannel 3D stack', pathName);
    else
        [fileName, pathName] = uigetfile(bfGetFileExtensions, 'Select the file contaning multichannel 3D stack');
    end

% save history
    if ~isempty(pathName) && all(pathName ~= 0)
        historyFile = fullfile(fileparts( mfilename('fullpath') ), 'imagePathHistory.mat' );
        save( historyFile, 'pathName' );
    end
end
    
dataFilePath = fullfile( pathName, fileName );
MD = MovieData.load(dataFilePath);
% reader = MD.getReader();

% Define dataProperties parameters
% Pixelsize is in um
dataProperties.filePath = pathName;
dataProperties.fileName = fileName;
dataProperties.PIXELSIZE_XY = MD.pixelSize_/1000;
dataProperties.PIXELSIZE_Z = MD.pixelSizeZ_/1000;
dataProperties.imSize = MD.imSize_;
dataProperties.nDepth = MD.zSize_;
dataProperties.NA = MD.numAperture_;

lenseType = input('Enter lense type (air, water or oil) > ', 's');
switch lenseType
    case 'air'
        dataProperties.refractiveIndex = 1;
    case 'water'
        dataProperties.refractiveIndex = 1.33;
    case 'oil'
        dataProperties.refractiveIndex = 1.51;
end
% sigmaCorrection defined by default
dataProperties.sigmaCorrection=[1 1];


for i = 1:numel(MD.channels_)
    prompt = sprintf('Enter the name (dapi, green or red) of channel %d > ', i);
    dataProperties.channel(i).name = input(prompt,'s');
    channel = MD.getChannel(i);
    dataProperties.channel(i).emissionWavelength = channel.emissionWavelength_/1000;
    dataProperties.channel(i).excitationWavelength = channel.excitationWavelength_/1000;
    dataProperties.channel(i).psfSigma = channel.psfSigma_;
    % Get frame size of a single channel then load 3D stack for all frames
    nFrameCha = channel.getReader().getSizeT;
    
    % How to use input value as new variable name?
    switch dataProperties.channel(i).name
        case 'dapi'
            imageData.dapi = channel.loadStack(nFrameCha);            
        case 'green'
            imageData.green = channel.loadStack(nFrameCha);            
        case 'red'
            imageData.red = channel.loadStack(nFrameCha);
    end
end

% clear

end

