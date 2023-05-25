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
    fc$implications$apply_rules(rules = c("simplification", "rsimplification"), parallelize = TRUE)

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
    # S$assign(attributes = symptoms, values = values)
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
        parallelize = TRUE
    )
    closure$implications$filter(
        rhs = target,
        not_lhs = target, drop = TRUE
    )
    return(closure)
}

get_remaining_attributes <- function(S, closure, symptoms) {
    # get already asked symptoms
    asked <- S$get_attributes()[S$get_vector()[, 1] > 0]

    lhs <- closure$implications$get_LHS_matrix()
    remaining <- rownames(lhs)[apply(lhs, 1, function(x) any(x == 1))]

    # intersect remaining with symptoms and remove already asked symptoms
    remaining <- intersect(remaining, symptoms)
    remaining <- setdiff(remaining, asked)
    return(remaining)
}

ask_upgrade_symptoms <- function(fc, S) {
    Svecs <- S$get_vector()
    Satts <- S$get_attributes()
    idx <- which(Svecs[, 1] > 0)
    df <- data.frame(
        symptom = Satts[idx],
        degree = Svecs[idx, 1]
    )

    # For every symptom, ask if it should be upgraded if its grade is less tan 1
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


iterative_diagnosis <- function(fc, cond_names, ev_names, sex, age, max_it, scale, debug = FALSE) {
    cat_age <- categorize_age(age)
    S <- create_set(fc, NULL, c(sex, cat_age), c(1, 1))
    i <- 1
    diag <- c()
    reamining_symps <- ev_names

    if (debug) {
        print(paste0("Age category: ", cat_age))
        print(paste0("Sex: ", sex))
    }

    while (i < max_it && length(diag) == 0) {
        if (debug) {
            print(paste0("################ ITERATION ", i, " ################"))
            print(paste0("Remaining symptoms: ", paste(length(reamining_symps), collapse = ", ")))
        }
        # STEP 1 ASK SYMPTOM
        x <- ask_symptom_console(fc, cond_names, scale, debug)

        # STEP 2 COMPUTE CLOSURE
        S <- create_set(fc, S, x$symptom, x$degree)
        S$print()
        diag <- diagnose(fc, S, cond_names, debug)

        # STEP 3 CHECK CLOSURE
        if (length(diag) > 0) {
            return(list(
                diagnosis = diag,
                set = S,
                iteration = i
            ))
        }

        # # STEP 4 ASK FOR IMPROVING
        # x <- ask_upgrade_symptoms(fc, S)
        # S <- x$S

        # # STEP 4.1 CHECK IF ANY CHANGES
        # S$print()

        # # STEP 4.2 COMPUTE CLOSURE
        # diag2 <- diagnose(fc, S, cond_names, debug)

        # # STEP 4.3 CHECK CLOSURE
        # if (length(diag2) > 0) {
        #     return(list(
        #         diagnosis = diag2,
        #         set = S,
        #         iteration = i
        #     ))
        # }


        # STEP 5 REPEAT FROM STEP 1
        i <- i + 1
        if (i == max_it) {
            print("Maximum number of iterations reached")
            return(list(
                diagnosis = NULL,
                set = S,
                iteration = i
            ))
        }
        closure <- compute_closure(fc, S, cond_names, debug)
        reamining_symps <- get_remaining_attributes(S, closure, ev_names)
        print(paste0("Passing from ", length(ev_names), " to ", length(reamining_symps), " symptoms"))
        print(paste0("Reduced by ", round(100 * (1 - length(reamining_symps) / length(ev_names)), 2), "%"))
    }
}


automatic_diagnosis <- function(fc, cond_names, ev_names, sex, age, max_it, scale, hardcoded_symptoms, debug = FALSE) {
    cat_age <- age
    S <- create_set(fc, NULL, c(sex, cat_age), c(1, 1))
    i <- 1
    diag <- c()
    remaining_symps <- ev_names

    if (debug) {
        print(paste0("Age category: ", cat_age))
        print(paste0("Sex: ", sex))
    }

    while (i < max_it && length(diag) == 0) {
        if (debug) {
            print(paste0("################ ITERATION ", i, " ################"))
            print(paste0("Remaining symptoms: ", paste(length(remaining_symps), collapse = ", ")))
        }
        # STEP 1 ASK SYMPTOM
        x <- hardcoded_symptoms[[i]]

        # STEP 2 COMPUTE CLOSURE
        S <- create_set(fc, S, x$symptom, x$degree)
        S$print()
        diag <- diagnose(fc, S, cond_names, debug)

        # STEP 3 CHECK CLOSURE
        if (length(diag) > 0) {
            return(list(
                diagnosis = diag,
                iteration = i,
                set = S,
                closure = compute_closure(fc, S, cond_names, debug)
            ))
        }

        # # STEP 4 COMPUTE CLOSURE
        # diag2 <- diagnose(fc, S, cond_names, debug)

        # # STEP 4.3 CHECK CLOSURE
        # if (length(diag2) > 0) {
        #     return(list(
        #         diagnosis = diag2,
        #         set = S,
        #         iteration = i
        #     ))
        # }

        # STEP 5 REPEAT FROM STEP 1
        i <- i + 1
        if (i == max_it) {
            print("Maximum number of iterations reached")
            return(list(
                diagnosis = NULL,
                iteration = i,
                set = S,
                closure = compute_closure(fc, S, cond_names, debug)
            ))
        }
        closure <- compute_closure(fc, S, cond_names, debug)
        remaining_symps <- get_remaining_attributes(S, closure, ev_names)
        print(paste0("Passing from ", length(ev_names), " to ", length(remaining_symps), " symptoms"))
        print(paste0("Reduced by ", round(100 * (1 - length(remaining_symps) / length(ev_names)), 2), "%"))
    }
}

benchmark_model_from_csv <- function(fc, cond_names, ev_names, validate_df, max_it, scale, samples, debug = FALSE) {
    # Initialize results dataframe
    results <- data.frame(
        row = integer(),
        diagnosis = character(),
        expected_diagnosis = character(),
        iteration = integer(),
        elapsed_time = numeric(),
        error = logical(),
        correct = logical()
    )

    # Initialize set list
    set_list <- list()

    # Take samples from the validation dataframe
    set.seed(Sys.time())
    validate_df <- validate_df[sample(nrow(validate_df), samples), ]

    # Loop over each row in the validation dataframe. Reorganize the dataframe randomly
    for (i in 1:nrow(validate_df)) {
        # Extract information for automatic diagnosis
        row <- validate_df[i, ]
        sex <- ifelse(row$SEX_M == 1, "SEX_M", "SEX_F")
        age <- paste0("AGE_", which(row[paste0("AGE_", 1:6)] == 1))
        hardcoded_symptoms <- names(row)[row == 1]
        hardcoded_symptoms <- hardcoded_symptoms[!hardcoded_symptoms %in% c(sex, age, cond_names)]

        # Convert hardcoded_symptoms to list of lists
        hardcoded_symptoms <- lapply(hardcoded_symptoms, function(symptom) list(symptom = symptom, degree = 1))

        # Call automatic diagnosis function and measure elapsed time
        start_time <- Sys.time()
        error_occurred <- FALSE
        d <- tryCatch(
            {
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
            error = function(e) {
                error_occurred <- TRUE
                print(paste0("Error in row ", i, ": ", e$message))
                NULL
            }
        )

        elapsed_time <- Sys.time() - start_time

        # Add results to dataframe
        results <- rbind(results, data.frame(
            row = i,
            diagnosis = paste(d$diagnosis, collapse = ", "),
            expected_diagnosis = paste(names(row)[row == 1 & names(row) %in% cond_names], collapse = ", "),
            iteration = d$iteration,
            elapsed_time = elapsed_time,
            error = error_occurred,
            correct = all(names(row)[row == 1 & names(row) %in% cond_names] %in% d$diagnosis)
        ))

        # Print progress
        if (i %% 100 == 0) {
            print(paste0("Processed ", i, " rows"))
        }
    }

    return(results = results)
}
