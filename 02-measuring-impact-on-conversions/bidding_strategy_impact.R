# Measuing Impact on Conversions 
# config ------------------------------------------------------------------
## load packages
library(knitr)
library(googleAuthR)
library(bigQueryR)
library(dplyr)
library(tidyr)
library(zoo)
library(CausalImpact)
library(ggplot2)

## set parameters for data extraction from BQ
### we add them at the top here for ease of changing, re-running analysis
### 1. ADD YOUR GCP PROJECT ID 
gcp_project_id <- "YOUR-GCP-PROJECT-ID" 
### 2. REPLACE WITH YOUR BQ DATASET ID 
bq_dataset <- "YOUR-BQ-DATASET-ID" 
### 3.1 REPLACE "YOUR-GCP-PROJECT-ID.YOUR-BQ-DATASET-ID" WITH
### YOUR GCP PROJECT ID AND BQ DATSET ID 
### 3.2 REPLACE DATES in TABLE_SUFFIX CLAUSE WITH YOUR START AND END DATES
query_control <- "
#standardSQL
SELECT
  date AS date,
  ROUND(SUM(IFNULL(totals.transactionRevenue/100000,0)),2) AS transactionRevenue
FROM
    `YOUR-GCP-PROJECT-ID.YOUR-BQ-DATASET-ID.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20180628' # YOUR CONTROL START DATE
  AND '20180805' # YOUR CONTROL END DATE 
  AND trafficSource.medium = 'cpc'
  AND trafficSource.adwordsClickInfo.adGroupId = 1111111111 # YOUR CONTROL AD GROUP ID 
GROUP BY
  1
ORDER BY
  1 ASC
"
### 4.1 REPLACE "YOUR-GCP-PROJECT-ID.YOUR-BQ-DATASET-ID" WITH
### YOUR GCP PROJECT ID AND BQ DATSET ID 
### 4.2 REPLACE DATES in TABLE_SUFFIX CLAUSE WITH YOUR START AND END DATES
query_test <- "
#standardSQL
SELECT
  date AS date,
  ROUND(SUM(IFNULL(totals.transactionRevenue/100000,0)),2) AS transactionRevenue
FROM
    `YOUR-GCP-PROJECT-ID.YOUR-BQ-DATASET-ID.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20180628' # YOUR TEST START DATE
  AND '20180805' # YOUR TEST END DATE
  AND trafficSource.medium = 'cpc'
  AND trafficSource.adwordsClickInfo.adGroupId = 22222222 # YOUR TEST AD GROUP ID 
GROUP BY
  1
ORDER BY
  1 ASC
"

## authenticate to BigQuery 
## Go through Google oAuth2 flow (browser will open)
## needs email that has access to the BigQuery dataset
## Setup instructions: http://code.markedmondson.me/googleAnalyticsR/big-query.html
## Vingette: https://cran.r-project.org/web/packages/bigQueryR/vignettes/bigQueryR.html
## Google oAuth2: https://developers.google.com/identity/protocols/OAuth2
bigQueryR::bqr_auth()

###  Check auth works and in right project:
knitr::kable(bqr_list_projects())

# extract -----------------------------------------------------------------
## Query BQ and save results as dataframe for modeling
## SMALL results (under ~ 100000 rows)
bq_raw_data_control <- bqr_query(projectId = gcp_project_id, 
                                 datasetId = bq_dataset, 
                                 query = query_control,
                                 useLegacySql = FALSE)

bq_raw_data_test <- bqr_query(projectId = gcp_project_id, 
                              datasetId = bq_dataset, 
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
## 5. CHANGE DATE RANGES TO MATCH BQ QUERIES ABOVE
### pre_period - 1) EARLIEST DATE OR SAME DATE AS CONTROL AND TEST BQ QUERIES ABOVE AND
### 2) DATE OF EVENT WE ARE MEASURING IMPACT FOR
pre_period <- as.Date(c("2018-06-28", "2018-07-15"))
### post_period - 1) NEXT DAY AFTER EVENT OR SECOND DATE IN "pre_period" AND 
### 2) LAST DATE OF DATA FROM BQ QUERIES ABOVE
post_period <- as.Date(c("2018-07-16", "2018-08-05"))

# modeling ----------------------------------------------------------------
## run the analysis 
impact <- CausalImpact(data = data, 
                       pre.period = pre_period, 
                       post.period = post_period)

## visualize the results
plot(impact) + ggtitle("Google Ads Group 1 vs Google Ads Group 2")
