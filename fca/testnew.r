source("fca/FDG_engine.r")

# Define file paths
evidences_file <- "fca/resources/dataset/release_evidences.json"
conditions_file <- "fca/resources/dataset/release_conditions.json"
train_file <- "fca/resources/dataset/release_train_patients.csv"
test_file <- "fca/resources/dataset/release_test_patients.csv"
validate_file <- "fca/resources/dataset/release_validate_patients.csv"
fc_savename <- paste0("fca/resources/dataset/fc_release_", format(Sys.time(), "%d%m%Y_%H%M%S"), ".rds")

# Load data from JSON files
evidences <- fromJSON(evidences_file)
conditions <- fromJSON(conditions_file)

# Get names from evidences and conditions
ev_names <- names(evidences)
cond_names <- names(conditions)

# Load training data
n_rows_fc <- 500
train_sparse_df <- load_source_file(train_file, n_rows_fc, sparse = TRUE)
validate_sparse_df <- load_source_file(validate_file, 1000, sparse = TRUE)

# Init fc
initfc <- init_fc(train_sparse_df, fc_savename, debug = TRUE, concepts = T)

# Load Formal Concept Analysis (FCA) data
# initfc <- readRDS("fca/resources/dataset/fc_release_24052023_090721.rds")

fc <- initfc$fc
elapsed <- initfc$elapsed

scale <- c(.75, 1)

i <- 233
row <- validate_sparse_df[i, ]
sex <- ifelse(row$SEX_M == 1, "SEX_M", "SEX_F")
age <- paste0("AGE_", which(row[paste0("AGE_", 1:6)] == 1))
hardcoded_symptoms <- names(row)[row == 1]
hardcoded_symptoms <- hardcoded_symptoms[!hardcoded_symptoms %in% c(sex, age, cond_names)]
hardcoded_symptoms <- lapply(hardcoded_symptoms, function(symptom) list(symptom = symptom, degree = 1))

d <- automatic_diagnosis(
  fc = fc,
  cond_names = cond_names,
  ev_names = ev_names,
  sex = "SEX_M",
  age = 15,
  max_it = 25,
  scale = scale,
  hardcoded_symptoms = hardcoded_symptoms,
  debug = FALSE
)

b <- benchmark(
  df = validate_sparse_df,
  fc = fc,
  cond_names = cond_names,
  ev_names = ev_names,
  max_it = 20,
  scale = scale,
  samples = 100,
  debug = F
)


bench_summary(b)
