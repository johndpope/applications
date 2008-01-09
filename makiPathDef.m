function pathOrId = makiPathDef(pathOrId,serverType)
%MAKIPATHDEF contains path definitions for relative paths for the maki project
%
% SYNOPSIS: pathOrId = makiPathDef(pathOrId,serverType)
%
% INPUT pathOrId: path that should be converted into
%                 $IDENTIFIER/rest/of/path, or $IDENTIFIER/rest/of/path
%                 that should be converted into /a/real/path   
%                 Supported identifiers
%                 $HERCULES - root path where the movies on hercules are
%                             stored (works for linux or windows) - deleted
%                             for now to allow use of movies analyzed in
%                             Woods Hole.
%                 $TESTDATA - D:\makiTestData on windows and HOME/testdata
%                             on linux
%                 $DANUSER, $MERLADI, $SWEDLOW, $MCAINSH
%       serverType: 'TEST','HERCULES','DANUSER','MERALDI',SWEDLOW' or
%       'MCAINSH'
%       if pathOrId is empty or omitted, makiPathDef returns the current
%       path definition
%
% OUTPUT converted input
%
% REMARKS pathes must not end in a filesep
%
% created with MATLAB ver.: 7.4.0.287 (R2007a) on Windows_NT
%
% created by: jdorn, kjaqaman
% DATE: 05-Jul-2007
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% assign path or ID

% load path list
pathList = loadPathList(serverType);

% check empty input
if nargin == 0 || isempty(pathList)
    pathOrId = pathList;
    return
end

% check input for $IDENTIFIER
tok = regexp(pathOrId,'^(\$\w+)','tokens');
if isempty(tok)
    % no Id
    isId = false;
else
    % replace full path with identifier
    tok = tok{1};
    tok = tok{1};
    isId = true;
    restOfPath = pathOrId(length(tok)+1:end);
    pathOrId = tok;
    
    % check for wrong fileseps
    fsIdx = regexp(restOfPath,'\\|/');
    restOfPath(fsIdx) = filesep;
end



% look up pathOrId
if isId
    % check identifiers
    pathIdx = strmatch(pathOrId,pathList(:,1));
    
    if isempty(pathIdx)
        warning('MAKIPATHDEF:NOMATCH','identifier %s not found',pathOrId);
    else
        % construct path
        if ispc
            pathOrId = fullfile(pathList{pathIdx,2},restOfPath);
        else
            pathOrId = fullfile(pathList{pathIdx,3},restOfPath);
        end
    end
    
else
    % check for paths. Loop, because we can't match a long string to many
    % short ones easily
    nPaths = size(pathList,1);
    
    done = false;
    ct = 0;
    pcIdx = isunix+2;
    while ~done && ct<nPaths
        ct = ct+1;
        match = strmatch(pathList{ct,pcIdx},pathOrId);
        if ~isempty(match)
            % replace matched path
            pathOrId = [pathList{ct,1},...
                pathOrId(length(pathList{ct,pcIdx})+1:end)];
            done = true;
        end
    end
    if ~done
        warning('MAKIPATHDEF:NOMATCH','no path matches %s',pathOrId)
    end
    
end



%% subfunction

function pathList = loadPathList(serverType)

%Input: 
%       serverType: 'TEST','HERCULES','DANUSER','MERALDI',SWEDLOW' or
%       'MCAINSH'


homeUser = getenv('HOME');

% pathList is {id, winPath, linuxPath}
if strcmp(serverType,'TEST')
    pathList = {'$TESTDATA','D:\makiTestData',[homeUser '/testData']};
elseif strcmp(serverType,'HERCULES')
    pathList = {'$HERCULES','O:','/hercules'};
elseif strcmp(serverType,'DANUSER')
    pathList = {'$DANUSER','O:','/mnt/dundee'};
elseif strcmp(serverType,'MERALDI')
    pathList = {'$MERALDI','O:',''};
elseif strcmp(serverType,'MCAINSH')
    pathList = {'$MCAINSH','O:',''};
elseif strcmp(serverType,'PORTER')
    pathList = {'$PORTER','O:\iainp',''};
elseif strcmp(serverType,'KING')
    pathList = {'$PORTER','O:\eking',''};
elseif strcmp(serverType,'POSCH')
    pathList = {'$POSCH','O:\mposch',''};
end    

