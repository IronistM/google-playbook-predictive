#' Rmarkdown to HTML 
#' 
#' @description knit Rmarkdown to HTML file so it can be consumed by end users in a web browser and hosted in a GCS bucket
#' 
#' @param file a string of the report or file without extension
#' 
#' @return a html file
#' 
rmd_to_html <- function(file){
  
  ## knit R markdown to hmtl so we can share
  rmarkdown::render(input = paste0(file, ".Rmd"),
                    output_options = "all")
}



#' Upload html files to GCS 
#' 
#' @description uplaod html file to GCS bucket and set access to public so those with the link can view 
#' 
#' @param html_file_list
#' @param access 
#' 
#' @return uploaded file 

upload_html_files  <- function(html_file_list,
                               access="private"){
  
  data <- lapply(html_file_list, function(x){
    
    message(Sys.time()," > Uploading ", x)
    ## upload to GCS 
    gcs_upload(file = x,
               name = x,
               predefinedAcl = c(access))
    
  })
}
