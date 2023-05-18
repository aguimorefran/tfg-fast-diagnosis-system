# FAST DIAGNOSIS SYSTEM ENGINE
# BASED ON FCA

!if (!require(fcaR)) install.packages("fcaR")
library(fcaR)

#' Generate sparse dataframe
#'
#' Generate a sparse dataframe from a CSV file.
#' Saves dataframe, diseases and symptoms as RDS files.
#'
#' @param csv_file Path to the CSV file
#'
#' @param save_file Path to the RDS file
#'
#' @param diseases_file Path to the RDS file
#'
#' @param symptoms_file Path to the RDS file
#'
#' @return A dataframe with the sparse matrix
generate_sparse_dataframe <- function(csv_file,
                                      save_file,
                                      diseases_file,
                                      symptoms_file) {
    data <- read.csv(
        "fca/disease_symptoms.csv",
        stringsAsFactors = FALSE,
        na.strings = c("", "NA")
    )

    data <- data.frame(lapply(data, tolower))
    data <- data.frame(lapply(data, function(x) gsub(" ", "_", trimws(x))))
    data <- data[!duplicated(data), ]

    diseases <- unique(data$Disease)

    symptoms <- unique(unlist(data[, -1]))

    co_occurrence <- data.frame(
        matrix(
            0,
            nrow = length(diseases),
            ncol = length(symptoms)
        )
    )
    colnames(co_occurrence) <- symptoms
    rownames(co_occurrence) <- diseases

    for (i in 1:nrow(data)) {
        disease <- data$Disease[i]
        for (j in 2:ncol(data)) {
            symptom <- data[i, j]
            if (!is.na(symptom)) {
                co_occurrence[disease, symptom] <-
                    co_occurrence[disease, symptom] + 1
            }
        }
    }

    # Normalize the co_occurrence matrix by the max count for each disease
    co_occurrence <- co_occurrence / apply(co_occurrence, 1, max)

    df <- data.frame(
        matrix(
            0,
            nrow = nrow(data),
            ncol = length(diseases) + length(symptoms)
        )
    )
    colnames(df) <- c(diseases, symptoms)

    # Fill the dataframe based on the presence of diseases and symptoms
    for (i in 1:nrow(data)) {
        disease <- data$Disease[i]
        df[i, disease] <- 1
        for (j in 2:ncol(data)) {
            symptom <- data[i, j]
            if (!is.na(symptom)) {
                df[i, symptom] <- co_occurrence[disease, symptom]
            }
        }
    }

    # Round to the lowest quartile  0, 0.25, 0.5, 0.75, 1
    df[df < 0.25] <- 0
    df[df >= 0.25 & df < 0.5] <- 0.25
    df[df >= 0.5 & df < 0.75] <- 0.5
    df[df >= 0.75 & df <= 1] <- 0.75



    # Save the dataframe as an RDS file
    if (is.null(df)) {
        stop("No dataframe to save")
    }
    if (is.null(save_file)) {
        stop("No file to be saved")
    }
    saveRDS(df, save_file)
    saveRDS(diseases, diseases_file)
    saveRDS(symptoms, symptoms_file)

    return(df)
}

#' Create set
#'
#' Create a set from a formal context, a vector of attributes and a vector of values.
#' 
#' @param S Source Set. If none is provided, a new one is created
#'
#' @param fc A formal context
#'
#' @param attributes A vector with the attributes of the set
#'
#' @param values A vector with the values of the set
#'
#' @return A set
create_set <- function(source_S, fc, attributes, values) {
    # check source_S == NULL
    if (is.null(source_S)) {
        S <- Set$new(fc$attributes)
    } else {
        S <- source_S$clone(deep =TRUE)
    }
    S$assign(attributes = attributes, values = values)

    vector <- S$get_vector()
    if (!any(vector[, 1] == 1)) {
        stop("No attributes found")
    }
    return(S)
}

#' Diagnose
#'
#' Creates a recommendation from a formal context, a set and a set of target attributes.
#'
#' @param fc A formal context
#'
#' @param S A set
#'
#' @param target A target attribute
#'
#' @return A vector with the implications
diagnose <- function(fc, S, target) {
    d <- fc$implications$recommend(
        S = S,
        attribute_filter = target
    )

    d <- d[d != 0]
    return(d)
}

