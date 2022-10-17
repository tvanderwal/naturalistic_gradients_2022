function g = full_gradient(g,idx)
tmp = nan(numel(idx),size(g,2));
tmp(idx,:) = g;
g = tmp;
end