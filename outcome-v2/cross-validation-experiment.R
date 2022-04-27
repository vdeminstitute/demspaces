#
#   Cross-validation exercise to compare predictive performance of the
#   models for original outcomes to the ERT-lite outcomes
#

# Config settings
#
config <- list(
  cv_folds = 10,
  cv_repeats = 1
)
# How many parallel workers to use?
N_WORKERS <- 6
# Redo existing chunks? (FALSE means progress for an interrupted run will be
# used, not re-done)
OVERWRITE = TRUE
# Remove artifacts after run or leave in place? (This interacts with
# OVERWRITE)
CLEANUP = FALSE

# End config settings

t0 <- proc.time()

suppressPackageStartupMessages({
  library(demspacesR)
  library(ranger)
  library(lgr)
  library(dplyr)
  library(future)
  library(doFuture)
  library(doRNG)
})


setwd(here::here("outcome-v2"))

# chunks will be saved to this directory
chunk_dir <- "output/chunks"

# Setup directories, in case they don't exist
dir.create("output", showWarnings = FALSE)
dir.create("output/log", showWarnings = FALSE)
dir.create(chunk_dir, showWarnings = FALSE)

# Setup log file
if (!OVERWRITE) {
  # reuse latest log file
  log_file <- tail(dir("output/log", full.names = TRUE), 1)
} else {
  timestamp <- as.character(Sys.time())
  timestamp <- gsub(" ", "_", timestamp)
  timestamp <- gsub(":", "", timestamp)
  log_file  <- sprintf("output/log/cv-experiment_%s.txt", timestamp)
}
lgr$add_appender(AppenderFile$new(log_file))

lgr$info("Running CV experiments for ERT-lite outcome")
lgr$info("Settings: %s-fold CV with %s repetitions", config$cv_folds, config$cv_repeats)
lgr$info("R package 'demspacesR' version %s", packageVersion("demspacesR"))

registerDoRNG()
registerDoFuture()
lgr$info("Running with %s workers", N_WORKERS)
plan("multisession", workers = 6)


# Load cutpoints for predict.ds_rf (#15)
cp <- read.csv(here::here("modelrunner/input/cutpoints.csv"))
cutpoints <- cp$up
names(cutpoints) <- cp$indicator

states <- readRDS(here::here("archive/data/states-v12.rds"))
states_mod <- readRDS(here::here("outcome-v2/data/states-v12-mod.rds"))

states <- states %>%
  ungroup() %>%
  arrange(gwcode, year) %>%
  filter(year < 2020)

states_mod <- states_mod %>%
  ungroup() %>%
  arrange(gwcode, year) %>%
  filter(year < 2020)


# Setup fold indices ------------------------------------------------------
#
#   Pre-compute the data split indices for repeated cross-validation so that
#   we can run each bit in parallel.
#
#   Since the original states data ("states") and "states_mod" are equivalent
#   except for the outcome indicators ("_next2"), we only have to do this once.
#
#   Do blocked sampling by year
#

n <- length(unique(states$year))
m <- config$cv_folds
items_per_fold <- c(rep(floor(n/m) + 1L, n%%m), rep(floor(n/m), m - n%%m))
fold <- rep(1:m, items_per_fold)

year <- unique(states$year)

splits <- list()
for (i in 1:config$cv_repeats) {
  year <- sort(sample(year, length(year)))
  splits[[i]] <- tibble(fold_id = 1:m, year = split(year, factor(fold)))
}
splits <- dplyr::bind_rows(splits, .id = "rep_id")


# Construct model list ----------------------------------------------------
#
#   A list containing the parameters needed to run each instance of the models
#   we want to run--basically what we can send to each parallel worker to get
#   on with it.
#

# joining on character() makes this a cross join
model_grid <- dplyr::full_join(tibble(data = c("orig", "mod")), splits,
                               by = character())

