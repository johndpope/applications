function [slist, movie]=autospfinder(movie,process,verbose,dataProperties)
%AUTOSPOTFIND call spfind on file or on moviematrix
%
% SYNOPSIS s[slist]=autospfinder(movie,process,verbose,dataProperties)
%
% INPUT movie   : either movie stack or filename. if empty string is given, a filedialog is opened
%       process : (optional) vector with processes (default: [1 2 3])
%                 1 = filter movie
%                 2 = find spots
%                 3 = find overlaps
%       verbose : if true additional info is printed during process
%       dataProperties: structure generated by analyzeMoviesGUI
%       
% OUTPUT slist : structure list of spots 
%
% NOTE: autospfind writes several outputfiles at the current working directory

%c: 10/08/01 dT

    %global PIXELSIZE_XY PIXELSIZE_Z FT_SIGMA PATCHSIZE TIMEPTS_IN_MEM FILTERPRM ...
    %    CH_MAXSLOPE CH_MAXNUMINTERV OVERLPSIZE MAXSPOTS F_TEST_PROB T_TEST_PROB;

if nargin <4 | isempty(dataProperties)
    %load_sp_constants;
    error('Missing dataProperties');
else
    
    PIXELSIZE_XY=dataProperties.PIXELSIZE_XY;
    PIXELSIZE_Z=dataProperties.PIXELSIZE_Z;
    FILTERPRM=dataProperties.FILTERPRM;
    PATCHSIZE=dataProperties.PATCHSIZE;
    CH_MAXNUMINTERV=dataProperties.CH_MAXNUMINTERV;
    OVERLPSIZE=dataProperties.OVERLPSIZE;
    FT_SIGMA=dataProperties.FT_SIGMA;
    TIMEPTS_IN_MEM=dataProperties.split.TIMEPTS_IN_MEM;
    CH_MAXSLOPE=dataProperties.CH_MAXSLOPE; 
    MAXSPOTS=dataProperties.MAXSPOTS;       
    F_TEST_PROB=dataProperties.F_TEST_PROB;    
    T_TEST_PROB=dataProperties.T_TEST_PROB;    
    
end


starttime=1;
slist=[];
cord=[];
savename='filtered_movie_';
savename=[savename, dataProperties.name,'.fim'];

%check input arguments
if nargin<2 | isempty(process)
    process=1:3;
end;


%non verbose (default)
if nargin<3 | isempty(verbose)
    verbose=0;
end;


%if we have a string load first part
if ischar(movie)
    %read movie
    if strcmp(movie(end-3:end),'.r3c')
        %cropped movie
        fname = movie;
        movie  =  readmat(fname,starttime:starttime+TIMEPTS_IN_MEM);
        nextSwitch = 'r3c';
    else
        %normal movie
        [movie fname]=r3dread(movie,starttime,TIMEPTS_IN_MEM);
        nextSwitch = 'r3d';
    end
    
else
    nextSwitch = 'none';
end;


nextmovie=movie;

while ~isempty(nextmovie)
    movie=nextmovie;
    % filter movie
    if any(process==1)
        fmov=filtermovie(movie,FILTERPRM);
    else
        fmov =movie;
    end;

    % find spots
    if any(process==2)
        [cord,mnp] = spotfind(fmov,dataProperties);
    end;

    % find overlapping spots
    if any(process==3)
        cord=findoverlap(movie,cord,dataProperties);
    end;

    
    
    slist=[slist cord];
    %read next part if exists
    starttime=starttime+TIMEPTS_IN_MEM;
    switch nextSwitch
        case 'r3d'
            nextmovie=r3dread(fname,starttime,TIMEPTS_IN_MEM);
        case 'r3c'
            nextmovie = readmat(fname,starttime:starttime+TIMEPTS_IN_MEM);
        case 'none'
            nextmovie = [];
    end
    if verbose
        starttime
    end;
end;

%export spots to file and standard output
%fstat= savespots('spots',slist,3); %save to file not needed
movie=fmov;

%only save slist if there is any
if any(process == 3)
    save(['slist-',nowString],'slist');
end
%write filtered part only if filtering has been done
if any(process==1)
    writemat(savename,fmov);
end