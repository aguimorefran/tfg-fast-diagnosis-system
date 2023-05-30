source("fca/FDS_dataloader.r")
source("fca/FDS_engine.r")

age_range = 10
rowstrain = 500
rowsvalidate = 100
dfs <- fetch_train_validate(rowstrain = rowstrain, rowsvalidate = rowsvalidate, age_range = age_range)

fc_savefolder <- "fca/resources/formalcontexts/"
fc_savename <- paste0(format(Sys.Date(), "%d%m%y"), "_", rowstrain, "_", age_range)
fc_savename <- paste0(fc_savefolder, fc_savename, ".rds")
fc_savename

train_sparse_df <- dfs$train_df
validate_sparse_df <- dfs$validate_df
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
