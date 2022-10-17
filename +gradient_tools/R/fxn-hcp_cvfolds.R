hcp_cvfolds = function(family, nfolds=10) {
  # randomly shuffle
  fam_shuffle = sample(unique(family$Family))
  n = length(fam_shuffle)
  per = n / nfolds
  if (per < 1) {
    stop("Not enough subjects for requested folds")
  }
  rem = n - floor(per)*nfolds
  # first "rem" groups have an extra family
  fam_foldid = rep(1:nfolds, floor(per))
  if (rem > 0) {
    fam_foldid = c(fam_foldid,1:rem)
  }
  foldid = c()
  subject = c()
  # set folds for all subjects based on family foldid
  for (i in 1:n) {
    sub = family$Subject[family$Family == fam_shuffle[i]]
    subject = c(subject,sub)
    foldid = c(foldid, rep(fam_foldid[i], length(sub)))
  }
  # setup output 
  folds = data.frame(Subject = subject, foldid = foldid)
  folds = folds[order(folds$Subject),]
  row.names(folds) = row.names(sort(row.names(folds)))
  return(folds)
}