function [I0,sDN,GaussRatio]=fsmCalcNoiseParam(firstfilename,bitDepth,sigma)
% fsmCalcNoiseParam calculates three parameters for the noise model applied to speckle selection
%
% Run this funtion on a background region (non-speckled) cropped from an image stack 
% (use cropStack for this purpose). 
% fsmCalcNoiseParam returns the mean backgroung intensity (I0), the mean standard deviation
% (sDN) and GaussRatio, which indicates how well the dark noise of the camera approximates 
% a normal distribution. More precisely, GaussRatio corresponds to the ratio:
%
%                                std(background image)
%                           -------------------------------,
%                            std(low-pass filtered image)
%
% where 'low-pass filtered image' is the result of the convolution of the image with a 
% Gaussian kernel with standard deviation = sigma.
%
% SYNOPSIS [I0,sDN,GaussRatio]=fsmCalcNoiseParam(firstfilename,bitDepth,sigma)
%
% INPUT    firstfilename: name of the first file with complete path;
%                         pass firstfilename=[] for selecting the file
%                         through an open dialog
%          bitDepth     : bit depth of the camera for normalization
%          sigma        : sigma for the gaussian kernel
%
% OUTPUT   I0           : average intensity
%          sDN          : average standard deviation (sigmaDarkNoise)
%          GaussRatio   : ratio std(image)/std(filtered_image)
%
% REMARK   fsmCalcNoiseParam loads all the selected images into memory. For this reason, 
%          adapt image number and size to your machine's amount of memory.

% Initialize return values
I0=0; sDN=0; GaussRatio=0;

% Store current directory
currDir=cd;

% Select first file from an open dialog if firstfilename was not passed as
% an input parameter
if isempty(firstfilename)
    
    % First image
    [fName,dirName] = uigetfile('*.tif','Select first image');
    if(isa(fName,'char') & isa(dirName,'char'))
        firstfilename=[dirName,fName];
    else
        % Return 0 values
        return
    end
    
else
    % Get information from firstfilename 
    [dirName,fname,fno,fext]=getFilenameBody(firstfilename);
    
end

% Change to dirName
cd(dirName);

% Check selected bit depth
info=imfinfo(firstfilename);
selBitDepth=num2str(bitDepth);
imgBitDepth=num2str(info.BitDepth);

if (bitDepth==8 & info.BitDepth>8) | (bitDepth>8 & info.BitDepth==8)
    strDlg=['The image bit depth is ',imgBitDepth,'. You selected ',selBitDepth,'. Please specify again the bit depth you intend to use.'];
    button = questdlg(strDlg, 'Please specify bit depth',selBitDepth,imgBitDepth,'Other',imgBitDepth);
    if strcmp(button,selBitDepth), % No change
    elseif strcmp(button,imgBitDepth),bitDepth=info.BitDepth;
    elseif strcmp(button,'Other'),
        uiwait(msgbox('Please specify the new bit depth in the corresponding field in fsmCenter and restart the calibration.','Please restart calibration...','modal'));    
        return
    end
end

% Normalization boundaries
mx=2^bitDepth-1;
mn=0;

% Check for border effect
if 2*(2*sigma+1)>min([info.Width info.Height])
    disp('The intensity drop at the borders generated by the filtering biases pixel intensities');
    disp('throughout the whole image. Please select larger image or smaller sigma.');
    I0=0;sDN=0;GaussRatio=0;
    return;
end

% Get file names
outFileList=getFileStackNames(firstfilename);
n=length(outFileList);

% The user can decide the number of images to be cropped
prompt={'Specify the number of images to be used for calibration (the higher the better).'};
dlg_title='User input requested';
num_lines=1;
def={num2str(n)};
answer=fix(str2num(char(inputdlg(prompt,dlg_title,num_lines,def))));

% Check the selected number
if isempty(answer)
    disp('Aborting.\n');
    return
end

if answer<1 | answer>n
    fprintf(1,'Invalid number of images specified. Using the default value (%d).\n',answer);
else
    % Crop outFileList
    n=answer;
    outFileList=outFileList(1:n);
end

% Load the n selected images from the stack into memory -- this may require a lot of memory
fprintf(1,'Loading stack...');
stack=imreadstack(firstfilename,n);
fprintf(1,' Done!\n');

% Normalize stack
stack=(stack-mn)/(mx-mn);

% Mean
I0=mean(stack(:));

% Standard deviation
S=std(stack,1,3);

% Get a mean value for the standard deviation over time
sDN=mean(S(:));

%
% Calculate GaussRatio
%
% Calculate how many pixels have to be cropped from the borders
border=2*fix(sigma)+1;

% Initialize vector
L=size(stack,3);
GaussRatios=zeros(1,L);

h=waitbar(0,'Calculating Gaussian ratio');
% Calculate all ratios
for i=1:L
    % Get current image
    rImg=stack(:,:,i);
    % Filter it with user-input sigma
    fImg=Gauss2D(rImg,sigma);
    % Crop border
    rImg=rImg(border:end-border+1,border:end-border+1);
    fImg=fImg(border:end-border+1,border:end-border+1);
    % Calculate current ratio
    GaussRatios(i)=std(rImg(:))/std(fImg(:));
    % Update waitbar
    waitbar(i/L,h);
end

% Close waitbar
close(h);

% Calcaulate GaussRatio as the mean of the vector GaussRatios
GaussRatio=mean(GaussRatios);

fprintf(1,'\nTo add this experiment to your database:\n');
fprintf(1,'(1) Click on ''Edit experiment parameters'' in fsmCenter.\n');
fprintf(1,'(2) Copy/paste this record at the end of your experiment settings file.\n');
fprintf(1,'(3) Edit the LABEL and DESCRIPTION fields.\n');
fprintf(1,'-------------------------------------------------------------------\n');
fprintf(1,'LABEL\t\t\t"Please change this"\n');
fprintf(1,'DESCRIPTION\t\t"Please change this"\n');
fprintf(1,'BIT DEPTH\t\t"%s"\n',num2str(bitDepth));
fprintf(1,'NOISE PARAMS\t"%1.8f 2e-4 %1.8f"\n',sDN,I0);
fprintf(1,'GAUSS RATIO\t\t"%1.2f"\n',GaussRatio);
fprintf(1,'#\n');
fprintf(1,'-------------------------------------------------------------------\n');
fprintf(1,'(Don''t forget the ''#'')\n');

% Back to old directory
cd(currDir);
