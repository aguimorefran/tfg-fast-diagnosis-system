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

    summary(dis_df)
    summary(symp_df)
    summary(relations)

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

# > str(sparse_df)
# tibble [303 × 130] (S3: tbl_df/tbl/data.frame)
#  $ disease_id                          : chr [1:303] "01a06be5-1038-40a9-b16f-f093899d5cc1" "02bb344d-d561-46be-909a-a62429efa3b1" "034d8cb0-da75-403a-8c7e-e0fc3ab72eb0" "035baccc-c491-4c3c-9b59-81dbfe477ac6" ...
#  $ 4990f072-81f7-4107-8060-0237a464540d: num [1:303] 0 0 0 0 0 0 0 0 0 0 ...
#  $ 618a4a72-aefe-4a03-88db-605e28fbde6e: num [1:303] 0 0 1 0 0 0 0 0 0 0 ...
#  $ 84d67443-2188-4841-a636-af46a45e3c51: num [1:303] 0 0 0 0 0 0 0 0 0 0 ...
# ....

# convert to matrix
sparse_matrix <- sparse_df %>%
    as.matrix()
rownames(sparse_matrix) <- sparse_df$disease_id
sparse_matrix <- sparse_matrix[, -1]

# convert matrix to numeric
sparse_matrix <- as.numeric(sparse_matrix)


fc_dis <- FormalContext$new(sparse_matrix)