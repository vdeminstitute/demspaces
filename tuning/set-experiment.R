#
#   Tuning experiments for LightGBM
#
#   This script runs cross-validation using the pre-2006 merge data in order to
#   investigate LightGBM hyperparameters.
#


# ID for this experiment
RUN_ID <- "run-11"
# Which models to run? Horserace with tuned models or sample new HPs?
MODEL <- "horserace"
# lightgbm, horserace
# How many HP sample sets to draw?
N_HP <- 50

# What is the data file name?
DATA_FILE <- here::here("create-data/output/states-v13.rds")
# What year to use as cutoff for the training data (inclusive)?
TRAIN_END <- 2003L  # last forecast window is 2004-2005
# What year to use as test data start (inclusive)?
TEST_START <- 2005L  # so the first forecast window is 2006-2007, i.e. not touching the last train fcast window


setwd(here::here("tuning"))

mg_file <- sprintf("%s_mg.rds", RUN_ID)
mg_file <- file.path("model-grid", mg_file)
if (file.exists(mg_file)) {
  stop("Model grid file already exists, not overwriting")
}

suppressPackageStartupMessages({
  library(lightgbm)
  library(tibble)
  library(xgboost)
})


# Functions ---------------------------------------------------------------

source("functions.R")


# Prepare model list ------------------------------------------------------

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

#
#   Dim 1: Outcomes
#

# Construct the grid of outcomes
data(spaces)

outcomes <- as_tibble(expand.grid(
  indicator = spaces$Indicator,
  direction = c("up", "down")
))

#
#   Dim 2: Model & HP
#

if (MODEL=="horserace") {
  model <- tibble(model = c("lightgbm_default", "xgboost_default", "ranger_2022",
                            "lightgbm_2023", "xgboost_2023"),
                  hp_set_id = c("run-11_lightgbm_default", "run-11_xgboost_default",
                                "run-11_ranger_2022", "run-11_lightgbm_2023",
                                "run-11_xgboost_2023"))
  model$params <- list(NULL, NULL, NULL,
                       list(lambda_l1 = 0.1, lambda_l2 = 0.1),
                       list(eta = 0.1, nrounds = 200L))
} else {
  model <- tibble(model = MODEL)
  if (model=="lightgbm") {
    hp_samples <- sample_lightgbm_hp(n = N_HP)
  } else if (model=="xgboost") {
    hp_samples <- sample_xgboost_hp(n = N_HP)
  }

  hp_samples <- tibble(hp_set_id = sprintf("%s_%s_hp-%02d", RUN_ID, MODEL, 1:N_HP),
                       params = (hp_samples))
}




#
#   Dim 3: CV splits
#

cv_splits <- cv_split_indices(nrow(train_data), k = 5)
cv_splits <- tibble(validation_split = cv_splits)


#
#   Construct model grid
#

model_grid <- dplyr::full_join(outcomes, model, by = character())
model_grid <- dplyr::full_join(model_grid, cv_splits, by = character())
if (MODEL!="horserace") {
  model_grid <- dplyr::full_join(model_grid, hp_samples, by = character())
}

model_grid$mg_id <- 1:nrow(model_grid)
model_grid <- model_grid[, c("mg_id", setdiff(colnames(model_grid), "mg_id"))]

model_grid$scores <- NA

saveRDS(model_grid, mg_file)


