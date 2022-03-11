#
#   RF permutation-based variable importance
#

IMPORTANCE <- "permutation"
N_WORKERS <- future::availableCores() - 2L

t0 <- proc.time()

library("dplyr")
library("lgr")
library("readr")
library("future")
library("doFuture")
library(doRNG)
library("jsonlite")
library("demspacesR")
library("ranger")
library("here")
library("tidyr")

oldwd <- getwd()
if (basename(getwd())!="modelrunner") {
  setwd(here::here("modelrunner"))
}

# Read data; do this early so we can log data year coverage
states <- readRDS("input/states-v12.rds")

# Setup directories, in case they don't exist
dir.create("output", showWarnings = FALSE)
unlink("output/varimp")
dir.create("output/varimp", showWarnings = FALSE)

# Setup log file
timestamp <- Sys.Date()
log_file  <- sprintf("output/varimp/log-varimp-%s.txt", timestamp)
lgr$add_appender(AppenderFile$new(log_file))

lgr$info("Variable importance")
lgr$info("Output will be written to output/varimp")
lgr$info("demspacesR version %s", packageVersion("demspacesR"))
lgr$info("'states' data cover %s - %s", min(states$year), max(states$year))

registerDoFuture()
lgr$info("Running with %s workers", N_WORKERS)
plan(multisession, workers = N_WORKERS)


# Construct model grid ----------------------------------------------------
#
#   Make one big giant grid of all the models we will run
#   This combines outcomes, up/down, tune grid, and then finally sampling
#   each tune grid value several times to get error estimates
#

# Tune grid
hp_grid <- tibble(
  num.trees = 1000,
  mtry      = 15,
  min.node.size = 1,
)

# Cross outcomes
outcome  <- c("v2x_veracc_osp", "v2xcs_ccsi", "v2xcl_rol", "v2x_freexp_altinf",
              "v2x_horacc_osp", "v2x_pubcorr")
direction <- c("up", "down")

model_grid <- crossing(hp_grid, outcome, direction)

# Randomly shuffle the model grid to even out expected runtime per worker
model_grid <- model_grid[sample(1:nrow(model_grid)), ]

# Initiate column to keep track of runtime
model_grid$time <- NA_real_
model_grid$var_imp <- list(NULL)

# Dump model grid to make it easier to monitor expected run length
write_rds(model_grid, "output/varimp/model-grid.rds")

#
#   Static data tasks that don't change over model grid
#

year_i <- 2011

train_data <- states %>%
  filter(year < year_i) %>%
  ungroup()
test_data  <- states %>%
  filter(year >= year_i) %>%
  ungroup()

# Covariate matrix
train_x <- train_data %>%
  select(-starts_with("dv_"))

model_grid <- foreach(
  i = seq_len(nrow(model_grid)),
  .combine = bind_rows,
  .export = c("train_data", "train_x", "model_grid")) %dorng% {
    t1 <- proc.time()

    pars <- model_grid[i, ]

    lgr$info("Start grid row %s", i)

    yvarname <- sprintf("dv_%s_%s_next2", pars$outcome, pars$direction)
    train_y  <- train_data[, yvarname, drop = TRUE]

    xy <- cbind(.yy = train_y, train_x)
    xy <- as.data.frame(xy)

    mdl <- ranger::ranger(.yy ~ ., data = xy,
                          probability = TRUE,
                          num.threads   = 1,
                          num.trees     = pars$num.trees,
                          mtry          = pars$mtry,
                          min.node.size = pars$min.node.size,
                          importance = IMPORTANCE,
                          verbose = FALSE)

    model_grid[i, ]$var_imp <- list(mdl$variable.importance)
    time_i <- (proc.time() - t1)["elapsed"]
    model_grid[i, ]$time <- time_i

    # log finish
    lgr$info("Finished grid row %s (time: %ss)", i, round(time_i))
    model_grid[i, ]
  }


write_rds(model_grid, "output/varimp/varimp.rds")

lgr$info("Finished getting variable importance")
lgr$info("Total script run time: %ss", round((proc.time() - t0)["elapsed"]))

# Kill workers
plan(sequential)

# Print warnings, if any
warn <- warnings()
if (length(warn) > 1) {
  call <- as.character(warn)
  msg  <- names(warn)
  warn_strings <- paste0("In ", call, " : ", msg)
  lgr$warn("There were R warnings, printing below:")
  for (x in warn_strings) lgr$warn(x)
}

setwd(oldwd)


