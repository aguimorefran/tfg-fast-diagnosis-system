# FAST DIAGNOSIS SYSTEM CONNECTION
packages <- c("redux", "httr", "jpeg")
for (package in packages) {
    if (!require(package, character.only = TRUE)) {
        install.packages(package, dependencies = TRUE)
    }
    library(package, character.only = TRUE)
}

fastapi_host <- "http://localhost:8000"

h <- hiredis(host = "localhost", port = 6379, db=0)

get_medical_data <- function(dni) {
    key <- paste0("medical_data:", dni)

    data <- h$GET(key)
    if (!is.null(data)) {
        return(jsonlite::fromJSON(data))
    }

    response <- httr::GET(paste0(fastapi_host, "/patient/", dni))
    data <- httr::content(response, "text")

    if (httr::http_error(response)) {
        stop("Error fetching medical data")
    }

    h$SET(key, data, EX = 3600)

    return(jsonlite::fromJSON(data))
}

dni <- "18900233Y"
medical_data <- get_medical_data(dni)
medical_data
