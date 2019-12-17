%% check matlab version, toolboxes, add paths
% check matlab version
if datenum(version('-date')) < datenum('March 5, 2015')
    error(['This code will probably NOT function with versions '...
        'of Matlab older than 2015a (ish)'])
end

% check optimization toolbox
find_optim = which('lsqnonlin');
if isempty(find_optim)
    error('Matlab function lsqnonlin not found, you likely do not have optimization toolbox installed. Please re-install matlab with this toolbox.');
end

gannet_git_dir = pwd; % you may want to replace this with the location of the UNR_Gannet.git folder

% add paths
addpath(genpath(fullfile(gannet_git_dir,'Gannet3.1-master')))
addpath(genpath(fullfile(gannet_git_dir,'dicm2nii')))
warning('Gannet 3.1 uses SPM12. This means you cannot have SPM8 code in your matlab path. If you encounter errors with SPM, see comments for an example for how to remove SPM8 from the path.')
% rmpath(genpath('C:\Users\mpschallmo\Google Drive\MatlabCode\spm8'))
addpath(genpath(fullfile(gannet_git_dir,'spm12')),'-END') % add this at the end of the path, because spm duplicates some matlab function names which is NOT GREAT

%% set up, convert anatomical data
data_dir = 'PATH_TO_YOUR_DATA'; % path to main directory, you will need to edit this
cd(data_dir)

subj_and_session = '20191003'; % subject and session #, you will need to edit this
anat_name = 'MPRAGE_8_ISO_2_AVERAGES_0011'; % anatomy file name, you will need to edit this
anat_dcm = fullfile(data_dir, anat_name);
anat_path = fullfile(data_dir,'3danat');

if ~exist(anat_path,'dir')
    mkdir(anat_path)
end

anat_nii = fullfile(anat_path,[anat_name(1:end-5) '.nii']);

if ~exist(anat_nii,'file')
    dicm2nii(anat_dcm, anat_path, 'nii')
end

%% run Gannet 

MRS_Directories = str2mat('GABA folder 1','GABA folder 2','etc.'); 
% list of folder names to batch process, each containing GABA & water data

for iF = 1:size(MRS_Directories,1)

    % get file names
    mrs_dir = fullfile(data_dir,squeeze(MRS_Directories(iF,:)));
    cd(mrs_dir)

    GABA_file = '*WATER_SAT*.dat';
    GABA_file_name = dir(GABA_file);
    
    H2O_file = '*ONLY_RF_OFF*.dat';
    H2O_file_name = dir(H2O_file);
    
    % Gannet Load
    MRS_data = GannetLoad({GABA_file_name(1).name}, {H2O_file_name(1).name});
    save(fullfile(mrs_dir,'GannetLoad_output',['GannetData_' ...
        datestr(now,'yyyymmdd')]), 'MRS_data')
    
    % Gannet Fit
    MRS_data = GannetFit(MRS_data);
    save(fullfile(mrs_dir,'GannetFit_output',['GannetData_' ...
        datestr(now,'yyyymmdd')]), 'MRS_data')
        
    % Gannet CoRegister
    MRS_data = GannetCoRegister(MRS_data, {anat_nii});
    save(fullfile(mrs_dir,'GannetCoRegister_output',['GannetData_' ...
        datestr(now,'yyyymmdd')]), 'MRS_data')
    
    % Gannet Segment
    disp('Running GannetSegment, this may take a while if this anatomy has not yet been segmented in SPM...')
    MRS_data = GannetSegment(MRS_data);
    save(fullfile(mrs_dir,'GannetSegment_output',['GannetData_' ...
        datestr(now,'yyyymmdd')]), 'MRS_data')
    
    % Gannet Quantify
    MRS_data = GannetQuantify(MRS_data);
    save(fullfile(mrs_dir,'GannetQuantify_output',['GannetData_' ...
        datestr(now,'yyyymmdd')]), 'MRS_data')
    
    MRS_struct{iF} = MRS_data; % output a single structure with data from all GABA scans being processing
    
    disp('Any key to continue.')
    pause
end

    