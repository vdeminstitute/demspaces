#
#   Tuning-related helper functions
#

# Randomly split a vector of 1:N into K different chunks of similar size
cv_split_indices <- function(N, k) {
  idx <- sample(1:N, size = N)
  group <- rep_len(1:k, N)
  splits <- list()
  for (i in 1:k) {
    splits[[as.character(i)]] <- sort(idx[group==i])
  }
  splits
}


run_lightgbm <- function(data, params = NULL) {
  start_time <- proc.time()

  # lightgbm wants to save a model; come up with a random name that we can
  # unlink in a hot second
  save_file <- tempfile("lightgbm", fileext = ".model")

  base_params <- list(objective = "binary", num_threads = 1L)
  if (is.null(params)) {
    params <- base_params
  } else {
    params <- c(base_params, params)
  }

  dtrain <- lgb.Dataset(data = as.matrix(data$train$x), label = data$train$y,
                        params = list(feature_pre_filter = FALSE))

  model <- lightgbm(data = dtrain,
                    params = params,
                    verbose = -1L,
                    save_name = save_file)

  validation_pred <- predict(model, as.matrix(data$validation$x))
  test_pred <- predict(model, as.matrix(data$test$x))

  unlink(save_file)

  scores <- calculate_scores(validation_pred, data$validation$y,
                             test_pred, data$test$y,
                             start_time)
  scores
}

sample_lightgbm_hp <- function(n) {
  params = list(
    num_iterations = sample(10:200, n, replace = TRUE),  # 100
    learning_rate = runif(n, 0.01, 0.4),     # 0.1
    num_leaves = sample(10:70, n, replace = TRUE),  # 31
    min_data_in_leaf = sample(5:50, n, replace = TRUE),
    bagging_freq = sample(c(rep(0, 1), 1:5), n, replace = TRUE),
    bagging_fraction = runif(n, 0.6, 1),
    feature_fraction = runif(n, 0.8, 1),
    lambda_l1 = sample(c(rep(0, n*0), runif(n, 0, 2)), n, replace = TRUE),
    lambda_l2 = sample(c(rep(0, n*0), runif(n, 0, 2)), n, replace = TRUE)
  )
  params$bagging_fraction[params$bagging_freq==0] <- 1
  # Turn a list of vectors into a length n list with one hp per list element
  params <- purrr::list_transpose(params, simplify = FALSE)
  params
}

run_xgboost <- function(data, params) {
  start_time <- proc.time()

  base_params <- list(objective = "binary:logistic", nthread = 1L)
  if (is.null(params)) {
    params <- base_params
  } else {
    params <- c(base_params, params)
  }

  if ("nrounds" %in% names(params)) {
    nrounds <- params$nrounds
    params["nrounds"] <- NULL
  } else {
    nrounds <- 100L
  }

  dtrain <- xgb.DMatrix(as.matrix(data$train$x), label = data$train$y)

  model <- xgboost(data = dtrain,
                   params = params,
                   nrounds = nrounds,
                   verbose = 0L)

  validation_pred <- predict(model, newdata = as.matrix(data$validation$x))
  test_pred <- predict(model, newdata = as.matrix(data$test$x))

  scores <- calculate_scores(validation_pred, data$validation$y,
                             test_pred, data$test$y,
                             start_time)
  scores
}

sample_xgboost_hp <- function(n) {
  params = list(
    nrounds = sample(10:400, n, replace = TRUE), #10:200
    eta = runif(n, 0, 0.3), # 0.3 0 1
    gamma = sample(c(rep(0, max(1, floor(n/2))), runif(n, 0, 1)), n, replace = TRUE), # 0
    max_depth = sample(3:15, n, replace = TRUE), # 6
    min_child_weight = runif(n, 0.5, 5), # 1
    max_delta_step = sample(c(rep(0, max(1, floor(n/2))), runif(n, 0, 5)), n, replace = TRUE),
    subsample = sample(c(rep(1, max(1, floor(n/2))), runif(n, 0.5, 1)), n, replace = TRUE),
    colsample_bytree = sample(c(rep(1, max(1, floor(n/2))), runif(n, 0.5, 1)), n, replace = TRUE),
    colsample_bylevel = sample(c(rep(1, max(1, floor(n/2))), runif(n, 0.5, 1)), n, replace = TRUE),
    colsample_bynode = sample(c(rep(1, max(1, floor(n/2))), runif(n, 0.5, 1)), n, replace = TRUE),
    lambda = sample(c(rep(1, max(1, floor(n/2))), runif(n, 0, 3)), n, replace = TRUE),
    alpha = sample(c(rep(0, max(1, floor(n/2))), runif(n, 0, 3)), n, replace = TRUE)
  )
  # Turn a list of vectors into a length n list with one hp per list element
  params <- purrr::list_transpose(params, simplify = FALSE)
  params
}

run_ranger <- function(data, params) {
  start_time <- proc.time()

  train_data <- cbind(data$train$x, yy = data$train$y)

  model <- ranger(yy ~ ., data = train_data,
                  num.trees = 2000L, mtry = 20L, min.node.size = 1L,
                  probability = TRUE,
                  num.threads = 1L)

  validation_pred <- predict(model, data = data$validation$x)$predictions[, 2]
  test_pred <- predict(model, data = data$test$x)$predictions[, 2]

  scores <- calculate_scores(validation_pred, data$validation$y,
                             test_pred, data$test$y,
                             start_time)
  scores
}


calculate_scores <- function(cv_pred, cv_truth, test_pred, test_truth, start_time) {
  cv_truth = factor(cv_truth, levels = c("1", "0"))
  test_truth = factor(test_truth, levels = c("1", "0"))
  stats <- list(
    # cv metrics
    "cv_pos_rate" = mean(cv_truth=="1"),
    "cv_brier"    = demspaces.dev:::safe_brier(cv_truth, cv_pred),
    "cv_log_loss" = demspaces.dev:::safe_mn_log_loss(cv_truth, cv_pred),
    "cv_auc_roc"  = demspaces.dev:::safe_roc_auc(cv_truth, cv_pred),
    "cv_auc_pr"   = demspaces.dev:::safe_roc_pr(cv_truth, cv_pred),
    # test metrics
    "test_pos_rate" = mean(test_truth=="1"),
    "test_brier"    = demspaces.dev:::safe_brier(test_truth, test_pred),
    "test_log_loss" = demspaces.dev:::safe_mn_log_loss(test_truth, test_pred),
    "test_auc_roc"  = demspaces.dev:::safe_roc_auc(test_truth, test_pred),
    "test_auc_pr"   = demspaces.dev:::safe_roc_pr(test_truth, test_pred),
    # common metrics
    "time" = as.numeric((proc.time() - start_time)["elapsed"])
  )
  stats
}


catlog <- function(msg, ...) {
  timestamp <- format(Sys.time(), "%T")
  msg <- sprintf(msg, ...)
  msg <- paste0("[", timestamp, "] ", msg, "\n")
  cat(msg)
  invisible(msg)
}

