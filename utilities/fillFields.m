function fillFields(handles,activeJob)
% fillFields writes all values within activejob into the right place in
% the PolyTrack GUI
%
% SYNOPSIS       fillFields(handles,activeJob)
%
% INPUT          handles : structure with all the information of PolyTrack
%                         (GUI)
%                activeJob : structure with information specific for a
%                            certain job (of the list in PolyTrack)
%
% OUTPUT         none
%
% DEPENDENCIES   ptFillFields uses {nothing}
%                                  
%                ptFillFields is used by { PolyTrack }
%
% Colin Glass, Feb 04         


% All this program does, is fill values into the respective fields of the
% PolyTrack (GUI).
set(handles.GUI_st_path_imagedirectory_ed,'String',activeJob.imagedirectory);
set(handles.GUI_st_path_imagename_ed,'String',activeJob.imagename);
set(handles.GUI_st_path_firstimage_ed,'String',num2str(activeJob.firstimage));
set(handles.GUI_st_path_lastimage_ed,'String',num2str(activeJob.lastimage));
set(handles.GUI_st_path_increment_ed,'String',num2str(activeJob.increment));
set(handles.GUI_st_path_savedirectory_ed,'String',activeJob.savedirectory);

set(handles.GUI_st_iq_fi_background_ed,'String',num2str(activeJob.fi_background,'%6.5f'));
set(handles.GUI_st_iq_fi_nucleus_ed,'String',num2str(activeJob.fi_nucleus,'%6.5f'));
set(handles.GUI_st_iq_fi_halolevel_ed,'String',num2str(activeJob.fi_halolevel,'%6.5f'));
set(handles.GUI_st_iq_la_background_ed,'String',num2str(activeJob.la_background,'%6.5f'));
set(handles.GUI_st_iq_la_nucleus_ed,'String',num2str(activeJob.la_nucleus,'%6.5f'));
set(handles.GUI_st_iq_la_halolevel_ed,'String',num2str(activeJob.la_halolevel,'%6.5f'));

set(handles.GUI_st_bp_maxsearch_ed,'String',num2str(activeJob.maxsearch));
set(handles.GUI_st_bp_minsize_ed,'String',num2str(activeJob.minsize));
set(handles.GUI_st_bp_maxsize_ed,'String',num2str(activeJob.maxsize));
set(handles.GUI_st_bp_minsdist_ed,'String',num2str(activeJob.minsdist));

set(handles.GUI_st_eo_minedge_ed,'String',num2str(activeJob.minedge));
set(handles.GUI_st_eo_sizetemplate_ed,'String',num2str(activeJob.sizetemplate));
set(handles.GUI_st_eo_mintrackcorrqual_ed,'String',num2str(activeJob.mintrackcorrqual));

set(handles.GUI_st_eo_mincorrqualtempl_pm,'String',num2str(activeJob.mincorrqualtempl));
set(handles.GUI_st_eo_noiseparameter_pm,'String',num2str(activeJob.noiseparameter));
set(handles.GUI_st_eo_leveladjust_pm,'String',num2str(activeJob.leveladjust));

set(handles.GUI_st_eo_clustering_rb,'Value',activeJob.clustering);
set(handles.GUI_st_eo_minmaxthresh_rb,'Value',activeJob.minmaxthresh);

set(handles.GUI_st_path_timeperframe_ed,'String',num2str(activeJob.timeperframe));

% Set the microm-to-pixel popup menu
if ~isempty(activeJob.mmpixel)
   set(handles.GUI_st_bp_mmpixel_pm,'Value',num2str(activeJob.mmpixel));
end

% Set the timestep slide popup menu
if ~isempty(activeJob.timestepslide)
   set(handles.GUI_st_eo_timestepslide_pm,'Value',activeJob.timestepslide_index);
end

% Set the bitdepth field
if ~isempty(activeJob.timestepslide)
   set(handles.GUI_st_bitdepth_pm,'Value',activeJob.bitdepth_index);
end
