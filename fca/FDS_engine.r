# FAST DIAGNOSIS SYSTEM ENGINE
# BASED ON FCA
packages <- c("fcaR", "Matrix", "RJDBC", "ggplot2", "dplyr", "tidyr")
for (package in packages) {
    if (!require(package, character.only = TRUE)) {
        install.packages(package, dependencies = TRUE, repos = "http://cran.us.r-project.org")
    }
    library(package, character.only = TRUE)
}

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


#' @title Ask symptom console
#' @description Ask symptom and degree from console to the user
#' @param fc A fcaR::FormalContext object
#' @param symptom A symptom
#' @param scale A scale
#' @param debug Whether to print debug messages or not
#' @return A list containing the symptom and the degree
ask_symptom_console <- function(fc, symptom, scale, debug = FALSE) {
    if (debug) {
        print("################ ASKING SYMPTOM ################")
    }

    symptom <- readline("Symptom: ")

    question <- paste0(
        "Degree of ", symptom, " (", paste(scale, collapse = ", "), "): "
    )
    degree <- as.numeric(readline(question))
    if (degree < 0 | degree > 1) {
        stop("Degree must be between 0 and 1")
    }
    return(list(symptom = symptom, degree = degree))
}

#' @title Create a fcaR::Set object
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

ask_upgrade_symptoms <- function(fc, S) {
    Svecs <- S$get_vector()
    Satts <- S$get_attributes()
    idx <- which(Svecs[, 1] > 0)
    df <- data.frame(
        symptom = Satts[idx],
        degree = Svecs[idx, 1]
    )

    for (i in 1:nrow(df)) {
        if (df$degree[i] < 1) {
            question <- paste0(
                "Upgrade ", df$symptom[i], " from ", df$degree[i], " to 1? (y/n) "
            )
            upgrade <- readline(question)
            if (upgrade == "y") {
                df$degree[i] <- 1
            } else if (upgrade == "n") {
                df$degree[i] <- 0
            } else {
                stop("Invalid input")
            }
        }
    }

    # Create new set
    S <- Set$new(fc$attributes)
    for (i in 1:nrow(df)) {
        S$assign(attributes = df$symptom[i], values = df$degree[i])
    }

    any_changes <- !identical(S$get_vector(), Svecs)

    return(list(S = S, any_changes = any_changes, df = df))
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

manual_diagnosis <- function(fc, cond_names, ev_names, sex, age, max_it, scale, debug = FALSE) {
    cat_age <- age
    S <- create_set(fc, NULL, c(sex, cat_age), c(1, 1))
    i <- 1
    diag <- c()

    if (debug) {
        print(paste0("Age category: ", cat_age))
        print(paste0("Sex: ", sex))
    }

    while (i < max_it && length(diag) == 0) {
        if (debug) {
            print(paste0("################ ITERATION ", i, " ################"))
        }

        # STEP 1 ASK SYMPTOM
        x <- ask_new_symptom(ev_names, scale, debug)

        # STEP 2 COMPUTE CLOSURE
        S <- create_set(fc, S, x$symptom, x$degree)
        diag <- diagnose(fc, S, cond_names, debug)

        # STEP 3 CHECK CLOSURE
        if (length(diag) > 0) {
            if (debug) {
                print("################ DIAGNOSIS FOUND ################")
                print(paste0("Diagnosis: ", diag))
            }
            return(list(
                diagnosis = diag,
                iteration = i,
                set = S
            ))
        }

        # STEP 5 REPEAT FROM STEP 1
        i <- i + 1
        if (i == max_it) {
            print("Maximum number of iterations reached")
            return(list(
                diagnosis = NULL,
                iteration = i,
                set = S
            ))
        }
    }
}


automatic_diagnosis <- function(fc, cond_names, ev_names, sex, age, max_it, scale, hardcoded_symptoms, debug = FALSE) {
    cat_age <- age
    S <- create_set(fc, NULL, c(sex, cat_age), c(1, 1))
    i <- 1
    diag <- c()

    if (debug) {
        print(paste0("Age category: ", cat_age))
        print(paste0("Sex: ", sex))
    }

    while (i < max_it && length(diag) == 0) {
        if (debug) {
            print(paste0("################ ITERATION ", i, " ################"))
        }
        # STEP 1 ASK SYMPTOM
        x <- hardcoded_symptoms[[i]]

        # STEP 2 COMPUTE CLOSURE
        S <- create_set(fc, S, x$symptom, x$degree)
        diag <- diagnose(fc, S, cond_names, debug)

        # STEP 3 CHECK CLOSURE
        if (length(diag) > 0) {
            if (debug) {
                print("################ DIAGNOSIS FOUND ################")
                print(paste0("Diagnosis: ", diag))
            }
            return(list(
                diagnosis = diag,
                iteration = i,
                set = S
            ))
        }

        # STEP 5 REPEAT FROM STEP 1
        i <- i + 1
        if (i == max_it) {
            print("Maximum number of iterations reached")
            return(list(
                diagnosis = NULL,
                iteration = i,
                set = S
            ))
        }
    }
}