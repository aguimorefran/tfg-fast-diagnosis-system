if (!require("fcaR")) {
    install.packages("fcaR", repos = "http://cran.r-project.org")
}
if (!require("RJDBC")) {
    install.packages("RJDBC", repos = "http://cran.r-project.org")
}
if (!require("tidyverse")) {
    install.packages("tidyverse", repos = "http://cran.r-project.org")
}
if (!require("dplyr")) {
    install.packages("dplyr", repos = "http://cran.r-project.org")
}
if (!require("tidyr")) {
    install.packages("DBI", repos = "http://cran.r-project.org")
}

library(fcaR) # https://cran.rstudio.com/web/packages/fcaR/fcaR.pdf
library(RJDBC)
library(tidyverse)
library(dplyr)
library(tidyr)

jdbc_driver_path <- "fca/resources/CassandraJDBC42.jar"
jdbc_driver_class <- "com.simba.cassandra.jdbc42.Driver"

if (!file.exists(jdbc_driver_path)) {
    stop("File not found: ", jdbc_driver_path)
}

cassandra_host <- "0.0.0.0"
cassandra_port <- 9042
cassandra_keyspace <- "fds"

cassdrv <- JDBC(jdbc_driver_class, jdbc_driver_path, identifier.quote = "`")
conn <- dbConnect(cassdrv, paste0("jdbc:cassandra://", cassandra_host, ":", cassandra_port, ";AuthMech=0;Keyspace=", cassandra_keyspace))

create_sparse_df <- function(conn, csv_filename) {
    # TODO CHANGE TABLES FROM .ENV
    dis_df <- dbGetQuery(conn, "SELECT * FROM fds.diseases")
    symp_df <- dbGetQuery(conn, "SELECT * FROM fds.symptoms")
    relations <- dbGetQuery(conn, "SELECT * FROM fds.diseases_vt_symptoms")

    relations_df <- relations %>%
        left_join(dis_df, by = c("id" = "id")) %>%
        left_join(symp_df, by = c("symptoms_value" = "id")) %>%
        rename(disease_name = name.x, symptom_name = name.y, disease_id = id, symptom_id = symptoms_value)

    symptom_id_list <- symp_df$id

    sparse_df <- relations_df %>%
        select(disease_id, disease_name) %>%
        distinct() %>%
        arrange(disease_id)

    sparse_df <- relations_df %>%
        pivot_wider(
            id_cols = disease_id, names_from = symptom_id, values_from = symptom_id,
            values_fn = function(x) ifelse(is.na(x), 0, 1)
        ) %>%
        replace(is.na(.), 0) %>%
        arrange(disease_id)
    
    dir.create("fca/data", showWarnings = FALSE)
    write.csv(sparse_df, "fca/data/" %>% paste(csv_filename, ".csv", sep = ""), row.names = FALSE)
    return(sparse_df)
}

sparse_df <- create_sparse_df(conn, "sparse")

tuples <- sparse_df %>%
    select(disease_id) %>%
    distinct() %>%
    arrange(disease_id) %>%
    mutate(rowid = row_number()) %>%
    select(rowid, disease_id) %>%
    collect()

sparse_matrix <- sparse_df %>%
    select(-disease_id) %>%
    collect() %>%
    as.matrix()

rownames(sparse_matrix) <- tuples$disease_id

for (i in 1:nrow(sparse_matrix)) {
    for (j in 1:ncol(sparse_matrix)) {
        if (sparse_matrix[i, j] != sparse_df[i, j + 1]) {
            print("ERROR" %>% paste(i, j, sep = ","))
        }
    }
}


fc_dis <- FormalContext$new(sparse_matrix)
fc_dis$find_concepts()

fc_dis$concepts[3]

# save the concepts to a R file
save(fc_dis, file = "fca/data/fc_dis.RData")
