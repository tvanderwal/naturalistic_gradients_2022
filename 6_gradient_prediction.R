# GRADIENT_PREDICTION runs cross-validated glmnet models (in parallel) on gradient outputs from indiv_aligned.m.
# Constrains related subjects to same fold curing cross-validation
# https://cran.r-project.org/web/packages/glmnet/index.html

# setup paths
repoDir = 'code/naturalistic_gradients_2022'
dataDir = 'project/hcp_gradients/indiv_aligned' # folder w/ combined csv outputs from indiv_aligned.m, one subject per row
behav_data = file.path(repoDir,'data/behavioral_measures_n95.csv')
relation_data = file.path(repoDir,'data/relatedness_n95.csv')

# setup model parameters
savePrefix = 'gradient'
ncomp = 4
alpha = 0
nfolds = 10
niter = 100
standardize = F
condition = c('rest', 'movie')
cores=4

# load packages/scripts
setwd(repoDir)
library(glmnet)
library(parallel)
source(file.path(repoDir,'+gradient_tools','R',"fxn-hcp_cvfolds.R"))

run_cpm = function(foldid,x,y,alpha,standardize=FALSE) {
  require(glmnet)
  
  nfolds = max(unlist(foldid))
  mdl = cv.glmnet(x, y, alpha=alpha, nfolds=nfolds, foldid=foldid, keep=TRUE, standardize=standardize)
  yhat = mdl$fit.preval[,mdl$index[1]]
  r = cor(yhat, y)
  rmse = sqrt(mean((yhat-y)^2))
  mae = mean(abs(yhat - y))
  return(list(r,rmse,mae))
}

# load behavior
behav = read.csv(behav_data)
relation = read.csv(relation_data)

# setup iterations / outputs
r = list()
rmse = list()
mae = list()
foldid = list()
for (i in 1:niter) {
  # create folds for each iteration with family members in same fold
  folds = hcp_cvfolds(relation, nfolds=nfolds) 
  foldid = append(foldid, list(folds$foldid))
}

# loop over condtions, gradients, and run models 
for (cond in condition) {
  for (comp in 1:(ncomp+1)) {
    grad = paste('gradient',comp,sep='')
    if (comp > ncomp) {
      gradient_data = NULL
      grad = paste('gradients1-',ncomp,sep='')
      for (c in 1:ncomp) {
        gradient_data = rbind(gradient_data,  read.csv(paste(file.path(dataDir,'indiv_aligned/'),cond,'_gradient',c,'_n95.csv',sep='')))
      }
    } else {
      gradient_data =  read.csv(paste(file.path(dataDir,'indiv_aligned/'),cond,'_',grad,'_n95.csv',sep=''))
    }
    gradient_data = t(as.matrix(gradient_data))
      for (b in colnames(behav)) {
        if (b != 'Subject') {
          name = paste(cond,grad,b,sep="_")
          print(name)
          if (is.na(cores) || cores == 1) {
            out = lapply(foldid,run_cpm,x=gradient_data,y=behav[[b]],alpha=alpha,standardize=standardize)
          } else {
            out = mclapply(foldid,run_cpm,x=gradient_data,y=behav[[b]],alpha=alpha,standardize=standardize,mc.cores=cores)
          }
        for (iter in out) {
          r[[name]] = append(r[[name]],iter[[1]])
          rmse[[name]] = append(rmse[[name]],iter[[2]])
          mae[[name]] = append(mae[[name]],iter[[3]])
        }
      }
    }
  }
}
# write csv outputs
filePrefix = paste(savePrefix,'alpha',alpha,'_',nfolds,'fold_',niter,'iter',sep='')
write.csv(r,paste(dataDir,filePrefix,'_r.csv',sep=''))
write.csv(rmse,paste(dataDir,filePrefix,'_rmse.csv',sep=''))
write.csv(mae,paste(DataDir,filePrefix,'_mae.csv',sep=''))


