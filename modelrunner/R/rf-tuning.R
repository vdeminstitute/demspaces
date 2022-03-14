#
#   Run RF tuning experiments
#
#

t0 <- proc.time()

#
TUNE_N <- 5
# How many parallel workers to use?
N_WORKERS <- 7 # parallely::availableCores() - 1L
# How many times to re-run each set of hyperparameters?
REP_N  <- 5
# What is the data file name?
DATA_FILE <- "states-v12.rds"

if (Sys.info()['nodename']=="mbp-2019.local") {
  OUTDIR <- "~/Dropbox/Work/vdem/demspaces/tuning"
} else if (Sys.info()['nodename']=="MSI") {
  OUTDIR <- "D:/Dropbox/Work/vdem/demspaces/tuning"
} else {
  stop("need outdir")
}

# Setup directories, in case they don't exist
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
dir.create("output/tuning", showWarnings = FALSE, recursive = TRUE)

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lgr)
  library(readr)
  library(future)
  library(doFuture)
  library(doRNG)
  library(jsonlite)
  library(demspacesR)
  library(ranger)
  library(here)
})

# Make sure we are in modelrunner
oldwd <- getwd()
if (basename(getwd())!="modelrunner") {
  setwd(here::here("modelrunner"))
}

# Setup log file
timestamp <- as.character(Sys.time())
timestamp <- gsub(" ", "_", timestamp)
log_file  <- sprintf("%s/rf-tune_%s.txt", OUTDIR, timestamp)
lgr$add_appender(AppenderFile$new(log_file))

outfile <- sprintf("rf-tune-results_%s.rds", timestamp)

lgr$info("RF tune experiment")

registerDoFuture()
lgr$info("Running with %s workers", N_WORKERS)
plan(multisession(workers = 7))

lgr$info("Running %s experiment(s) with %s rep(s) each: %s total model_grid rows", TUNE_N, REP_N, 12*TUNE_N)


# Construct model grid ----------------------------------------------------
#
#   Make one big giant grid of all the models we will run
#   This combines outcomes, up/down, tune grid, and then finally sampling
#   each tune grid value several times to get error estimates
#

# Tune grid
num.trees.vals <- function(n) as.integer(runif(n, min = 5, max = 100.99))*100
mtry.vals      <- function(n) {
  n1 <- floor(n*.3)
  n2 <- floor(n*.5)
  n3 <- n - n1 - n2
  as.integer(c(runif(n1, min = 1, max = 9.99),
               runif(n2, min = 10, max = 25.99),
               runif(n3, min = sqrt(25), max = sqrt(80.99))^2))
}
min.node.size.vals  <- function(n) as.integer(runif(n, min = 1, max = 20.99))

# fill in the actual values later so we get more randomization
tune_grid <- tibble(
  row = 1:TUNE_N,
  num.trees = num.trees.vals(TUNE_N),
  mtry      = mtry.vals(TUNE_N),
  min.node.size = min.node.size.vals(TUNE_N),
  cost = list(NULL),
  time = NA_real_
)

# for script debugging
tune_grid <- tibble(row = 1:5, num.trees = 1000, mtry = 26:30, min.node.size = 1, cost = list(NULL), time= NA_real_)

for (i in 1:nrow(tune_grid)) {
  lgr$info("Par set %s: num.trees=%s, mtry=%s, min.node.size=%s", i,
           tune_grid$num.trees[[i]], tune_grid$mtry[[i]], tune_grid$min.node.size[[i]])
}

# Cross outcomes
outcome  <- c("v2x_veracc_osp", "v2xcs_ccsi", "v2xcl_rol", "v2x_freexp_altinf",
               "v2x_horacc_osp", "v2x_pubcorr")
direction <- c("up", "down")

model_grid <- tidyr::crossing(outcome, direction)
model_grid <- dplyr::full_join(model_grid, tune_grid, by = character())

