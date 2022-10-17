# Cortical gradients during naturalistic processing are hierarchical and modality-specific
This repository contains code for computing and analyzing gradient embeddings from the Human Connectome Project's [Young Adult 7T fMRI data](https://www.humanconnectome.org/study/hcp-young-adult/article/reprocessed-7t-fmri-data-released-other-updates). A [ConnectomeDB](https://db.humanconnectome.org/) account is required to download data.

## Dependencies
- MATLAB (R2020-2022)
- Python 3 w/ Jupyter
- R (4.0)
     - [glmnet](https://cran.r-project.org/web/packages/glmnet/index.html) package
- [CIFTI MATLAB](https://github.com/Washington-University/cifti-matlab) library
- [BrainSpace](https://brainspace.readthedocs.io/en/latest/) toollbox (0.1.2)
    - Add `resources/schaefer_1000_conte69.csv` from this repo to parcellation folder
