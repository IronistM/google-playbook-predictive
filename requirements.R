# install required packages from CRAN
packages_list <- c("knitr",
                   "googleAuthR",
                   "googleCloudStorageR",
                   "bigQueryR",
                   "dplyr",
                   "tidyr",
                   "prophet",
                   "ggplot2",
                   "plotly",
                   "scales",
                   "CasualImpact",
                   "zoo",
                   "caret")

new_packages <- packages_list[!(packages_list %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)
