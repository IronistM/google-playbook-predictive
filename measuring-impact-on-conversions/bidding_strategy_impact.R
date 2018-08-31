# Measuing Impact on Conversions 
# config ------------------------------------------------------------------
## load packages
library(googleAuthR)
library(bigQueryR)
library(dplyr)
library(tidyr)
library(zoo)
library(CausalImpact)
library(ggplot2)

# set options for authentication
## Setup instructions here: http://code.markedmondson.me/googleAnalyticsR/big-query.html
## Vingette here: https://cran.r-project.org/web/packages/bigQueryR/vignettes/bigQueryR.html
# options(googleAuthR.client_id = "XXXXXXXXXXXXXXXX") # SET CLIENT ID
# options(googleAuthR.client_secret = "XXXXXXXXXXXXXXXX") # SET CLIENT SECRET 
options(googleAuthR.scopes.selected = c("https://www.googleapis.com/auth/cloud-platform"))

## this will open your browser
## Authenticate with an email that has access to the BigQuery project you need
bqr_auth()

# extract -----------------------------------------------------------------
## set parameters for easier interpretation/reuse later
project <- "XXXXXXXXXXXXXXXX" # SET GCP PROJECT ID 
dataset <- "XXXXXXXXXXXXXXXX" # SET BQ DATASET

query_control <- "
#standardSQL
SELECT
  date AS date,
  ROUND(SUM(IFNULL(totals.transactionRevenue/100000,0)),2) AS transactionRevenue
FROM
    `<dataset-id>.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20180628'
  AND '20180805'
  AND trafficSource.medium = 'cpc'
  AND trafficSource.adwordsClickInfo.adGroupId = 1111111111 # CONTROL ad group ID
GROUP BY
  1
ORDER BY
  1 ASC
"

query_test <- "
#standardSQL
SELECT
  date AS date,
  ROUND(SUM(IFNULL(totals.transactionRevenue/100000,0)),2) AS transactionRevenue
FROM
    `<dataset-id>.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20180628'
  AND '20180805'
  AND trafficSource.medium = 'cpc'
  AND trafficSource.adwordsClickInfo.adGroupId = 22222222 # TEST ad group ID
GROUP BY
  1
ORDER BY
  1 ASC
"
## Get Data from BQ 
### SMALL results (under ~ 100000 rows)
bq_raw_data_control <- bqr_query(projectId = project, 
                                 datasetId = dataset, 
                                 query = query_control,
                                 useLegacySql = FALSE)

bq_raw_data_test <- bqr_query(projectId = project, 
                              datasetId = dataset, 
                              query = query_test,
                              useLegacySql = FALSE)

## Set control and test groups as seperate vectors to 
## match up with CausaulImpact R package basic examples
## http://google.github.io/CausalImpact/CausalImpact.html#creating-an-example-dataset
x <- bq_raw_data_control$transactionRevenue
y1 <- bq_raw_data_test$transactionRevenue

## Create column of dats 
time_points <- as.Date(bq_raw_data_control$date, format = "%Y%m%d")

## combine into a single zoo object for modeling/anaylsis
data <- zoo(cbind(x, y1), time_points)

## print top 10 rows to sanity check
head(data)

## set periods for Causual Impact 
pre_period <- as.Date(c("2018-06-28", "2018-07-15"))
post_period <- as.Date(c("2018-07-16", "2018-08-05"))

# model -------------------------------------------------------------------
## run the analysis 
impact <- CausalImpact(data = data, 
                       pre.period = pre_period, 
                       post.period = post_period)

## visualize the results
plot(impact) + ggtitle("Google Ads Group 1 vs Google Ads Group 2")