# Iterate over outcomes
outcomes <- c("v2x_veracc_osp", "v2xcs_ccsi", "v2xcl_rol", "v2x_freexp_altinf",
              "v2x_horacc_osp", "v2x_pubcorr")
model_grid <- dplyr::full_join(model_grid, tibble(outcome = outcomes),
                               by = character())

# Assign ID for each row in model grid, BEFORE reshuffling it below;
# this should be stable between runs and interrupts
model_grid$id <- 1:nrow(model_grid)

# Names for the chunkfiles (a row in model_grid is what we will save)
model_grid$chunkfile <- sprintf("output/chunks/chunk-%04d.rds", model_grid$id)

# Here are the outcomes I want to get out of this at the end:
model_grid$time <- rep(NA_real_, nrow(model_grid))
model_grid$score <- list(NULL)

# shuffle so workers get more even work (hopefully)
model_grid <- model_grid[sample(1:nrow(model_grid)), ]

# Record total model N for progress messages
n_models <- nrow(model_grid)
lgr$info("%s total models", n_models)

if (!OVERWRITE) {
  done   <- dir(chunk_dir, full.names = TRUE)
  model_grid <- model_grid[!model_grid$chunkfile %in% done, ]

  lgr$info("Found and re-using %s models; %s left to run", length(done), nrow(model_grid))
}



# Run experiment - train models -------------------------------------------

model_grid <- foreach(
  i = seq_len(nrow(model_grid)),
  .combine = bind_rows,
  .export = c("model_grid", "cutpoints", "states", "states_mod", "n_models")) %dorng% {

    t0 <- proc.time()

    id_i      <- model_grid$id[[i]]
    outcome_i <- model_grid$outcome[[i]]
    chunk_i   <- model_grid$chunkfile[[i]]
    dv_version <- model_grid$data[[i]]
    test_years <- model_grid$year[[i]]

    lgr$info("Start model %s", id_i)

    if (dv_version=="orig") {
      df <- states
    } else {
      df <- states_mod
    }

    train_data <- df %>%
      ungroup() %>%
      filter(!year %in% test_years)
    test_data  <- df %>%
      ungroup() %>%
      filter(year %in% test_years)

    mdl      <- ds_rf(outcome_i, train_data, num.threads = 1L,
                      num.trees = 2000L, mtry = 20L, min.node.size = 1L,
                      verbose = FALSE)
    fcasts_i <- predict(mdl, new_data = test_data, cutpoint = cutpoints[[outcome_i]])

    score <- score_ds_fcast(fcasts_i, test_data)
    model_grid$score[i] <- list(score)

    runtime <- round((proc.time() - t0)["elapsed"])
    model_grid$time[i] <- runtime

    saveRDS(model_grid[i, ], chunk_i)

    # log finish
    n_done <- length(dir("output/chunks"))
    lgr$info("Finished model %s; time: %ss; progress: %s/%s (%s%%)",
             id_i,
             runtime,
             n_done, n_models, round(n_done/n_models*100, 0))

    model_grid[i, ]
  }

# Combine model chunks into one set
chunk_files <- dir(chunk_dir, full.names = TRUE)
chunks      <- lapply(chunk_files, readRDS)
model_grid  <- do.call(rbind, chunks)

# Save model grid with all results
saveRDS(model_grid, sprintf("output/cv-results_%s.rds", timestamp))

# Clean up chunks so that future runs will work correctly
if (CLEANUP) {
  unlink(chunk_dir, recursive = TRUE)
}

# Log finish
lgr$info("Total script run time: %ss", round((proc.time() - t0)["elapsed"]))

# Warnings won't be printed unless we do explicitly here
warn <- warnings()
if (length(warn) > 1) {
  call <- as.character(warn)
  msg  <- names(warn)
  warn_strings <- paste0("In ", call, " : ", msg)
  lgr$info("There were R warnings, printing below:")
  for (x in warn_strings) lgr$info(x)
}









