# FAST DIAGNOSIS SYSTEM ENGINE
# BASED ON FCA
library("fcaR")
library("Matrix")
library("RJDBC")
library("ggplot2")
library("dplyr")
library("tidyr")

jdbc_driver_class <- "com.simba.cassandra.jdbc42.Driver"

create_formal_context <- function(df, save_file, debug = TRUE, concepts = FALSE) {
    starttime <- Sys.time()
    if (file.exists(save_file)) {
        load <- readline("Load existing formal context? (y/n) ")
        if (load == "y") {
            fc <- readRDS(save_file)
            return(fc)
        }
    }

    # warn <- readline("This function takes long to run. Continue? (y/n) ")
    # if (warn == "n") {
    #     stop("Function aborted")
    # }
    if (debug) {
        print("Generating formal context")
    }
    fc <- FormalContext$new(df)
    if (debug) {
        print("Generating implications")
    }
    fc$find_implications(verbose = debug, save_concepts = concepts)

    endtime <- Sys.time()
    print(paste0("Elapsed time: ", endtime - starttime))

    saveRDS(fc, save_file)
    return(fc)
}


apply_rules_formal_context <- function(fc_file, debug = TRUE) {
    if (!file.exists(fc_file)) {
        stop("File does not exist")
    }

    fc <- readRDS(fc_file)

    colMeans(fc$implications$size())
    if (debug) {
        print("Applying simplification rules")
        print(colMeans(fc$implications$size()))
    }
    starttime <- Sys.time()
    fc$implications$apply_rules(rules = c("simplification", "rsimplification"), parallelize = .Platform$OS.type == "unix")

    if (debug) {
        print(colMeans(fc$implications$size()))
    }
    endtime <- Sys.time()
    print(paste0("Elapsed time: ", endtime - starttime))

    saveRDS(fc, fc_file)
    return(fc)
}


create_set <- function(fc, S0, symptoms, values, debug = FALSE) {
    if (is.null(S0)) {
        S <- Set$new(fc$attributes)
    } else {
        S <- S0$clone(deep = TRUE)
    }
    for (i in 1:length(symptoms)) {
        S$assign(attributes = symptoms[i], values = values[i])
    }
    return(S)
}

diagnose <- function(fc, S, target, debug = FALSE) {
    if (debug) {
        print("################ DIAGNOSING ################")
    }
    d <- fc$implications$recommend(
        S,
        attribute_filter = target
    )
    return(names(d[d > 0]))
}

compute_closure <- function(fc, S, target, debug = FALSE) {
    if (debug) {
        print("################ COMPUTING CLOSURE ################")
    }
    closure <- fc$implications$closure(S, reduce = TRUE)
    closure$implications$apply_rules(
        c("simp", "rsimp", "reorder"),
        parallelize = .Platform$OS.type == "unix"
    )
    closure$implications$filter(
        rhs = target,
        not_lhs = target, drop = TRUE
    )
    return(closure)
}

ask_new_symptom <- function(ev_names, scale, debug = FALSE) {
    scale <- as.character(scale)
    if (debug) {
        print("################ ASKING NEW SYMPTOM ################")
    }
    symptom <- readline("Input new symptom\n")
    if (!symptom %in% ev_names) {
        print(paste0("Invalid input: ", symptom, " not in ev_names symptoms"))
        stop("Invalid symptom")
    }

    if (!is.character(scale)) {
        stop("Scale must be a character vector")
    }

    question <- paste0(
        "Degree of ", symptom, " (", paste(scale, collapse = ", "), "): "
    )
    degree <- as.numeric(readline(question))
    if (degree < 0 | degree > 1) {
        stop("Degree must be between 0 and 1")
    }
    return(list(symptom = symptom, degree = degree))
}


categorize_age <- function(age) {
    cat_age <- cut(age, breaks = seq(0, 100, by = 20), labels = FALSE, include.lowest = TRUE)
    cat_age <- paste0("AGE_", cat_age)
    return(cat_age)
}


##########################################################################
source("FDS_dataloader.r")

fc <- readRDS("formalcontexts/010623_3000_10.rds")
cond_names <- fetch_conditions()


get_diagnosis <- function(patient_data) {
    tryCatch(
        {
            patient_data <- jsonlite::fromJSON(patient_data)
        },
        error = function(e) {
            return(jsonlite::toJSON(list(status = "error", diagnosis = "Error al parsear el JSON.")))
        }
    )

    sex <- toupper(patient_data$sex)
    if (!sex %in% c("SEX_M", "SEX_F")) {
        return(jsonlite::toJSON(list(status = "error", diagnosis = "Sexo incorrecto. Debe ser 'SEX_M' o 'SEX_F'.")))
    }

    age <- patient_data$age
    cat_age <- categorize_age(age)

    symptoms <- patient_data$symptoms$name
    values <- patient_data$symptoms$degree

    S <- create_set(fc, NULL, c(sex, cat_age), c(1, 1))
    S <- create_set(fc, S, symptoms, values)

    print(S)

    result <- diagnose(fc, S, cond_names)

    status <- ifelse(length(result) > 0 & length(result) < length(cond_names),
        "success",
        ifelse(length(result) == 0,
            "missing_symptoms",
            "error"
        )
    )

    response <- list(
        status = status,
        diagnosis = result,
        patient_data = patient_data
    )

    return(response)
}
