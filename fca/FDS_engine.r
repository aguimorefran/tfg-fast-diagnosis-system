# FAST DIAGNOSIS SYSTEM ENGINE
# BASED ON FCA
packages <- c("fcaR", "Matrix", "RJDBC")
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

    warn <- readline("This function takes long to run. Continue? (y/n) ")
    if (warn == "n") {
        stop("Function aborted")
    }
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

ask_new_symptom <- function(remaining, scale, debug = FALSE) {
    if (debug) {
        print("################ ASKING NEW SYMPTOM ################")
    }
    symptom <- readline("Input new symptom")
    if (!symptom %in% remaining) {
        print(paste0("Invalid input: ", symptom, " not in remaining symptoms"))
        stop("Invalid symptom")
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

save_benchmark <- function(benchmark_results, n) {
    # Compute basic statistics
    mean_score <- mean(benchmark_results$Score, na.rm = TRUE)
    error_count <- sum(benchmark_results$Error != "", na.rm = TRUE)
    mean_iterations <- mean(benchmark_results$Iteration, na.rm = TRUE)
    successful_diagnoses <- sum(benchmark_results$Score > 0, na.rm = TRUE)
    failed_diagnoses <- sum(benchmark_results$Score == 0, na.rm = TRUE)
    proportion_successful <- successful_diagnoses / nrow(benchmark_results)
    proportion_failed <- failed_diagnoses / nrow(benchmark_results)

    # Create benchmark result row
    benchmark_row <- data.frame(
        n = n,
        errors = error_count,
        score = mean_score,
        mean_iterations = mean_iterations,
        successful_diagnoses = successful_diagnoses,
        failed_diagnoses = failed_diagnoses,
        proportion_successful = proportion_successful,
        proportion_failed = proportion_failed,
        date_added = Sys.Date()
    )

    # Update CSV file
    dir_name <- "fca/benchmarks"
    if (!dir.exists(dir_name)) {
        dir.create(dir_name, recursive = TRUE)
    }
    csv_path <- paste0(dir_name, "/benchmark_results.csv")

    if (file.exists(csv_path)) {
        # If the file already exists, load it and append the new row
        existing_data <- read.csv(csv_path, stringsAsFactors = FALSE, check.names = FALSE)
        new_data <- rbind(existing_data, benchmark_row)
    } else {
        # If the file doesn't exist, create it with the new row
        new_data <- benchmark_row
    }

    write.csv(new_data, csv_path, row.names = FALSE, quote = FALSE)

    return(new_data)
}

benchmark <- function(df, fc, cond_names, ev_names, max_it, scale, train_rows, samples = nrow(df), debug = FALSE) {
    results <- data.frame(
        Iteration = integer(),
        Final_Diagnosis = character(),
        Score = double(),
        Error = character()
    )

    # Select random samples from the dataframe
    set.seed(42)
    df <- df[sample(nrow(df), samples), ]

    for (i in 1:nrow(df)) {
        errorOccurred <- FALSE
        result <- try(
            {
                row <- df[i, ]
                sex <- ifelse(row$SEX_M == 1, "SEX_M", "SEX_F")
                age <- paste0("AGE_", which(row[paste0("AGE_", 1:6)] == 1))
                hardcoded_symptoms <- names(row)[row == 1]
                hardcoded_symptoms <- hardcoded_symptoms[!hardcoded_symptoms %in% c(sex, age, cond_names)]
                hardcoded_symptoms <- lapply(hardcoded_symptoms, function(symptom) list(symptom = symptom, degree = 1))

                pathology <- names(row)[row == 1 & names(row) %in% cond_names]

                automatic_diagnosis(
                    fc = fc,
                    cond_names = cond_names,
                    ev_names = ev_names,
                    sex = sex,
                    age = age,
                    max_it = max_it,
                    scale = scale,
                    hardcoded_symptoms = hardcoded_symptoms,
                    debug = debug
                )
            },
            silent = TRUE
        )

        if (inherits(result, "try-error")) {
            errorOccurred <- TRUE
            error_msg <- as.character(result)
            results <- rbind(results, data.frame(
                Iteration = NA,
                Final_Diagnosis = NA,
                Pathology = NA,
                Score = NA,
                Error = error_msg
            ))
        }

        if (!errorOccurred) {
            if (debug) {
                print(paste0("################ PATHOLOGY: ", pathology, " ################"))
            }
            if (is.null(result$diagnosis) || length(result$diagnosis) == 0) {
                final_diagnosis <- "NA"
                score <- 0
            } else {
                final_diagnosis <- paste(result$diagnosis, collapse = ",")
                if (pathology %in% result$diagnosis) {
                    score <- 1 / length(result$diagnosis)
                } else {
                    score <- 0
                }
            }
            results <- rbind(results, data.frame(
                Iteration = result$iteration,
                Final_Diagnosis = as.character(final_diagnosis),
                Pathology = as.character(pathology),
                Score = as.numeric(score),
                Error = ""
            ))
        }
        print(paste0("Progress: ", round(i / samples * 100, 2), "%"))
    }

    # Save results
    save_benchmark(results, n = train_rows)

    return(results)
}
