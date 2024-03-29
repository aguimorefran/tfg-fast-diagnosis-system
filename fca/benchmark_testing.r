source("FDS_dataloader.r")
source("FDS_engine.r")
source("FDS_benchmark.r")

age_range <- 10
rowstrain <- 2000
rowsvalidate <- 1000
dfs <- fetch_train_validate(rowstrain = rowstrain, rowsvalidate = rowsvalidate, age_range = age_range)

fc_savefolder <- "formalcontexts/"
fc_savename <- paste0(format(Sys.Date(), "%d%m%y"), "_", rowstrain, "_", age_range)
fc_savename <- paste0(fc_savefolder, fc_savename, ".rds")
fc_savename

train_sparse_df <- dfs$train_df
validate_sparse_df <- dfs$validate_df

cond_names <- fetch_conditions()
ev_names <- fetch_evidences()

# fc <- create_formal_context(train_sparse_df, fc_savename)
# fc <- apply_rules_formal_context(fc_savename)

# Load RDS fca/formalcontexts/010623_2000_10.rds
fc <- readRDS("formalcontexts/010623_3000_10.rds")

scale <- c(.75, 1)
set.seed(as.integer(as.numeric(Sys.time()) * 10^6) + rowstrain)
# b <- benchmark(
#   df = validate_sparse_df,
#   fc = fc,
#   cond_names = cond_names,
#   ev_names = ev_names,
#   max_it = 20,
#   scale = scale,
#   debug = F,
#   train_rows = rowstrain
# )

d <- manual_diagnosis(
  fc = fc,
  cond_names = cond_names,
  ev_names = ev_names,
  sex = "SEX_M",
  age = 30,
  scale = scale,
  max_it = 20,
  debug = T
)
