#
#   Comparison of tuned RF, xgboost, and lightgbm
#

RUN_ID <- "run-11"

N_WORKERS <- 4L

# What is the data file name?
DATA_FILE <- here::here("create-data/output/states-v13.rds")
# What year to use as cutoff for the training data (inclusive)?
TRAIN_END <- 2013L  # last forecast window is 2004-2005
# What year to use as test data start (inclusive)?
TEST_START <- 2015L  # so the first forecast window is 2006-2007, i.e. not touching the last train fcast window

mg_file <- file.path("model-grid", sprintf("%s_mg.rds", RUN_ID))
res_file <- file.path("results", sprintf("%s_results.csv", RUN_ID))
chunk_dir <- file.path(sprintf("chunks_%s", RUN_ID))

t_script_start <- proc.time()

suppressPackageStartupMessages({
  library(lightgbm)
  library(ranger)
  library(xgboost)
  library(tibble)
  library(tidyr)
  library(dplyr)
  library(future)
  library(doFuture)
  library(demspaces.dev)
})





# Functions ---------------------------------------------------------------

source("functions.R")

# Load experiment model grid ----------------------------------------------

model_grid <- readRDS(mg_file)


# Prepare datat -----------------------------------------------------------

states <- readRDS(DATA_FILE)

# DV var names. All but the current outcome of these will have to be dropped
# for the training data.
dv_var_names <- colnames(states)[grepl("^dv_", colnames(states))]
# ID vars
id_var_names <- c("gwcode", "year")
# Features
feature_names <- setdiff(colnames(states), c(dv_var_names, id_var_names))

train_data <- states[states$year <= TRAIN_END, ]
test_data  <- states[states$year >= TEST_START & states$year <= 2020, ]



# Train/evaluate models ---------------------------------------------------

# initalize chunk dir
if (!dir.exists(chunk_dir)) {
  catlog("Initializing chunk directory")
  dir.create(chunk_dir)
} else {
  catlog("Found existing chunk directory")
  n_done <- length(dir(chunk_dir))
  n_total <- nrow(model_grid)
  catlog("%s of %s chunks done (%s%%)", n_done, n_total, round(n_done/n_total*100))
}

# shuffle the model grid for more event worker assignments
model_grid <- model_grid[sample(1:nrow(model_grid)), ]

# register plan
if (N_WORKERS==1L) {
  catlog("Running in sequential model")
  plan(sequential)
} else {
  plan(multisession, workers = N_WORKERS)
  catlog("Running in parallel with %s workers", N_WORKERS)
}


res <- foreach(
  i = 1:nrow(model_grid),
  .inorder = FALSE,
  .options.future = list(seed = TRUE)
) %dofuture% {

  mgi <- model_grid[i, ]

  chunk_file <- file.path(chunk_dir, sprintf("%s.rds", mgi$mg_id))
  if (!file.exists(chunk_file)) {
    outcome <- sprintf("dv_%s_%s_next2", mgi$indicator, mgi$direction)
    validation_idx <- mgi$validation_split[[1]]

    params <- mgi$params[[1]]

    data <- list(
      train = list(
        x = train_data[-validation_idx, feature_names],
        y = train_data[-validation_idx, ][[outcome]]
      ),
      validation = list(
        x = train_data[validation_idx, feature_names],
        y = train_data[validation_idx, ][[outcome]]
      ),
      test = list(
        x = test_data[, feature_names],
        y = test_data[[outcome]]
      )
    )

    if (mgi$model=="ranger_2022") {
      scores <- run_ranger(data, params)
    } else if (grepl("xgboost", mgi$model)) {
      scores <- run_xgboost(data, params)
    } else if (grepl("lightgbm", mgi$model)) {
      scores <- run_lightgbm(data, params)
    } else {
      stop("something wrong")
    }

    mgi$scores[1] <- list(as_tibble(scores))

    saveRDS(mgi, chunk_file)
  }
  invisible(TRUE)
}



# Combine chunks ----------------------------------------------------------


catlog("Chunks done, combining results")

files <- dir(chunk_dir, full.names = TRUE)
res <- lapply(files, readRDS)
res <- do.call(rbind, res)

res <- res[order(res$mg_id), ]

res$validation_split <- NULL

res <- tidyr::unnest_wider(res, params)
res <- tidyr::unnest_wider(res, scores)

readr::write_csv(res, res_file)


# Clean up ----------------------------------------------------------------


catlog("Cleaning up")

unlink(chunk_dir, recursive = TRUE)

script_time <- as.integer((proc.time() - t_script_start)["elapsed"])
catlog("Done, total run time %ss", script_time)
