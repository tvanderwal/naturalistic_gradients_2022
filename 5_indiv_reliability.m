% INDIV_RELIABILITY calculates ICC(2,1) reliability from subject-level
% gradient embeddings. Computes reliablity over varying amounts of data
% from a prior run of gradient_pipeline.m with 'increment' argument
%
% Same outlier removal args as in align_indiv.m
function out = indiv_reliability(ref, matFolder1, matFolder2 ,varargin)
p = inputParser;
p.addParameter('idx',[]);
p.addParameter('ncomp',[]);
p.addParameter('outlierThr',[]);
p.addParameter('outlierScores',true);
p.parse(varargin{:});
inputs = p.Results;
if ~isempty(inputs.idx)
    idx = inputs.idx;
else
    idx = [];
end
% get .mat files containing gradients
mat1 = dir(fullfile(matFolder1,'*.mat'));
mat2 = dir(fullfile(matFolder2,'*.mat'));
[~,mat1_idx] = intersect({mat1.name},{mat2.name});
if numel(mat1_idx) ~= numel(mat1) || numel(mat1_idx) ~= numel(mat2)
   warning('%d unmatched runs were dropped', (numel(mat1) - numel(mat1_idx)) + (numel(mat2) - numel(mat1_idx)));
end
mat = mat1(mat1_idx);
for i=1:numel(mat)
    [~,tmp] = fileparts(mat(i).name);
    tmp = strsplit(tmp,'_');
    mat(i).sub = str2double(tmp{1});
    mat(i).cond = tmp{2};
end
matFolder = {matFolder1, matFolder2};

out = load(fullfile(mat(1).folder,mat(1).name));
out = out.out;

% check # of parcels
if ~isempty(idx)
    n = sum(idx);
else
    n = structfun(@(x) size(x,1), ref);
    if range(n)
        error('Different number of parcels/vertices in references')
    else
        n = n(1);
    end
end

% check / setup # of components 
ncomp = min(structfun(@(x) size(x,2), ref));
if ~isempty(inputs.ncomp) && inputs.ncomp <= ncomp
    ncomp = inputs.ncomp;
end
if ~isempty(inputs.outlierThr) && numel(inputs.outlierThr) > ncomp
    inputs.outlierThr = inputs.outlierThr(1:ncomp);
end

missing = [];
for i=1:numel(mat)
    for j=1:numel(matFolder)
        % load, get indices
        indiv = load(fullfile(matFolder{j},mat(i).name));
        indiv = indiv.out;
        if isempty(idx)
            indiv_idx = mean(indiv.idx,2);
            if any(indiv_idx < 1 & indiv_idx > 0)
                warning('%s indices not consitent across increments',mat(i).name);
            end
            indiv_idx = indiv_idx > 0;
        else
            indiv_idx = idx;
        end
        % loop over increments (number of vols used)
        for k=1:numel(indiv.vols)
            tmp_gradients = indiv.gradients(:,:,k);
            % compute and remove outlying gradients (if outlierThr input given)
            outL = tmp_gradients(indiv_idx,1:ncomp);
            %outL = max(abs(outL),[],1) ./ std(outL,0,1);
            outL = max(abs(outL),[],1) ./ median(abs(outL),1);
            outliers(i,j,:) = outL;
            if ~isempty(inputs.outlierThr)
                outL = outL > inputs.outlierThr;
                if sum(outL)
                    fprintf('%s\t%d outliers\n',mat(i).name,sum(outL));
                end
            else
                outL = false(1,ncomp);
            end
            tmp_gradients = tmp_gradients(:,~outL);
            % get rid of outlier parcels
            if inputs.outlierScores
                tmp_gradients(abs(tmp_gradients) > median(abs(tmp_gradients),"omitnan") + 3*std(abs(tmp_gradients),0,'omitnan')) = 0;
            end
            if size(indiv.gradients,2) < ncomp
                indiv_ncomp = size(indiv.gradients,2);
            else
                indiv_ncomp = ncomp;
            end
            unaligned(:,:,j,k,i) = tmp_gradients(indiv_idx,1:indiv_ncomp);
            % align
            [~,aligned(:,:,j,k,i)] = procrustes(ref.(mat(i).cond)(:,1:ncomp),tmp_gradients(indiv_idx,1:indiv_ncomp),'Scaling',0);
        end
    end
    for k=1:numel(indiv.vols)
        icc_all(i,k) = gradient_tools.icc21(reshape(aligned(:,:,:,k,i),[size(aligned,1)*size(aligned,2), size(aligned,3)]));
        [d_all(i,k),~,t] = procrustes(unaligned(:,:,1,k,i),unaligned(:,:,2,k,i),'Scaling',0);
        transform(i,k,:,:) = t.T;
        for g=1:size(aligned,2)
            icc(i,g,k) = gradient_tools.icc21(squeeze(aligned(:,g,:,k,i)));
        end
    end
end

out = [];
out.aligned = aligned;
out.outliers = outliers;
out.missing = missing;
out.idx = idx;
out.mat = mat;
out.icc = icc;
out.icc_all = icc_all;
out.d_all = d_all;
out.transform_all = transform;
end
