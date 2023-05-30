source("fca/FDG_engine.r")

evidences_file <- "fca/resources/dataset/release_evidences.json"
conditions_file <- "fca/resources/dataset/release_conditions.json"
train_file <- "fca/resources/dataset/release_train_patients.csv"
test_file <- "fca/resources/dataset/release_test_patients.csv"
validate_file <- "fca/resources/dataset/release_validate_patients.csv"

evidences <- fromJSON(evidences_file)
conditions <- fromJSON(conditions_file)

ev_names <- names(evidences)
cond_names <- names(conditions)

n_rows_fc <- 1500
age_range <- 10

train_sparse_df <- load_source_file(train_file, n_rows_fc, sparse = TRUE, age_range = age_range)
validate_sparse_df <- load_source_file(validate_file, 1000, sparse = TRUE, age_range = age_range)

fc_savename <- paste0(format(Sys.Date(), "%d%m%y"), "_", n_rows_fc, "_", age_range)

initfc <- init_fc(train_sparse_df, fc_savename, debug = TRUE, concepts = FALSE)

initfc <- readRDS(fc_savename)

fc <- initfc$fc
elapsed <- initfc$elapsed

scale <- c(.75, 1)
samples <- 100
set.seed(Sys.time())
b <- benchmark(
  df = validate_sparse_df,
  fc = fc,
  cond_names = cond_names,
  ev_names = ev_names,
  max_it = 20,
  scale = scale,
  debug = F,
  samples = samples,
  train_rows = n_rows_fc
)
