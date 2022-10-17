% Z is the transformed (sign-flipped dimensions) of Y to match X
function Z = sign_flip(X, Y)
% flip grad signs of Y that negatively correlate with X
r = corr(X,Y);
r = diag(r);
neg_grad = r < 0;
Z = Y;
Z(:,neg_grad) = Z(:,neg_grad) * -1;
end