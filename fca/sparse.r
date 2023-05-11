chooseCRANmirror(ind = 1)
install.packages(c("fcaR", "RJDBC", "tidyverse", "dplyr", "DBI", "devtools"), dependencies = TRUE, type = "source", INSTALL_opts = "--no-lock", ask = FALSE, repos = "http://cran.r-project.org")

library(arules)
library(fcaR)
library(RJDBC)
library(dplyr)
library(tidyr)
library(devtools)


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


tuples <- sparse_df %>%
  select(disease_id) %>%
  distinct() %>%
  arrange(disease_id) %>%
  mutate(rowid = row_number()) %>%
  select(rowid, disease_id) %>%
  collect()

# Crear la matriz dispersa eliminando la columna disease_id y convirtiendo el dataframe resultante en una matriz
sparse_matrix <- as.matrix(sparse_df[, -1])

# Establecer los nombres de las filas de sparse_matrix como los valores de disease_id en sparse_df
rownames(sparse_matrix) <- sparse_df$disease_id

# Return the name of a symptom given its id
symptom_name <- function(symptom_id) {
  return(symp_df[symp_df$id == symptom_id, ]$name)
}

# Return the name of a disease given its id
disease_name <- function(disease_id) {
  return(dis_df[dis_df$id == disease_id, ]$name)
}

# fc <- FormalContext$new(sparse_matrix)
# fc$find_implications(verbose = TRUE)
# saveRDS(fc, "fca/resources/fc.rds")

fc <- readRDS("fca/resources/fc.rds")

implications <- fc$implications

s1 <- "761d186a-8e4e-4129-a85c-510ec16522a3"
s2 <- "8c96ca09-5c9e-44c1-9f5f-8ff51b3a2ea3"

X <- c(s1)

Sigma <- implications


# NextMinGen(X, Sigma):
# input:
# X, set of attributes selected by the user
# Sigma, set of implications describing the knowledge in the system
# output:
# Next, set of attribute sets which are the choices of the next step in the guided search
# Gamma, reduced set of implications

# repeat:
# Gamma = Sigma; Sigma = emptyset
# foreach A -> B in Gamma do:
# if A subseteq X then X = X U B
# else if B not subseteq X then Sigma = Sigma U {A \ X -> B \ X}
# until Gamma = Sigma
# Next = Minimals{A subseteq M | A -> B in Gamma for some B subseteq M}
# return (Next, Gamma).

NextMinGen <- function(X, Sigma) {
  M <- Sigma$get_attributes()
  repeat {
    Gamma <- Sigma
    Sigma <- ImplicationSet$new(attributes = M)

    for (i in 1:Gamma$cardinality()) {
      rule <- Gamma[i]
      A <- rule$get_LHS_matrix()
      B <- rule$get_RHS_matrix()

      if (all(as.vector(A) %in% unlist(X))) {
        X <- union(X, B)
      } else if (!all(as.vector(B) %in% unlist(X))) { 
        A[which(rownames(A) %in% X), ] <- 0
        B[which(rownames(B) %in% X), ] <- 0
        new_rule <- ImplicationSet$new(attributes = M, lhs = A, rhs = B)
        Sigma$add(new_rule)
      }
    }

    # Compare Gamma and Sigma to check if they are equal %~%
    if (Gamma %~% Sigma) {
      break
    }


  }
}


Minimals <- function(Gamma, X, M) {
  minimal_sets <- list()

  for (i in 1:Gamma$cardinality()) {
    rule <- Gamma[i]
    A <- rule$get_LHS_matrix()
    B <- rule$get_RHS_matrix()


  }
}

# Crear un ImplicationSet a partir de los datos planets
fc_planets <- FormalContext$new(planets)
fc_planets$find_implications()
implications_planets <- fc_planets$implications
Gamma <- implications_planets
X

mins <- Minimals(implications_planets)
