chooseCRANmirror(ind = 1)
install.packages(c("fcaR", "RJDBC", "tidyverse", "dplyr", "DBI", "NLP", "tm"), dependencies = TRUE, type = "source", INSTALL_opts = "--no-lock", ask = FALSE, repos = "http://cran.r-project.org")

library(arules)
library(fcaR)
library(RJDBC)
library(dplyr)
library(tidyr)
library(NLP)
library(tm)

install.packages("BiocManager", dependencies = TRUE, type = "source", INSTALL_opts = "--no-lock", ask = FALSE, repos = "http://cran.r-project.org")
BiocManager::install("Rgraphviz", ask = FALSE)

install.packages("hasseDiagram", dependencies = TRUE, type = "source", INSTALL_opts = "--no-lock", ask = FALSE, repos = "http://cran.r-project.org")


jdbc_driver_path <- "fca/resources/CassandraJDBC42.jar"
jdbc_driver_class <- "com.simba.cassandra.jdbc42.Driver"

DISEASE_DEGREES <- 3

if (!file.exists(jdbc_driver_path)) {
    stop("File not found: ", jdbc_driver_path)
}

cassandra_host <- "0.0.0.0"
cassandra_port <- 9042
cassandra_keyspace <- "fds"

cassdrv <- JDBC(jdbc_driver_class, jdbc_driver_path, identifier.quote = "`")
conn <- dbConnect(cassdrv, paste0("jdbc:cassandra://", cassandra_host, ":", cassandra_port, ";AuthMech=0;Keyspace=", cassandra_keyspace))

dis_df <- dbGetQuery(conn, "SELECT * FROM fds.diseases")
symp_df <- dbGetQuery(conn, "SELECT * FROM fds.symptoms")

create_sparse_df <- function(conn, dis_df, symp_df, csv_filename) {
    # TODO CHANGE TABLES FROM .ENV
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

# Return the name of a symptom given its id
symptom_name <- function(symptom_id) {
    return(symp_df[symp_df$id == symptom_id, ]$name)
}

# Return the name of a disease given its id
disease_name <- function(disease_id) {
    return(dis_df[dis_df$id == disease_id, ]$name)
}

NextMinGen <- function(X, implications) {
    S <- ImplicationSet$new()
    repeat {
        G <- implications
        implications <- S
        S <- ImplicationSet$new()

        for (i in 1:G$size()) {
            A <- G$get_LHS_matrix()[i, ]
            B <- G$get_RHS_matrix()[i, ]

            if (all(A %in% X)) {
                X <- unique(c(X, B))
            } else if (!all(B %in% X)) {
                S$add(A[!A %in% X], B[!B %in% X])
            }
        }

        if (G$size() == S$size()) {
            break
        }
    }

    Next <- list()
    for (i in 1:S$size()) {
        A <- S$get_LHS_matrix()[i, ]
        B <- S$get_RHS_matrix()[i, ]
        M <- unique(c(A, B))
        if (!any(sapply(Next, function(x) all(x %in% M)))) {
            Next <- append(Next, list(M))
        }
    }

    return(list(Next = Next, G = S))
}


fc <- FormalContext$new(sparse_matrix)

fc$find_implications(verbose = TRUE)

implications <- fc$implications

NextMinGen <- function(X, implications) {
    S <- ImplicationSet$new()
    repeat {
        G <- implications
        implications <- S
        S <- ImplicationSet$new()

        for (i in 1:G$size()) {
            A <- G$get_LHS_matrix()[i, ]
            B <- G$get_RHS_matrix()[i, ]

            if (all(A %in% X)) {
                X <- unique(c(X, B))
            } else if (!all(B %in% X)) {
                S$add(A[!A %in% X], B[!B %in% X])
            }
        }

        if (G$size() == S$size()) {
            break
        }
    }

    Next <- list()
    for (i in 1:S$size()) {
        A <- S$get_LHS_matrix()[i, ]
        B <- S$get_RHS_matrix()[i, ]
        M <- unique(c(A, B))
        if (!any(sapply(Next, function(x) all(x %in% M)))) {
            Next <- append(Next, list(M))
        }
    }

    return(list(Next = Next, G = S))
}

get_top_five_attributes <- function(symptom_disease_matrix) {
    symptom_freq <- colSums(symptom_disease_matrix)
    top_five_symptoms <- names(sort(symptom_freq, decreasing = TRUE))[1:5]
    top_five_symptoms
}

find_similar_symptoms <- function(input_symptom, symptom_list, symptom_disease_matrix) {
    corpus <- Corpus(VectorSource(c(input_symptom, symptom_list)))
    corpus <- tm_map(corpus, content_transformer(tolower))
    corpus <- tm_map(corpus, removePunctuation)
    corpus <- tm_map(corpus, removeWords, stopwords("spanish"))
    corpus <- tm_map(corpus, stripWhitespace)

    tdm <- TermDocumentMatrix(corpus)
    similarity_matrix <- as.matrix(similarity(tdm, method = "cosine"))

    similar_symptoms <- sort(similarity_matrix[1, -1], decreasing = TRUE)[1:3]
    symptom_list[order(similarity_matrix[1, -1], decreasing = TRUE)[1:3]]
}

symptom_disease_matrix <- sparse_matrix

top_five_attributes <- get_top_five_attributes(symptom_disease_matrix)

cat("Los cinco síntomas más comunes son:\n")
for (i in 1:length(top_five_attributes)) {
    cat(paste0(i, ": ", symptom_name(top_five_attributes[i]), "\n"))
}

while (TRUE) {
    cat("¿Padece alguno de estos síntomas? (Ingrese el número correspondiente)\n")

    for (i in 1:length(top_five_attributes)) {
        cat(paste0(i, ": ", symptom_name(top_five_attributes[i]), "\n"))
    }

    cat("Si padece un síntoma que no aparece en esta lista, introduzca 'otro':\n")
    choice <- readline("> ")

    if (choice == "otro") {
        input_symptom <- readline("Introduzca su síntoma: ")
        similar_symptoms <- find_similar_symptoms(input_symptom, colnames(symptom_disease_matrix), symptom_disease_matrix)
        cat("Síntomas parecidos:\n")

        for (i in 1:length(similar_symptoms)) {
            cat(paste0(i, ": ", symptom_name(similar_symptoms[i]), "\n"))
        }

        choice <- as.integer(readline("Seleccione el síntoma que más se aproxime (Ingrese el número correspondiente): "))
        selected_symptom <- similar_symptoms[choice]
    } else {
        choice <- as.integer(choice)
        selected_symptom <- top_five_attributes[choice]
    }

    selected_attributes <- unique(c(selected_attributes, selected_symptom))

    # Utilizar NextMinGen para refinar el conjunto de implicaciones
    result <- NextMinGen(selected_attributes, implications)
    next_attributes <- result$Next
    implications <- result$G

    # Actualizar el conjunto de opciones con los siguientes atributos
    top_five_attributes <- unique(unlist(next_attributes))

    # Si el usuario ingresa "terminar", salir del bucle
    if (tolower(selected_symptom) == "terminar") {
        break
    }
}
