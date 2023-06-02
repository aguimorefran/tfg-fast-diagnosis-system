packages <- c("fcaR", "Matrix", "RJDBC", "ggplot2", "dplyr", "tidyr")
for (package in packages) {
    if (!require(package, character.only = TRUE)) {
        install.packages(package, dependencies = TRUE, repos = "http://cran.us.r-project.org")
    }
    library(package, character.only = TRUE)
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
    mean_score <- mean(benchmark_results$Score, na.rm = TRUE)
    error_count <- sum(benchmark_results$Error != "", na.rm = TRUE)
    mean_iterations <- mean(benchmark_results$Iteration, na.rm = TRUE)
    successful_diagnoses <- sum(benchmark_results$Score > 0, na.rm = TRUE)
    failed_diagnoses <- sum(benchmark_results$Score == 0, na.rm = TRUE)
    proportion_successful <- successful_diagnoses / nrow(benchmark_results)
    proportion_failed <- failed_diagnoses / nrow(benchmark_results)

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

    dir_name <- "fca/benchmarks"
    if (!dir.exists(dir_name)) {
        dir.create(dir_name, recursive = TRUE)
    }
    csv_path <- paste0(dir_name, "/benchmark_results.csv")

    if (file.exists(csv_path)) {
        existing_data <- read.csv(csv_path, stringsAsFactors = FALSE, check.names = FALSE)
        new_data <- rbind(existing_data, benchmark_row)
    } else {
        new_data <- benchmark_row
    }

    write.csv(new_data, csv_path, row.names = FALSE, quote = FALSE)

    return(new_data)
}
analyze_benchmarks <- function() {
    dir_name <- "fca/benchmarks"
    if (!dir.exists(dir_name)) {
        dir.create(dir_name, recursive = TRUE)
    }
    csv_path <- paste0(dir_name, "/benchmark_results.csv")

    benchmarks <- read.csv(csv_path)

    print("Head of the data:")
    print(head(benchmarks))

    print("Summary of the data:")
    print(summary(benchmarks))

    scatter_plot <- ggplot(benchmarks, aes(x = n, y = score)) +
        geom_point() +
        geom_smooth(method = lm, se = FALSE, color = "blue") +
        geom_smooth(method = "loess", formula = "y ~ log(x)", se = FALSE, color = "red") +
        labs(
            title = "Scatterplot of n vs Score with Linear and Logarithmic Regression",
            x = "n",
            y = "Score",
            caption = "Blue: Linear regression line; Red: Logarithmic regression line"
        ) +
        theme_light()

    ggsave(filename = paste0(dir_name, "/scatter_plot.png"), plot = scatter_plot)

    box_plot <- ggplot(benchmarks, aes(x = factor(n), y = score)) +
        geom_boxplot() +
        labs(
            title = "Boxplot of Score by n",
            x = "n",
            y = "Score"
        ) +
        theme_light()

    ggsave(filename = paste0(dir_name, "/box_plot.png"), plot = box_plot)

    density_plot <- ggplot(benchmarks, aes(x = score)) +
        geom_density(fill = "steelblue") +
        labs(
            title = "Density plot of Score",
            x = "Score"
        ) +
        theme_light()

    ggsave(filename = paste0(dir_name, "/density_plot.png"), plot = density_plot)

    linear_regression_model <- lm(score ~ n, data = benchmarks)
    print(summary(linear_regression_model))
    n_linear <- (0.9 - linear_regression_model$coefficients[1]) / linear_regression_model$coefficients[2]

    log_regression_model <- lm(score ~ log(n), data = benchmarks)
    print(summary(log_regression_model))
    n_log <- exp((0.9 - log_regression_model$coefficients[1]) / log_regression_model$coefficients[2])

    sink(paste0(dir_name, "/statistics.txt"))
    cat("Head of the data:\n")
    print(head(benchmarks))
    cat("\nSummary of the data:\n")
    print(summary(benchmarks))
    cat("\nLinear regression model summary:\n")
    print(summary(linear_regression_model))
    cat("\nApprox. number of rows for R2 > 0.9 in linear regression: ", round(n_linear, 0), "\n")
    cat("\nLogarithmic regression model summary:\n")
    print(summary(log_regression_model))
    cat("\nApprox. number of rows for R2 > 0.9 in logarithmic regression: ", round(n_log, 0), "\n")
    sink()
}


benchmark <- function(df, fc, cond_names, ev_names, max_it, scale, train_rows, samples = nrow(df), debug = FALSE) {
    results <- data.frame(
        Iteration = integer(),
        Final_Diagnosis = character(),
        Score = double(),
        Error = character()
    )

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
    analyze_benchmarks()

    return(results)
}