#' Initialize formal context
#'
#' Initialize a formal context from a dataframe.
#'
#' @param df A dataframe
#'
#' @param save_file Path to the RDS file
#'
#' @return A formal context
#'
init_fc <- function(df, save_file) {
    if (file.exists(save_file)) {
        load <- readline("Load existing formal context? (y/n) ")
        if (load == "y") {
            fc <- readRDS(save_file)
            return(fc)
        }
    }

    warn <- readline("This function takes long to run. Continue? (y/n) ")
    if (warn == "n") {
        stop("Function aborted")
    }
    fc <- FormalContext$new(df)
    fc$find_implications()

    colMeans(fc$implications$size())
    fc$implications$apply_rules(rules = c("simplification", "rsimplification"), parallelize = TRUE)
    colMeans(fc$implications$size())

    saveRDS(fc, save_file)
    return(fc)
}

#' Min implication
#'
#' Get the implication with the smallest LHS and RHS
#'
#' @param imps ImplicationSet object
#'
#' @return An implication
min_implication <- function(imps) {
    size <- imps$size()
    sorted_indices <- order(size[, "LHS"], size[, "RHS"])
    min_idx <- sorted_indices[1]
    return(imps[sorted_indices[1]])
}

#' Implication LHS names
#'
#' Get the names of the LHS of an implication
#'
#' @param imp An ImplicationSet
#'
#' @return A vector with the names of the LHS
imp_LHS_names <- function(imp) {
    lhs <- imp$get_LHS_matrix()
    return(rownames(lhs)[rowSums(lhs) != 0])
}

#' Get closure
#'
#' Get the closure of a set in a formal context
#'
#' @param fc A formal context
#'
#' @param S A set
#'
#' @return Closure of the set S in the formal context fc
get_closure <- function(fc, S) {
    cl <- fc$implications$closure(S, reduce = TRUE)
    cl$implications$apply_rules(c("simp", "rsimp", "reorder"), parallelize = TRUE)
    closure <- cl$implications$filter(
        rhs = diseases,
        not_lhs = diseases,
        drop = TRUE
    )
    return(closure)
}

#' Get asked
#'
#' Calculate the attributes that were asked to the user
#'
#' @param S A set
#'
#' @return A vector with the asked attributes
get_asked <- function(S) {
    return(S$get_attributes()[S$get_vector()[, 1] != 0])
}

#' Ask degree console
#'
#' Ask the user for the degree of a symptom
#'
#' @param symptom A symptom
#'
#' @return The degree of the symptom
ask_degree_console <- function(symptom) {
    degree <- readline(paste("What is the degree of", symptom, "? (0, 0.25, 0.5, 0.75, 1) "))
    degree <- as.numeric(degree)
    if (degree != 0 & degree != 0.25 & degree != 0.5 & degree != 0.75 & degree != 1) {
        stop("Invalid degree")
    }
    return(degree)
}

sourcefile <- "fca/disease_symptoms.csv"
savefile <- "fca/source_dataframe.rds"
savefile_fc <- "fca/fc.rds"
diseases_file <- "fca/diseases.rds"
symptoms_file <- "fca/symptoms.rds"

generate_sparse_dataframe(sourcefile, savefile, diseases_file, symptoms_file)

df <- readRDS(savefile)
diseases <- readRDS(diseases_file)
symptoms <- readRDS(symptoms_file)
fc <- init_fc(df, savefile_fc)
S <- create_set(NULL, fc, c("high_fever"), c(1))

diag <- diagnose(fc, S, diseases)
closure <- get_closure(fc, S)
min_rule <- min_implication(closure)
symps_to_ask <- imp_LHS_names(min_rule)
degree <- ask_degree_console(symps_to_ask[1])

S2 <- create_set(S, fc, symps_to_ask[1], degree)
diag2 <- diagnose(fc, S2, diseases)
diag2
closure2 <- get_closure(fc, S2)
min_rule2 <- min_implication(closure2)


fc$implications$recommend(S = S2, attribute_filter = diseases)

# Plot df as it is a sparse matrix
library(ggplot2)

# Create an image of the size of the dataframe and fill it with the value

rct <- expand.grid(x = 1:nrow(df), y = 1:ncol(df))
rct$fill <- as.vector(as.matrix(df))
ggplot(rct, aes(x = x, y = y, fill = fill)) + geom_tile() + scale_fill_gradient(low = "white", high = "black")
