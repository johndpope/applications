function [projList]=combineProjListFiles(saveResult)
% combineProjListFiles allows selection of multiple projList files to combine

% SYNOPSIS: [projList]=combineProjListFiles(saveResult)
%
% INPUT   : saveResult: 1 to save new projList file, 0 to return it to
%                       workspace only
% OUTPUT  : projList  : see getProj.m for details
%
% 2009/08 - Kathryn Applegate, Matlab R2008a

if nargin<1
    saveResult=0;
end

projList=[];
temp=[];
userEntry='Yes';
while strcmp(userEntry,'Yes')
    [fileName,pathName] = uigetfile('*.mat','Select projList.mat file');
    if fileName==0
        msgbox('No projects selected.')
        return
    end
    load([pathName filesep fileName]);
    temp=[temp; projList];
    disp(['Selected: ' pathName fileName])
    userEntry = questdlg('Select another projList.mat file?');
end
clear projList;
projList=temp;

% format imDir and anDir paths for current OS
nProj=length(projList);
curDir=pwd;
temp1=cellfun(@(x) formatPath(projList(x,1).anDir),mat2cell([1:nProj]',ones(nProj,1),1),'uniformOutput',0);
temp2=cellfun(@(x) formatPath(projList(x,1).imDir),mat2cell([1:nProj]',ones(nProj,1),1),'uniformOutput',0);
projList=cell2struct([temp1 temp2],{'anDir','imDir'},2);
cd(curDir)

if saveResult==1
    temp=inputdlg({'Enter file name:'},'',1);
    dirName=uigetdir(pwd,'Select output directory.');
    save([dirName filesep temp{1}],'projList')
end