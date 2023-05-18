data <- read.csv("fca/disease_symptoms.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))

data <- data.frame(lapply(data, tolower))
data <- data.frame(lapply(data, function(x) gsub(" ", "_", trimws(x))))
data <- data[!duplicated(data), ]

diseases <- unique(data$Disease)

symptoms <- unique(unlist(data[, -1]))

co_occurrence <- data.frame(matrix(0, nrow = length(diseases), ncol = length(symptoms)))
colnames(co_occurrence) <- symptoms
rownames(co_occurrence) <- diseases

for (i in 1:nrow(data)) {
    disease <- data$Disease[i]
    for (j in 2:ncol(data)) {
        symptom <- data[i, j]
        if (!is.na(symptom)) {
            co_occurrence[disease, symptom] <- co_occurrence[disease, symptom] + 1
        }
    }
}

# Normalize the co_occurrence matrix by the max count for each disease
co_occurrence <- co_occurrence / apply(co_occurrence, 1, max)

df <- data.frame(matrix(0, nrow = nrow(data), ncol = length(diseases) + length(symptoms)))
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
df[df >= 0.75 & df < 1] <- 0.75


# print first 10 colnames from df
colnames(df)[1:50]

# Load FDG.r
library(fcaR)


################ STEP 1: INITIALIZE FORMAL CONTEXT ################
# fc <- FormalContext$new(df)
# fc$find_implications()
# # save rds
# saveRDS(fc, "fca/fc.rds")
# load rds
fc <- readRDS("fca/fc.rds")

colMeans(fc$implications$size())
fc$implications$apply_rules(rules = c("simplification", "rsimplification"), parallelize = TRUE)
colMeans(fc$implications$size())

S1 <- Set$new(attributes = fc$attributes, itching = 1, ulcers_on_tongue = .5)
S1

diag <- diagnose(fc, S1, diseases)

get_asked <- function(S) {
    return(S$get_attributes()[S$get_vector()[, 1] != 0])
}

min_implication <- function(imps) {
    size <- imps$size()
    sorted_indices <- order(size[, "LHS"], size[, "RHS"])
    min_idx <- sorted_indices[1]
    return(imps[sorted_indices[1]])
}

cl <- fc$implications$closure(S1, reduce = TRUE)
cl$implications$apply_rules(c("simp", "rsimp", "reorder"), parallelize = TRUE)
closure <- cl$implications$filter(
    rhs = diseases,
    not_lhs = diseases,
    drop = TRUE
)

toask <- min_implication(closure)


