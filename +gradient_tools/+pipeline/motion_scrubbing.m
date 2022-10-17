function [rm, fd] = motion_scrubbing(fd,varargin)
p = inputParser; 
p.addRequired('fd',@(x) isnumeric(x) || exist(x,'file'));
p.addParameter('run',[],@ischar);
p.addParameter('thresh',0.30); % threshold for high motion volumes
p.addParameter('scrubBefore',1);
p.addParameter('scrubAfter',2);
p.addParameter('verbose',false);
p.parse(fd,varargin{:});
inputs = p.Results;
inputs.run = lower(inputs.run);

% load fd if necessary
if ~isnumeric(fd)
   fd = load(fd); 
end
% fd is a 1D array, make row vector, add '0' to make full length
if size(fd,1) > size(fd,2)
   fd = fd'; 
end
fd = [0 fd];
rm = false(size(fd));
% scrub bad volumes
rm = rm | fd > inputs.thresh;

% scrub volumes around bad volumes (scrub before and scrub after)
before = false(size(rm));
for i=1:inputs.scrubBefore
    before = before | [rm(i+1:end) false(1,i)];
end

after = false(size(rm));
for i=1:inputs.scrubAfter
    after = after | [false(1,i) rm(1:end-i)];
end
if inputs.verbose
    fprintf('%d vols > %.2fmm\t%d before\t%d after\n',sum(rm),inputs.thresh,sum(before),sum(after));
end
rm = rm | before | after;
if inputs.verbose
    fprintf('%d/%d vols (%.0f%%) scrubbed\n',sum(rm),numel(rm),sum(rm)*100/numel(rm));
end

% load pre-defined volumes to remove
if ~isempty(inputs.run)
    mat = fullfile(fileparts(mfilename('fullpath')),'data','run_volumes.mat');
    load(mat); % this loads ''volumes'' with each run a field
    % run specific removal of predetermined volumes
    if startsWith(inputs.run,'movie')
        if numel(rm) ~= numel(volumes.(inputs.run))
            error('Number of volumes (%d) doesn''t match run (%s, %d)',numel(rm),inputs.run,volumes.(inputs.run));
        end
        rm = rm | volumes.(inputs.run);
    elseif startsWith(inputs.run,'rest')
        movie_rm = volumes.(regexprep(inputs.run,'rest','movie'));
        rm = rm | movie_rm(1:numel(rm));
    else
        error('%s run not valid',inputs.run);
    end
end
end