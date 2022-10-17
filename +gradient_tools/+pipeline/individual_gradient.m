% function to load HCP-stype cifti files and use BrainSpace toolbox to
% compute gradients
%
% also uses https://github.com/Washington-University/cifti-matlab
function out = individual_gradient(cifti,varargin)
% handle inputs
p = inputParser;
%p.addParameter('vol',{},@iscellstr);
p.addParameter('parc','schaefer');
p.addParameter('res',1000);
p.addParameter('gradient',true);
p.addParameter('plot',false);
p.addParameter('scrubVols',[],@isnumeric);
p.addParameter('increment',[],@isnumeric);
p.parse(varargin{:});

inputs = p.Results;
out = [];

% load conte69 template (HCP cortex mapping)
[conte.lh, conte.rh] = load_conte69();

% load parcellation
if ~isempty(inputs.res) && inputs.res
    parc = load_parcellation(inputs.parc,inputs.res);
    parc = parc.(sprintf('%s_%d',inputs.parc,inputs.res));
end

% load ciftis, split off surface (with mask where data exist ~29/32k), concatenate 
if ischar(cifti)
   cifti = {cifti}; 
end
gii.lh = [];
gii.rh = [];
mask.lh = [];
mask.rh = [];
for i=1:numel(cifti)
   img = cifti_read(cifti{i});
   % cortical surface
   [tmp.lh, tmp_mask.lh] = cifti_struct_dense_extract_surface_data(img,'CORTEX_LEFT');
   [tmp.rh, tmp_mask.rh] = cifti_struct_dense_extract_surface_data(img,'CORTEX_RIGHT');
   gii.lh = [gii.lh tmp.lh];
   gii.rh = [gii.rh tmp.rh];
   mask.lh = [mask.lh tmp_mask.lh];
   mask.rh = [mask.rh tmp_mask.rh];
   % volumetric structures
   %[tmp, ~, tmp_mask] = cifti_struct_dense_extract_volume_all_data(img);
end
clear tmp*

% stack lh and rh, mask out non-data, scrub (crop timeseries)
gii = [gii.lh; gii.rh];
if ~isempty(inputs.scrubVols)
   gii = gii(:,~inputs.scrubVols); 
end
mask = [mask.lh; mask.rh];
mask = all(mask,2);
gii(~mask,:) = NaN;

% setup increments (multiple connectomes / gradients of with increasing amts of data)
if isempty(inputs.increment)
    vols = size(gii,2);
else
    vols = inputs.increment:inputs.increment:size(gii,2);
    if vols(end) < size(gii,2)
        vols(end+1) = size(gii,2);
    end
end

% correlation matrix
g = {};
gradients = [];
for i=1:numel(vols)
    if ~isempty(inputs.res) && inputs.res
        parcellated = full2parcel(gii(:,1:vols(i))',parc)';
        conn(:,:,i) = corr(parcellated);
    else
        conn(:,:,i) = corr(gii(:,1:vols(i))');
    end
    idx(:,i) = ~all(isnan(conn(:,:,i))); % deal with missing parcels
    % do gradient mapping
    if inputs.gradient
        g{i} = GradientMaps('kernel','cosine','approach','dm');
        try
            g{i} = g{i}.fit(conn(idx(:,i),idx(:,i),i));

            % fix missing parcels and plot
            gradients(:,:,i) = nan(numel(idx(:,i)),size(g{i}.gradients{1},2));
            gradients(idx(:,i),:,i) = g{i}.gradients{1};
            if inputs.plot
                scree_plot(g.lambda{1});
                plot_hemispheres(gradients(:,1:3,i),{conte.lh conte.rh},'parcellation',parc); % first 2
                gradient_in_euclidean(gradients(:,1:3,i),{conte.lh conte.rh},parc);
            end
        catch
            fprintf('Error computing gradient');
        end
    end
end
% outputs
out.vols = vols;
out.conn = conn;
out.idx = idx;
out.g = g;
out.gradients = gradients;
end
