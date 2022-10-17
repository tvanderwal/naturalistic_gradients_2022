% GRADIENT_PIPELINE loads CIFTI and motion (MCFLIRT par) files, performs (optional) scrubbing,
% data parcellation (optional), and computes individual/group-level connectivity matrices and gradient
% embeeddings
%
% Combines data across runs (within-condition), allows for computing
% gradients with successive amounts of data ('increment')
%
% SurveyBott, 2022
function sub = gradient_pipeline(varargin)
% setup inputs
p = inputParser;
p.addParameter('dataDir','/arc/project/st-tv01-1/hcp/data-clean',@isfolder);
p.addParameter('motionDir','/arc/project/st-tv01-1/hcp/motion',@isfolder);
p.addParameter('outDir',[]);
p.addParameter('outSuffix','');
p.addParameter('gradient',true);
p.addParameter('scrub',true);
p.addParameter('parc','schaefer');
p.addParameter('res',1000);
p.addParameter('saveIndiv',true);
p.addParameter('saveConn',false)
p.addParameter('saveGroup',false);
p.addParameter('includeSub',[],@isnumeric); % list of subjects to include
p.addParameter('runCond',{'MOVIE','REST'});
p.addParameter('runN',1:4);
p.addParameter('runMaxVols',[]); % maximum number of volumes per run
p.addParameter('increment',[]); % # of volumes to successively add (multiple gradients)
p.parse(varargin{:});
inputs = p.Results;

%% create 'sub' struct - find motion and cifti files
% get cifti files, extract info, include based on inputs
files.cifti = dir(fullfile(inputs.dataDir,'*','*.nii'));
for i=1:numel(files.cifti)
    cifti(i) = hcp_fileparts(files.cifti(i));
end
if ~isempty(inputs.includeSub)
   cifti = cifti(ismember([cifti.sub],inputs.includeSub)); 
end
% get unique subjects, reorg by subject, add motion
subId = unique([cifti.sub]);
cond = unique({cifti.condition});
for i=1:numel(subId)
   sub(i).id = subId(i);
   for j=1:numel(cond)
      sub(i).(cond{j}) = cifti(ismember([cifti.sub],subId(i)) & ismember({cifti.condition},cond{j}));
      if numel(sub(i).(cond{j})) ~= 1 
          fprintf('sub-%d\t%s\t%d CIFTI files\n',sub(i).id,cond{j},numel(sub(i).(cond{j})));
      else
          % find match fd.1D file
          sub(i).(cond{j}).fdFile = [];
          fd_file = dir(fullfile(inputs.motionDir,sprintf('%d*',sub(i).id),sprintf('*%s*.1D',cond{j})));
          if numel(fd_file) ~= 1
              fprintf('sub-%d\t%s\t%d motion (fd.1D) files\n',sub(i).id,cond{j},numel(fd_file));
          else
              sub(i).(cond{j}).fdFile = fullfile(fd_file.folder,fd_file.name);
              % scrub
              if startsWith(lower(cond{j}),'movie')
                  scrubCond = cond{j};
              else
                  scrubCond = '';
              end
              [sub(i).(cond{j}).scrub, sub(i).(cond{j}).fd] = gradient_tools.pipeline.motion_scrubbing(sub(i).(cond{j}).fdFile,'run',scrubCond,...
                  'thresh',0.30,'scrubBefore',1,'scrubAfter',2);
              sub(i).(cond{j}).vols = sum(~sub(i).(cond{j}).scrub);
          end
      end

   end
end
% remove runs not requested
if ~isempty(inputs.runN)
    rm_cond = ~ismember(cellfun(@str2num,regexprep(cond,inputs.runCond,'')),inputs.runN);
    sub = rmfield(sub,cond(rm_cond));
end
cond = fieldnames(sub);
cond(ismember(cond,'id')) = [];