# Shuffle model grid so worker load is more even
if (FALSE) {
  # Better allocation method
  mdl <- read_rds("output/time-model.rds")
  model_grid$reps <- REP_N
  model_grid$ecost <- predict(mdl, newdata = model_grid, type = "response")

  # current cost
  model_grid$worker <- rep(1:N_WORKERS, each = nrow(model_grid)/N_WORKERS)[1:nrow(model_grid)]
  rando <- max(sapply(split(model_grid$ecost, model_grid$worker), sum))

  # alt
  model_grid <- model_grid[order(model_grid$ecost), ]
  model_grid$worker <- rep(c(1:N_WORKERS, N_WORKERS:1), length.out = nrow(model_grid))
  alt <- max(sapply(split(model_grid$ecost, model_grid$worker), sum))

  if (alt < rando) {
    model_grid <- model_grid[order(model_grid$worker), ]
    lgr$info("Expected runtime %sh using alt allocation (vs %sh for rando)",
             round(alt/3600, 1), round(rando/3600, 1))
  } else {
    lgr$info("Expected runtime %sh using rando allocation (vs %shj for alt)",
             round(rando/3600, 1), round(alto/3600, 1))
  }
}

# shuffle model grid
model_grid <- model_grid[sample(1:nrow(model_grid)), ]

# add REP_N and machine to model_grid so we can estimate timing better
# (down the road)
model_grid$rep_n <- REP_N
model_grid$nodename <- Sys.info()['machine']

# dump model grid to make it easier to monitor expected run length
model_grid$ecost <- model_grid$worker <- NULL
write_rds(model_grid, "output/tuning/model-grid.rds")

#
#   Static data tasks that don't change over model grid
#

year_i <- 2011
states <- readRDS(file.path("input", DATA_FILE))

train_data <- states %>%
  filter(year < year_i) %>%
  ungroup()
test_data  <- states %>%
  filter(year >= year_i) %>%
  ungroup()

# Covariate matrix
train_x <- train_data %>%
  select(-starts_with("dv_"))

one_run <- function(data, pars) {
  mdl <- ranger::ranger(.yy ~ ., data = data, probability = TRUE,
                        num.threads   = 1,
                        num.trees     = pars$num.trees,
                        mtry          = pars$mtry,
                        min.node.size = pars$min.node.size)
  # This is Brier score
  mdl$prediction.error
}

model_grid <- foreach(
  i = seq_len(nrow(model_grid)),
  .combine = bind_rows,
  .export = c("train_data", "train_x", "model_grid", "one_run")) %dorng% {
  t1 <- proc.time()

  pars <- model_grid[i, ]

  lgr$info("Start grid row %s", i)

  yvarname <- sprintf("dv_%s_%s_next2", pars$outcome, pars$direction)
  train_y  <- train_data[, yvarname, drop = TRUE]

  xy <- cbind(.yy = train_y, train_x)
  xy <- as.data.frame(xy)

  model_grid[i, ]$cost <- list(replicate(REP_N, one_run(xy, pars)))
  time_i <- (proc.time() - t1)["elapsed"]
  model_grid[i, ]$time <- time_i

  # log finish
  lgr$info("Finished grid row %s (time: %ss)", i, round(time_i))
  model_grid[i, ]
}

write_rds(model_grid, file.path("output/tuning", outfile))

lgr$info("Total script run time: %ss", round((proc.time() - t0)["elapsed"]))

warn <- warnings()
if (length(warn) > 1) {
  call <- as.character(warn)
  msg  <- names(warn)
  warn_strings <- paste0("In ", call, " : ", msg)
  lgr$warn("There were R warnings, printing below:")
  for (x in warn_strings) lgr$warn(x)
}

# Combine all tuning chunks so far into one file
tune_chunks <- dir(OUTDIR, pattern = "rf-tune-results_", full.names = TRUE)
tune <- lapply(tune_chunks, readRDS)
names(tune) <- tune_chunks
tune <- dplyr::bind_rows(tune, .id = "source_file")
saveRDS(tune, file.path(OUTDIR, "all-results.rds"))

setwd(oldwd)
