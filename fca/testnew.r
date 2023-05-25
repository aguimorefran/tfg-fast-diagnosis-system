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
# initfc <- init_fc(train_sparse_df, fc_savename, debug = TRUE, concepts = T)

# Load Formal Concept Analysis (FCA) data
initfc <- readRDS("fca/resources/dataset/fc_release_24052023_090721.rds")

fc <- initfc$fc
elapsed <- initfc$elapsed

scale <- c(.75, 1)

# d <- iterative_diagnosis(
#   fc = fc,
#   cond_names = cond_names,
#   ev_names = ev_names,
#   sex = "SEX_M",
#   age = 19,
#   max_it = 20,
#   scale = scale,
#   debug = TRUE
# )

# Benchmark model
benchmark <- benchmark_model_from_csv(
  fc = fc,
  cond_names = cond_names,
  ev_names = ev_names,
  validate_df = validate_sparse_df,
  max_it = 20,
  scale = scale,
  samples = 1,
  debug = TRUE
)


S <- benchmark$set[1]
S <- create_set(fc, NULL, S, rep(1, )
cl <- compute_closure(fc, S, cond_names, debug=TRUE)

auto <- automatic_diagnosis(
  fc = fc,
  cond_names = cond_names,
  ev_names = ev_names,
  sex = "SEX_M",
  age = "AGE_2",
  max_it = 20,
  scale = scale,
  hardcoded_symptoms = hardcoded_symptoms
)


cl <- diagnose(fc, S, cond_names, TRUE)