%% scrub motion, crop timepoints to match across runs
if inputs.scrub
for i=1:numel(sub)
    vols.movie = [];
    vols.rest = [];
    for j=1:numel(cond)
        try
            vols.(lower(cond{j}(1:end-1)))(str2double(cond{j}(end))) = sub(i).(cond{j}).vols;
        catch
            error('sub-%d missing %s data',sub(i).id,cond{j});
        end
    end
    vols.delta = vols.rest - vols.movie;
    if any(vols.delta < 0) 
        % more movie in one or more runs
        if sum(vols.delta) < 0
            error('sub-%d more movie vols than rest across runs',sub(i).id);
        else
            % calculate extra vols to add in to rest to account for movie > rest
            extraMovie = abs(sum(vols.delta(vols.delta < 0)));
            restAdd = zeros(size(vols.delta));
            restAdd(vols.delta >=0) = diff(round(linspace(0,extraMovie,sum(vols.delta >= 0)+1)));
            for j=1:numel(vols.delta)
                if vols.delta(j) > 0
                    % remove rest volumes from rest > movie, and add back in extra necessary to match across runs
                    restCond = sprintf('REST%d',j);
                    goodVols = find(~sub(i).(restCond).scrub);
                    sub(i).(restCond).scrub(goodVols(end-(vols.delta(j)-restAdd(j))+1:end)) = 1;
                    sub(i).(restCond).vols = sum(~sub(i).(restCond).scrub);
                end
            end
        end
    else
        % run-wise elimination of rest vols to match movie
        for j=inputs.runN
            restCond = sprintf('REST%d',j);
            goodVols = find(~sub(i).(restCond).scrub);
            sub(i).(restCond).scrub(goodVols(end-vols.delta(j)+1:end)) = 1;
            sub(i).(restCond).vols = sum(~sub(i).(restCond).scrub);
        end
    end
end
end

%% run gradients - rest and movie per subject
runs = fieldnames(rmfield(sub,'id'));
condition = unique(cellfun(@(x) x(1:end-1),runs,'UniformOutput',0)); % should just be MOVIE and REST
if ~isempty(inputs.runCond)
    condition = intersect(condition,inputs.runCond);
    if isempty(condition)
       error('''runCond'' not found');
    end
end
if ~isempty(inputs.outDir) && ~isfolder(inputs.outDir)
    mkdir(inputs.outDir);
end
for i=1:numel(condition)
    fprintf('%s\n',condition{i});
    grp_conn = [];
    grp_n = [];
    parfor j=1:numel(sub)
        fprintf('\t%d/%d\tsub-%d\n',j,numel(sub),sub(j).id);
	    % aggregate cifti files and scrubbing timecourses
        cifti = {};
        scrub = [];
        r = sort(runs(startsWith(runs,condition{i})));
        for k=1:numel(r)
            cifti{k} = sub(j).(r{k}).file;
            run_scrub = sub(j).(r{k}).scrub;
            if ~isempty(inputs.runMaxVols)
                good_tpts = find(~run_scrub,inputs.runMaxVols+1);
                if numel(good_tpts) >= inputs.runMaxVols
                    run_scrub(good_tpts(end):end) = true;
                else
                    % not enough timepoints
                end
            end
            scrub = [scrub run_scrub];
        end
        % run (and save)
        out = gradient_tools.pipeline.individual_gradient(cifti,'parc',inputs.parc,'res',inputs.res,'scrubVols',scrub,'gradient',inputs.gradient,'increment',inputs.increment);
        if ~isempty(inputs.outDir) && inputs.saveIndiv
            filename = fullfile(inputs.outDir,sprintf('%d_%s%s.mat',sub(j).id,condition{i},inputs.outSuffix));
            save_gradient(out,filename,inputs.saveConn);
        end
        if inputs.saveGroup
            idx = ~isnan(out.conn);
            out.conn = atanh(out.conn);
            out.conn(~idx) = 0;
            if j==1
                grp_conn = out.conn;
                grp_n = idx;
            else
                grp_conn = grp_conn + out.conn;
                grp_n = grp_n + idx;
            end
        end
    end
    if ~isempty(inputs.outDir) && inputs.saveGroup
        grp_conn = tanh(grp_conn ./ grp_n);
        grp_conn(abs(grp_conn)==Inf) = NaN;
        filename = fullfile(inputs.outDir,sprintf('group_%s_n%d.mat',condition{i},n));
        save(filename,'grp_conn','grp_n','-v7.3');
    end
end
end
function save_gradient(out,filename,saveConn)
if ~saveConn
   out.conn = []; 
end
save(filename,'out');
end
function parts = hcp_fileparts(file,varargin)
% setup inputs
p = inputParser;
p.parse(varargin{:});
inputs = p.Results;
% extract file parts
if isstruct(file)
    parts.file = fullfile(file.folder,file.name);
    parts.folder = file.folder;
    parts.name = file.name;
    [~,parts.name,parts.ext] = fileparts(parts.name);
else
    parts.file = file;
    [parts.folder, parts.name, parts.ext] = fileparts(file);
end
% get subject id (if path)
[~,parts.sub] = fileparts(parts.folder);
parts.sub = str2double(regexprep(parts.sub,'_7T',''));
% get specific info from filename
s = strsplit(parts.name,'_');
parts.type = s{1};
parts.condition = s{2};
parts.phase = s{4};
parts.suffix = s{end};
end
