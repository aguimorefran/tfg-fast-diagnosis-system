# FAST DIAGNOSIS SYSTEM DATALOADER
packages <- c("RJDBC")
for (package in packages) {
    if (!require(package, character.only = TRUE)) {
        install.packages(package, dependencies = TRUE, repos = "http://cran.us.r-project.org")
    }
    library(package, character.only = TRUE)
}

evidences_file <- "fca/resources/dataset/release_evidences.json"
conditions_file <- "fca/resources/dataset/release_conditions.json"
evidences <- fromJSON(evidences_file)
conditions <- fromJSON(conditions_file)
ev_names <- names(evidences)
cond_names <- names(conditions)

jdbc_driver_path <- "fca/resources/CassandraJDBC42.jar"
jdbc_driver_class <- "com.simba.cassandra.jdbc42.Driver"
cassandra_host <- "0.0.0.0"
port <- 9042
keyspace <- "fds"
table <- "casos_clinicos"
rowstrain <- 2000
rowsvalidate <- 1000
age_range <- 10

fetch_dataframes_cassandra <- function(cassandra_host, port, keyspace, table, rowstrain, rowsvalidate) {
    cassdrv <- JDBC(jdbc_driver_class, jdbc_driver_path, identifier.quote = "`")
    conn <- dbConnect(cassdrv, paste0("jdbc:cassandra://", cassandra_host, ":", port, ";AuthMech=0;Keyspace=", keyspace))

    result <- dbGetQuery(conn, sprintf("SELECT id FROM %s.%s", keyspace, table))
    ids <- result$id
    ids <- ids[sample(length(ids))]
    ids <- ids[1:(rowstrain + rowsvalidate)]

    result <- dbGetQuery(conn, sprintf("SELECT * FROM %s.%s WHERE id IN (%s)", keyspace, table, paste(ids, collapse = ",")))
    dbDisconnect(conn)

    df <- as.data.frame(result)

    train_df <- df[1:rowstrain, ]
    validate_df <- df[(rowstrain + 1):(rowstrain + rowsvalidate), ]

    return(list(train_df = train_df, validate_df = validate_df))
}

convert_to_sparse <- function(df, nrows, cond_names, ev_names, age_range = 10) {
    df <- df[sample(nrow(df), min(nrow(df), nrows)), ]
    df <- df[, c("age", "sex", "evidences", "pathology", "initial_evidence")]
    df$evidences <- gsub("\\[|\\]|'", "", df$evidences)
    df$evidences <- sapply(strsplit(df$evidences, ","), function(x) trimws(x))
    df$evidences <- sapply(df$evidences, trimws)
    df$evidences <- sapply(df$evidences, function(x) gsub("@.*", "", x))
    df$evidences <- sapply(df$evidences, function(x) gsub("_$", "", x))

    num_age_categories <- ceiling(100 / age_range)
    df$age <- cut(df$age, breaks = seq(0, 100, by = age_range), labels = FALSE, include.lowest = TRUE)
    df <- df[!is.na(df$age), ]
    df$age <- paste0("AGE_", df$age)

    sparse_df <- data.frame(
        matrix(
            0,
            nrow = nrow(df),
            ncol = length(ev_names) + length(cond_names) + num_age_categories + 2 # num_age_categories for age categories, 2 for sex categories
        )
    )
    colnames(sparse_df) <- c(ev_names, cond_names, paste0("AGE_", 1:num_age_categories), "SEX_M", "SEX_F")

    for (i in 1:nrow(df)) {
        if (i %% 100 == 0) {
            print(paste0("Row ", i, " of ", nrow(df)))
        }
        row <- df[i, ]
        evidence <- unlist(row$evidences)
        pathology <- row$pathology
        initial_evidence <- row$initial_evidence
        age <- row$age
        sex <- paste0("SEX_", row$sex)

        for (ev in evidence) {
            sparse_df[i, ev] <- 1
        }
        sparse_df[i, pathology] <- 1
        sparse_df[i, initial_evidence] <- 1
        sparse_df[i, age] <- 1
        sparse_df[i, sex] <- 1
    }

    return(sparse_df)
}


dfs <- fetch_dataframes_cassandra(cassandra_host, port, keyspace, table, rowstrain, rowsvalidate)
sparse_train_df <- convert_to_sparse(dfs$train_df, rowstrain, cond_names, ev_names, age_range)
sparse_validate_df <- convert_to_sparse(dfs$validate_df, rowsvalidate, cond_names, ev_names, age_range)
