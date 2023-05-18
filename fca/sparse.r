chooseCRANmirror(ind = 1)
# install.packages(c("fcaR", "RJDBC", "tidyverse", "dplyr", "DBI", "devtools"), dependencies = TRUE, type = "source", INSTALL_opts = "--no-lock", ask = FALSE, repos = "http://cran.r-project.org")

if(!require(arules)) install.packages("arules")
if(!require(fcaR)) install.packages("fcaR")
if(!require(RJDBC)) install.packages("RJDBC")
if(!require(dplyr)) install.packages("dplyr")
if(!require(tidyr)) install.packages("tidyr")
if(!require(devtools)) install.packages("devtools")
if(!require(Matrix)) install.packages("Matrix")
if(!require(tidyr)) install.packages("tidyr")

library(arules)
library(fcaR)
library(RJDBC)
library(dplyr)
library(tidyr)
library(devtools)
library(Matrix)
library(tidyr)


install.packages("BiocManager", dependencies = TRUE, type = "source", INSTALL_opts = "--no-lock", ask = FALSE, repos = "http://cran.r-project.org")
BiocManager::install("Rgraphviz", ask = FALSE)

install.packages("hasseDiagram", dependencies = TRUE, type = "source", INSTALL_opts = "--no-lock", ask = FALSE, repos = "http://cran.r-project.org")


jdbc_driver_path <- "fca/resources/CassandraJDBC42.jar"
jdbc_driver_class <- "com.simba.cassandra.jdbc42.Driver"

if (!file.exists(jdbc_driver_path)) {
  stop("File not found: ", jdbc_driver_path)
}

########## STEP 1: Fetch data from Cassandra

cassandra_host <- "0.0.0.0"
cassandra_port <- 9042
cassandra_keyspace <- "fds"

cassdrv <- JDBC(jdbc_driver_class, jdbc_driver_path, identifier.quote = "`")
conn <- dbConnect(cassdrv, paste0("jdbc:cassandra://", cassandra_host, ":", cassandra_port, ";AuthMech=0;Keyspace=", cassandra_keyspace))

dis_df <- dbGetQuery(conn, "SELECT * FROM fds.diseases")
symp_df <- dbGetQuery(conn, "SELECT * FROM fds.symptoms")

relations <- dbGetQuery(conn, "SELECT * FROM fds.diseases_vt_symptoms")

########### STEP 2: Create the sparse matrix

# Primero, debemos convertir la columna "id" de los dataframes a factor para que coincidan los tipos de datos
dis_df$id <- as.factor(dis_df$id)
symp_df$id <- as.factor(symp_df$id)

# Unimos los dataframes de enfermedades y síntomas
merged_df <- merge(symp_df, relations, by.x = "id", by.y = "symptoms_value")
merged_df <- merge(merged_df, dis_df, by.x = "id.y", by.y = "id")

# Creamos dataframes separados para síntomas y enfermedades
symptom_df <- merged_df[, c("id.x", "name.x")]
colnames(symptom_df) <- c("id", "symptom")
disease_df <- merged_df[, c("id.y", "name.y")]
colnames(disease_df) <- c("id", "disease")

# Hacemos una codificación one-hot para los síntomas y las enfermedades
symptom_one_hot <- reshape2::dcast(symptom_df, id ~ symptom, length)
disease_one_hot <- reshape2::dcast(disease_df, id ~ disease, length)

# Unimos los dataframes de síntomas y enfermedades
final_df <- merge(symptom_one_hot, disease_one_hot, by = "id")

# Eliminamos la columna id
final_df$id <- NULL

# Convertimos el dataframe final en una matriz dispersa
sparse_matrix <- as(final_df, "sparseMatrix")
