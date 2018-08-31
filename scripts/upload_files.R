# setup
source("./scripts/functions.R")

## assumes you have client JSON saved to environment argument GAR_CLIENT_JSON
app_project <- googleAuthR::gar_set_client(
  scopes = c("https://www.googleapis.com/auth/cloud-platform"))

library(googleCloudStorageR)

# authenticate 
## Option 1 - AUTO
## assumes you have service account private key file (JSON) 
## saved to environment argument GCS_AUTH_FILE

## Option 2
## OAUTH via web browser 
### googleAuthR::gar_auth("gcs.oauth")

## set and sanity check options so we're sure we're uploading to the 
## corerect bucket
gcs_global_bucket(bucket = "gcp-playbook-predictive")
gcs_list_buckets(projectId = "snappy-way-531")


html_file_list <- c("forecasting-kpi-targets/report-example.html",
                    "power-of-remarketing/predict_conversion.html")

# upload files to be publicly visible
upload_html_files(html_file_list = html_file_list, 
                  access = "public")
