# FAST DIAGNOSIS SYSTEM ENGINE
# BASED ON FCA
packages <- c("fcaR", "jsonlite", "Matrix")
for (package in packages) {
    if (!require(package, character.only = TRUE)) {
        install.packages(package, dependencies = TRUE, repos = "http://cran.us.r-project.org")
    }
    library(package, character.only = TRUE)
}


get_value <- function(json_object, name, value) {
    result <- NULL
    if (is.null(json_object)) {
        return(result)
    }

    if (name %in% names(json_object)) {
        sub_json <- json_object[[name]]
        if (is.list(sub_json)) {
            if (value %in% names(sub_json)) {
                result <- sub_json[[value]]
            }
        }
    }

    return(result)
}

load_source_file <- function(filename, nrows, sparse = FALSE) {
    df <- read.csv(filename, stringsAsFactors = FALSE)
    df <- df[sample(nrow(df), min(nrow(df), nrows)), ]

    df <- df[, c("AGE", "SEX", "EVIDENCES", "PATHOLOGY", "INITIAL_EVIDENCE")]
    df$EVIDENCES <- gsub("\\[|\\]|'", "", df$EVIDENCES)
    df$EVIDENCES <- sapply(strsplit(df$EVIDENCES, ","), function(x) trimws(x))
    df$EVIDENCES <- sapply(df$EVIDENCES, trimws)
    df$EVIDENCES <- sapply(df$EVIDENCES, function(x) gsub("@.*", "", x))
    df$EVIDENCES <- sapply(df$EVIDENCES, function(x) gsub("_$", "", x))

    # Categorize age
    df$AGE <- cut(df$AGE, breaks = seq(0, 100, by = 20), labels = FALSE, include.lowest = TRUE)
    df <- df[!is.na(df$AGE), ]
    df$AGE <- paste0("AGE_", df$AGE)

    if (!sparse) {
        return(df)
    }

    # Create sparse dataframe
    sparse_df <- data.frame(
        matrix(
            0,
            nrow = nrow(df),
            ncol = length(ev_names) + length(cond_names) + 6 + 2 # 6 for age categories, 2 for sex categories
        )
    )
    colnames(sparse_df) <- c(ev_names, cond_names, paste0("AGE_", 1:6), "SEX_M", "SEX_F")

    for (i in 1:nrow(df)) {
        if (i %% 100 == 0) {
            print(paste0("Row ", i, " of ", nrow(df)))
        }
        row <- df[i, ]
        evidence <- unlist(row$EVIDENCES)
        pathology <- row$PATHOLOGY
        initial_evidence <- row$INITIAL_EVIDENCE
        age <- row$AGE
        sex <- paste0("SEX_", row$SEX)

        # set in df the columns that match evidences, conditions, pathology, age and sex
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

init_fc <- function(df, save_file, debug = TRUE, concepts = FALSE) {
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

    colMeans(fc$implications$size())
    if (debug) {
        print("Applying simplification rules")
        print(colMeans(fc$implications$size()))
    }
    fc$implications$apply_rules(rules = c("simplification", "rsimplification"), parallelize = .Platform$OS.type == "unix")

    if (debug) {
        print(colMeans(fc$implications$size()))
    }
    endtime <- Sys.time()
    res <- list(fc = fc, elapsed = endtime - starttime)

    saveRDS(res, save_file)
    return(res)
}

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
    # return values > 0
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

benchmark <- function(df, fc, cond_names, ev_names, max_it, scale, samples = nrow(df), debug = FALSE) {
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

                # Get the actual pathology name from the column names
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
        #Print progress each 10%
        if (i %% (samples / 10) == 0) {
            print(paste0("Progress: ", round(i / samples * 100, 2), "%"))
        }
    }

    return(results)
}

bench_summary <- function(benchmark_df) {
    total_tests <- nrow(benchmark_df)
    error_cases <- sum(benchmark_df$Error != "")
    error_rate <- error_cases / total_tests
    mean_score <- mean(benchmark_df$Score, na.rm = TRUE)
    max_score <- max(benchmark_df$Score, na.rm = TRUE)
    correct_diagnoses <- sum(benchmark_df$Score == 1, na.rm = TRUE)
    correct_rate <- correct_diagnoses / total_tests

    result_summary <- data.frame(
        Total_Tests = total_tests,
        Error_Cases = error_cases,
        Error_Rate = error_rate,
        Mean_Score = mean_score,
        Max_Score = max_score,
        Correct_Diagnoses = correct_diagnoses,
        Correct_Rate = correct_rate
    )

    return(result_summary)
}
