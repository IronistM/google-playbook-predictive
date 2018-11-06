# Forecasting KPI's 
# config ------------------------------------------------------------------
## load packages
library(knitr)
library(googleAuthR)
library(bigQueryR)
library(dplyr)
library(tidyr)
library(prophet)
library(ggplot2)
library(plotly)
library(scales)

## set parameters for data extraction from BQ
### we add them at the top here for ease of changing, re-running analysis
### 1. ADD YOUR GCP PROJECT ID 
gcp_project_id <- "YOUR-GCP-PROJECT-ID" 
### 2. REPLACE WITH YOUR BQ DATASET ID 
### (OR LEAVE AS-IS TO RUN ON GA360 DEMO DATASET)
bq_dataset <- "google_analytics_sample" 
### 3. REPLACE "bigquery-public-data.google_analytics_sample" WITH
### YOUR GCP PROJECT ID AND BQ DATSET ID 
#### (OR LEAVE AS IS TO RUN ON GA360 DEMO DATASET)
bq_query <- "
#standardSQL
SELECT
  date AS date,
  (trafficSource.medium) AS medium,
  SUM(totals.pageviews) AS pageViews,
  ROUND(SUM(IFNULL(totals.transactionRevenue/100000,0)),2) AS transactionRevenue
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN 
  FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 732 DAY))
  AND FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY
  1,
  2
HAVING
  medium = 'cpc'
ORDER BY 
  1 ASC,
  3 DESC
"

## set modeling parameters
### 4. SET DATASET NAME TO BE RELAVANT FOR YOUR ANALYSIS 
### (THIS WILL BE THE CSV FILE THAT IS IN GCS AND YOUR LOCAL MACHINE)
dataset_name <- "cpc_revenue_by_date"
### 5. SET TRAINING DATA START AND END DATES 
### (1 YEAR MIN FOR TRAINING DATA DATE RANGE)
train_start <- "2016-08-01"
train_end <- "2017-07-23"
### 6. SET TRAINING DATA START AND END DATE 
valid_start <- "2017-07-24"
valid_end <- "2017-07-30"
### 7. SET FORECAST PERIOD (SAME NUMBER OF DAYS AS VALIDATION DATE RANGE ABOVE)
forecast_period <- 7

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
bq_raw_data <- bqr_query(projectId = gcp_project_id, 
                         datasetId = bq_dataset_id, 
                         query = bq_query,
                         useLegacySql = FALSE)

## save original dataset as csv to resume work later if our session crashes
write.csv(bq_raw_data, paste0(dataset_name, ".csv"), row.names = FALSE)

# modeling -------------------------------------------------------------------
## load data from csv in case resuming analysis from latest data from exports
bq_raw_data <- read.csv(paste0(dataset_name, ".csv"), 
                        stringsAsFactors = FALSE)
## explore data 
### create data frame for exploration and modelling to preserve original,
### "bq_raw_data" is an R dataframe of the query results above
### select the 2 columns, data and transactionRevenue for modeling only
data <- bq_raw_data %>% 
  select(ds = date, y = transactionRevenue) %>% 
  mutate(ds = as.Date(ds, format = "%Y%m%d")) 

## visualize to idenitfy outliers if needed later on 
p <- ggplot(data, aes(ds, y)) + geom_line() 
ggp <- ggplotly(p)
ggp

### create training dataset
train_data <- data %>% 
  filter(ds >= train_start & ds <= train_end)

### create validation dataset 
validation_data <- data %>% 
  filter(ds >= valid_start & ds <= valid_end)

## forecast - basic ------------------------------------------------
###  fit the model on the dataframe 
m <- prophet(train_data)
future <- make_future_dataframe(m, periods = forecast_period)

### deploy model using receive predictions for the length of days required
forecast <- predict(m, future)

### visualize forecast result 
plot(m, forecast)

### view raw data with predicted value by day and uncertainty intervals 
tail(forecast[c("ds", "yhat", "yhat_lower", "yhat_upper")], n = forecast_period * 2)

## remove outliers ---------------------------------------------------------
## create vector of outliers and convert outliers to NA 
## to improve forecast model accuracy 
### 7. EDIT THESE DATES TO MATCH YOUR IDENTIFIED OUTLIERS
outlier_dates <- c("2016-09-28", 
                   "2016-11-30", 
                   "2016-12-07", 
                   "2017-04-03", 
                   "2017-04-06")
outliers <- train_data$ds %in% as.Date(outlier_dates)
train_data$y[outliers] = NA 

## check to ensure outliers are NA 
train_data %>%
  filter(is.na(y))

## forecast - final ----------------------------------------------------------
###  fit the model on the dataframe 
m <- prophet(train_data)
future <- make_future_dataframe(m, periods = forecast_period)

### deploy model using receive predictions for the length of days required
forecast <- predict(m, future)

### visualize forecast result 
plot(m, forecast)

### view raw data with predicted value by day and uncertainty intervals 
tail(forecast[c("ds", "yhat", "yhat_lower", "yhat_upper")], n = forecast_period * 2)

## results -------------------------------------------------------------------
### calculate and print total forecasted 
total_forecast <- forecast %>% 
  filter(ds >= valid_start & ds <= valid_end) %>% 
  summarise(transactionRevenue = sum(yhat))

message("Forecasted Revenue: ", dollar(total_forecast$transactionRevenue))

### calculate and print total actual revenue 
total_actual <- validation_data %>% 
  filter(ds >= valid_start & ds <= valid_end) %>% 
  summarise(transactionRevenue = sum(y))

message("Actual Revenue: ", dollar(total_actual$transactionRevenue))

### compare forecast vs actual 
difference <- ((total_actual$transactionRevenue - total_forecast$transactionRevenue) 
               / total_forecast$transactionRevenue )

### calculate percent difference/error in forecast vs actual
message("Perecent difference in Forecasted vs Actual Revenue: ", percent(difference))
