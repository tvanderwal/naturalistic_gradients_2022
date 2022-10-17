if ~exist('varargin','var')
    varargin = {};
end
% handle inputs
p = inputParser;
p.addParameter('res',400);
p.parse(varargin{:});

inputs = p.Results;


[conte.lh, conte.rh] = load_conte69();

% load parcellation
schaefer = load_parcellation('schaefer',inputs.res);
schaefer = schaefer.(sprintf('schaefer_%d',inputs.res));