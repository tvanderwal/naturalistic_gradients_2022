% ALIGN_INDIV aligns individual gradient embeddings from gradient_pipeline.m
% to 'ref' template (e.g. group average)
%
% Optional removal of outlier gradients with 'outlierThr' value (one per
% gradient). Can be data derived wrt a prior run of this script w/ 'out.outliers'
%
% Optional removal (set to 0) of outlier gradient scores with
% 'outlierScores' (T/F)

function out = align_indiv(ref, indivFolder, varargin)
p = inputParser;
p.addParameter('save',1);
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
mat = dir(fullfile(indivFolder,'*.mat'));
for i=1:numel(mat)
    [~,tmp] = fileparts(mat(i).name);
    tmp = strsplit(tmp,'_');
    mat(i).sub = str2double(tmp{1});
    mat(i).cond = tmp{2};
end

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

% load indiv and align to group
aligned = nan(n,ncomp,numel(mat));
outliers = nan(numel(mat),ncomp);
missing = false(numel(idx),numel(mat));
for i=1:size(aligned,3)
    indiv = load(fullfile(mat(i).folder,mat(i).name));
    indiv = indiv.out;
    if isempty(idx)
        indiv_idx = indiv.idx;
    else
        indiv_idx = idx;
    end
    % compute and remove outlying gradients (if outlierThr input given)
    outL = indiv.gradients(indiv_idx,1:ncomp);
    %outL = max(abs(outL),[],1) ./ std(outL,0,1);
    outL = max(abs(outL),[],1) ./ median(abs(outL),1);
    outliers(i,:) = outL;
    if ~isempty(inputs.outlierThr)
        outL = outL > inputs.outlierThr;
        if sum(outL)
            fprintf('%s\t%d outliers\n',mat(i).name,sum(outL));
        end
    else
        outL = false(1,ncomp);
    end
    indiv.gradients = indiv.gradients(:,~outL);
    % get rid of outlier parcels
    if inputs.outlierScores
        indiv.gradients(abs(indiv.gradients) > median(abs(indiv.gradients),"omitnan") + 3*std(abs(indiv.gradients),0,'omitnan')) = 0;
    end
    if size(indiv.gradients,2) < ncomp
        indiv_ncomp = size(indiv.gradients,2);
    else
        indiv_ncomp = ncomp;
    end
    % align
    [~,aligned(:,:,i)] = procrustes(ref.(mat(i).cond)(:,1:ncomp),indiv.gradients(indiv_idx,1:indiv_ncomp),'Scaling',0);
end

% output csv
if inputs.save
    sub = unique([mat.sub]);
    sub_names = arrayfun(@(x) sprintf('%d',x),sub,'UniformOutput',0);
    cond = unique({mat.cond});
    % save csv
    for i=1:numel(cond)
        % aggregate sub
        out = nan(n,numel(sub),ncomp);
        for j=1:numel(sub)
            mat_idx = strcmp({mat.cond},cond{i}) & [mat.sub] == sub(j);
            out(:,j,:) = aligned(:,:,mat_idx);
        end
        % output
        for j=1:size(out,3)
            t = array2table(out(:,:,j),'VariableNames',sub_names);
            writetable(t,sprintf('%s_gradient%d_n%d.csv',lower(cond{i}),j,numel(sub)),'WriteVariableNames',1);
        end
    end

    % save mat
    save(sprintf('gradients_aligned_indiv_n%d',numel(sub)),'aligned','mat','idx');
end
out = [];
out.aligned = aligned;
out.outliers = outliers;
out.missing = missing;
out.idx = idx;
out.mat = mat;
end