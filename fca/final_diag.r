library(fcaR)

# Inicializa el formal context
init_fc <- function(data) {
    fc <- FormalContext$new(data)
    fc$find_implications(verbose = TRUE)
    fc$implications$apply_rules(rules = c("simplification", "rsimplification"))
    return(fc)
}

# Crea un Set inicial
init_set <- function(fc, seed, seed_value) {
    S <- Set$new(attributes = fc$attributes)
    S$assign(attributes = seed, values = seed_value)
    return(S)
}

# Obtiene el diagnóstico y el siguiente síntoma a preguntar
get_diagnosis <- function(fc, S, interest, asked) {
    diag <- fc$implications$recommend(S, interest)
    diag_found <- names(diag[diag == 1])

    if (length(diag_found) > 0) {
        return(list(diag_found, NULL, S))
    } else {
        cl <- fc$implications$closure(S, reduce = TRUE)
        cl$implications$apply_rules(c("simp", "rsimp", "reorder"))
        nxt <- cl$implications$filter(rhs = interest, not_lhs = interest, drop = TRUE)
        # print nxt in console
        print(nxt)
        toask <- next_symptom(nxt, S, asked)
        return(list(NULL, toask, S))
    }
}

# Pregunta el grado del siguiente síntoma
ask_symptom_degree <- function(toask) {
    degree <- readline(prompt = paste("¿Cuál es el grado de", toask, "? (0-1)"))
    return(as.numeric(degree))
}

# Obtiene el próximo síntoma a preguntar
next_symptom <- function(implications, S, asked) {
    lhs <- implications$get_LHS_matrix()
    zeros <- Matrix::rowSums(lhs == 0)
    lhs <- lhs[order(zeros), ]
    # Remove from lhs those rows whose rownames are in asked
    lhs <- lhs[!(rownames(lhs) %in% asked), ]

    return(rownames(lhs)[1])
}

iterative_diagnosis <- function(fc, S1, seed, interest) {
    history <- list()
    diagnosis <- get_diagnosis(fc, S1, interest, asked = c())
    history[[1]] <- list(S1, diagnosis)
    counter <- 2
    asked <- c(seed)

    while (is.null(diagnosis[[1]])) {
        next_symptom <- diagnosis[[2]]
        degree <- ask_symptom_degree(next_symptom)
        asked <- c(asked, next_symptom)

        S_new <- diagnosis[[3]]$clone(deep = TRUE)
        S_new$assign(attributes = next_symptom, values = degree)
        print(S_new)

        diagnosis <- get_diagnosis(fc, S_new, interest, asked)
        history[[counter]] <- list(S_new, diagnosis)
        counter <- counter + 1
    }

    return(history)
}

# Inicializa el formal context
fc <- init_fc(cobre32)

# Crea un Set inicial
seed <- 'FICAL_6'
seedVal <- .5
S1 <- Set$new(attributes = fc$attributes)
S1$assign(attributes = seed, values = seedVal)

interest <- c("dx_ss", "dx_other")

# Inicia el proceso iterativo de diagnóstico
history <- iterative_diagnosis(fc, S1, seed, interest)

# Imprime el diagnóstico final
final_diagnosis <- tail(history, n = 1)[[1]][[2]][[1]]
print(paste("Diagnóstico final:", final_diagnosis))

# Print the history
print("Historial:")
for (i in 1:length(history)) {
    print("--------------------------------------------------")
    print(paste("Iteración", i))
    print(history[[i]][[1]])
    print(history[[i]][[2]])
}

# Test the diagnosis
Stest <- history[[length(history)]][[1]]

# Test the diagnosis with recommend
diag <- fc$implications$recommend(Stest, interest)
