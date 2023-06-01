# FAST DIAGNOSIS SYSTEM CONNECTION
packages <- c("httr", "jsonlite", "redux")
for (package in packages) {
    if (!require(package, character.only = TRUE)) {
        install.packages(package, dependencies = TRUE, repos = "http://cran.us.r-project.org")
    }
    library(package, character.only = TRUE)
}

redis_host <- "redis"
redis_port <- 6379
fastapi_host <- "http://fastapi:8000"

h <- redux::hiredis()
r <- redux::redis_api(h$connect(redis_host, redis_port))

get_medical_data <- function(dni) {
    key <- paste0("medical_data:", dni)

    data <- r$get(key)
    if (!is.null(data)) {
        return(jsonlite::fromJSON(data))
    }

    response <- httr::GET(paste0(fastapi_host, "/patient/", dni))
    data <- httr::content(response, "text")

    if (httr::http_error(response)) {
        stop("Error fetching medical data")
    }

    r$set(key, data, ex = 3600) # expires after 1 hour

    return(jsonlite::fromJSON(data))
}


dni <- "79059848Q"
medical_data <- get_medical_data(dni)
