#
#   Run random forest model
#
#   Because these models take longer to run, this script is set up to chunk by outcome-year
#   and then later re-combine the outcome-year chunks into one superset of
#   forecasts similar in structure to the other model runners.
#
#   **To start a fresh re-run, delete the year chunks in rf-chunks**
#
#   The 2021 update took 7 hours to run.
#

# Config settings
#
# How many parallel workers to use?
N_WORKERS <- future::availableCores() - 1L
# Redo existing chunks? (FALSE means progress for an interrupted run will be
# used, not re-done)
OVERWRITE = FALSE
# Years from which to walk-forward 2-years-ahead forecasts;
# UPDATE: last year should probably be the end year in the data
YEARS <- 2005:2021

# TODO: i don't think this works correctly with parallel workers; and in any
# case maybe not a good idea
#set.seed(12348)

# End config settings

t0 <- proc.time()

library(dplyr)
library(lgr)
library(readr)
library(future)
library(doFuture)
library(jsonlite)
library(demspacesR)
library(ranger)
library(here)

setwd(here::here("modelrunner"))

# chunks will be saved to this directory
chunk_dir <- "output/rf-chunks"
model_dir <- "output/rf-models"

# Setup directories, in case they don't exist
dir.create("output", showWarnings = FALSE)
dir.create("output/log", showWarnings = FALSE)
dir.create(chunk_dir, showWarnings = FALSE)
dir.create(model_dir, showWarnings = FALSE)

# Setup log file
timestamp <- Sys.Date()
log_file  <- sprintf("output/log/rf-%s.txt", timestamp)
lgr$add_appender(AppenderFile$new(log_file))

lgr$info("Running random forest model")
lgr$info("R package 'demspacesR' version %s", packageVersion("demspacesR"))

registerDoFuture()
lgr$info("Running with %s workers", N_WORKERS)
plan(multisession, workers = N_WORKERS)

# Parse states data version so we can name the output forecasts correctly
fn <- tail(dir("input", full.names = TRUE), 1)
VERSION <- regmatches(fn, regexpr("v[0-9]+[a-z]?", fn))
if (VERSION %in% c("", character(0))) stop("Could not parse VERSION")
lgr$info("Using data version %s", VERSION)

# Load data
states <- readRDS(fn)

# Iterate over outcomes
outcomes <- c("v2x_veracc_osp", "v2xcs_ccsi", "v2xcl_rol", "v2x_freexp_altinf",
              "v2x_horacc_osp", "v2x_pubcorr")

model_grid <- expand.grid(outcome = outcomes, year = YEARS, stringsAsFactors = FALSE)
model_grid$chunk <- paste0(model_grid$outcome, "_", model_grid$year)
model_grid$outfile <- file.path(chunk_dir, paste0(model_grid$chunk, ".csv"))
model_grid$modelfile <- file.path(model_dir, paste0(model_grid$chunk, ".rds"))
model_grid$time <- NA_real_

# shuffle so workers get more even work (hopefully)
model_grid <- model_grid[sample(1:nrow(model_grid)), ]
model_grid$id <- 1:nrow(model_grid)
model_grid <- model_grid[, c("id", "outcome", "year", "chunk", "outfile", "modelfile", "time")]

# Save model grid, in case something goes wrong
mg <- model_grid[, c("id", "outcome", "year")]
write_csv(mg, "output/rf-model-grid.csv")

if (!OVERWRITE) {
  done   <- dir(chunk_dir, full.names = TRUE)
  model_grid <- model_grid[!model_grid$outfile %in% done, ]
}

# Record total model N for progress messages
n_models <- nrow(mg)
lgr$info("%s total models", n_models)

model_grid <- foreach(i = 1:nrow(model_grid),
                      .combine = bind_rows,
                      .export = c("model_grid", "n_models")) %dopar% {

  t0 <- proc.time()

  id_i      <- model_grid$id[[i]]
  outcome_i <- model_grid$outcome[[i]]
  year_i    <- model_grid$year[[i]]
  chunk_i   <- model_grid$chunk[[i]]
  outfile_i <- model_grid$outfile[[i]]
  modfile_i <- model_grid$modelfile[[i]]

  tt <- year_i
  lgr$info("Start model %s", id_i)

  states_t <- states %>% filter(year <= tt)

  train_data <- states_t %>%
    ungroup() %>%
    filter(year < max(year))
  test_data  <- states_t %>%
    ungroup() %>%
    filter(year == max(year))

  mdl      <- ds_rf(outcome_i, train_data, num.threads = 1,
                    num.trees = 900, min.node.size = 1)
  fcasts_i <- predict(mdl, new_data = test_data)

  runtime <- round((proc.time() - t0)["elapsed"])
  model_grid$time[i] <- runtime

  write_rds(mdl, modfile_i)
  write_csv(fcasts_i, outfile_i)

  # log finish
  n_done <- length(dir("output/rf-chunks"))
  lgr$info("Finished model %s; time: %ss; progress: %s/%s (%s%%)",
           id_i,
           runtime,
           n_done, n_models, round(n_done/n_models*100, 0))

  model_grid[i, ]
}

# Combine model chunks into one set
chunk_files <- dir(chunk_dir, full.names = TRUE)
chunks      <- lapply(chunk_files, readr::read_csv, col_types = cols())
fcasts_y    <- do.call(rbind, chunks)

# Score forecasts
score <- score_ds_fcast(fcasts_y, states)

# Write both versioned and un-versioned (for git diff) forecast and score
# files
write_csv(fcasts_y, "output/fcasts-rf.csv")
write_csv(score,    "output/fcasts-rf-score-summary.csv")
write_csv(fcasts_y, sprintf("output/fcasts-rf-%s.csv", VERSION))
write_csv(score,    sprintf("output/fcasts-rf-%s-score-summary.csv", VERSION))

# Clean up chunks so that future runs will work correctly
unlink(chunk_dir, recursive = TRUE)
unlink(model_dir, recursive = TRUE)
unlink("output/rf-model-grid.csv")

# Log finish
score <- tidyr::unite(score, Measure, Measure, Direction)
ss <- as.list(score$Value)
names(ss) <- score$Measure
lgr$info("Total script run time: %ss", round((proc.time() - t0)["elapsed"]))
lgr$info("Performance: %s", jsonlite::toJSON(ss, auto_unbox = TRUE, digits = 3))

# Warnings won't be printed unless we do explicitly here
warn <- warnings()
if (length(warn) > 1) {
  call <- as.character(warn)
  msg  <- names(warn)
  warn_strings <- paste0("In ", call, " : ", msg)
  lgr$warn("There were R warnings, printing below:")
  for (x in warn_strings) lgr$warn(x)
}

