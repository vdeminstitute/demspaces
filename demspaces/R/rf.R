
#' Random forest
#'
#' Demonstrates the interface. Otherwise only difference is that it internally
#' normalizes input data before fitting and predicting.
#'
#' @template ds_model
#' @param mtry see [ranger::ranger()]; if NULL, this will be tuned via
#'   out-of-bag error (see "ds_rf_tuner" in the source code in "rf.R").
#' @param ... other arguments passed to [ranger::ranger()]
#'
#' @examples
#' data("states")
#'
#' mdl <- ds_rf("v2x_veracc_osp", states)
#' preds <- predict(mdl, new_data = states)
#'
#' @export
ds_rf <- function(space, data, mtry = NULL, ...) {

  full_data <- data
  yname <- space

  # drop DV vars that we should exclude, except for our actual outcome pair
  ynameup   <- paste0("dv_", yname, "_up_next2")
  ynamedown <- paste0("dv_", yname, "_down_next2")

  full_data <- full_data %>%
    dplyr::select(-dplyr::starts_with("dv"), dplyr::one_of(c(ynameup, ynamedown)))

  train_data <- full_data[setdiff(names(full_data), c("gwcode", "year"))]

  # Standardize feature data
  train_x     <- train_data[, setdiff(names(train_data), c(ynameup, ynamedown))]

  # discard incomplete feature cases
  keep_idx <- stats::complete.cases(train_x)
  if (!all(keep_idx)) {
    warning(sprintf("Discarding %s incomplete feature set cases",
                    sum(!keep_idx)))
    train_x    <- train_x[keep_idx, ]
    train_data <- train_data[keep_idx, ]
  }

  # Check for missing values and subset;
  mssng_dv <- c(is.na(full_data[, ynamedown]), is.na(full_data[, ynameup]))
  if (any(mssng_dv)) {
    warning(sprintf("Discarding %s incomplete outcome set cases",
                    sum(mssng_dv)))

    keep_idx <- stats::complete.cases(train_data)
    train_data <- train_data[keep_idx, ]
    train_x    <- train_x[keep_idx, ]

  }

  up_mdl   <- ds_rf_tuner(x = train_x, y = train_data[, ynameup], mtry, ...)
  down_mdl <- ds_rf_tuner(x = train_x, y = train_data[, ynamedown], mtry, ...)

  new_ds_rf(up_mdl, down_mdl, space)
}

#' Wrapper to only tune mtry
#' Based on tunerf results
#' @keywords internal
ds_rf_tuner <- function(x, y, mtry, ...) {

  if (is.null(mtry)) {
    mtry_grid <- c(5, 7, 10, 15, 20, 25, 30, 40, 50, 60, 70, 85, 100)

    # cannot have mtry values greater than # of features
    mtry_grid <- mtry_grid[mtry_grid < ncol(x)]
    cost <- rep(NA_real_, length(mtry_grid))
    for (i in seq_len(length(mtry_grid))) {
      mdl <- rf(x, y, mtry = mtry_grid[i], ...)
      cost[i] <- mdl$model$prediction.error
    }
    mtry_final <- mtry_grid[which.min(cost)]
  } else {
    mtry_final <- mtry
  }

  rf(x, y, mtry = mtry_final, ...)
}

#' Constructor
#' @keywords internal
new_ds_rf <- function(up_mdl, down_mdl, yname) {
  structure(
    list(
      up_mdl   = up_mdl,
      down_mdl = down_mdl
    ),
    yname = yname,
    class = "ds_rf"
  )
}

#' Predict Method for DS random forest model
#'
#' Create opening and closing predictions for a fitted [ds_rf()] model.
#'
#' @param object a fitted [ds_rf()] model
#' @param new_data predictor data
#' @param cutpoint optional cutpoint used to adjust forecasts, see details
#' @param ... not used
#'
#' @details The "cutpoints" argument can optionally be used to adjust the raw
#'
#' @export
#' @importFrom stats predict
predict.ds_rf <- function(object, new_data, cutpoint = NULL, ...) {

  if (any(!c("gwcode", "year") %in% names(new_data))) {
    stop("'new_data' must contain 'gwcode' and 'year' columns")
  }

  up_mdl   <- object$up_mdl
  down_mdl <- object$down_mdl
  yname    <- attr(object, "yname")

  p_up     <- predict(up_mdl,   new_data = new_data)[["p_1"]]
  p_down   <- predict(down_mdl, new_data = new_data)[["p_1"]]

  # adjust raw forecasts to eliminate unlikely events (#15)
  if (!is.null(cutpoint)) {
    up_idx <- new_data[[yname]] > (1 - cutpoint)
    down_idx <- new_data[[yname]] < cutpoint

    p_up[up_idx] <- 0
    p_down[down_idx] <- 0
  }

  p_same   <- (1 - p_up) * (1 - p_down)

  fcast <- data.frame(
    outcome   = yname,
    from_year = new_data$year,
    for_years = paste0(new_data$year + 1, " - ", new_data$year + 2),
    gwcode = new_data$gwcode,
    p_up   = p_up,
    p_same = p_same,
    p_down = p_down,
    stringsAsFactors = FALSE
  )
  attr(fcast, "yname") <- yname
  fcast

}

#' Random forest
#'
#' Standardized interface for ...
#'
#' @param x Data frame with features.
#' @param y Binary vector indicating outcome event.
#' @param ... other arguments passed to [ranger::ranger()]
#'
#' @examples
#' credit_data <- modeldata::credit_data
#' credit_data <- credit_data[complete.cases(credit_data), ]
#'
#' mdl <- rf(credit_data[, setdiff(colnames(credit_data), "Status")],
#'           credit_data$Status)
#'
#' @export
rf <- function(x, y, ...) {

  if (!requireNamespace("ranger", quietly = TRUE)) {
    stop("Package \"ranger\" needed for this function to work. Please install it.",
         call. = FALSE)
  }

  if (inherits(y, "data.frame")) {
    y = y[[1]]
  }
  if (!inherits(y, "factor")) {
    y <- factor(y)
  }

  # throw error is any missing
  cx <- complete.cases(x)
  cy <- complete.cases(y)
  if (!all(cy, cx)) {
    stop("Missing values detected; x and y inputs cannot have missing values")
  }

  xy <- cbind(.yy = y, x)
  xy <- as.data.frame(xy)

  mdl_i <- ranger::ranger(.yy ~ ., data = xy, probability = TRUE,
                          ...)

  fit <- mdl_i
  new_rf(fit, levels(y))
}

#' Constructor
#' @keywords internal
new_rf <- function(model, y_classes) {
  structure(
    list(model = model),
    y_classes = y_classes,
    class = "rf"
  )
}

#' @export
predict.rf <- function(object, new_data, ...) {

  # missing value handling:
  # this will subset out missing values, but in predictions let's return those
  # by keeping track of index of X in new_data using row names
  new_data <- new_data[, object$model$forest$independent.variable.names]
  x_data   <- new_data[complete.cases(new_data), ]
  idx      <- match(rownames(x_data), rownames(new_data))

  y_classes <- attr(object, "y_classes")
  p <- predict(object$model, data = x_data, type = "response")
  p <- as.data.frame(p$predictions)

  stopifnot(all(y_classes==colnames(p)))

  preds <- tibble::tibble(
    p0 = rep(NA_real_, nrow(new_data)),
    p1 = rep(NA_real_, nrow(new_data))
  )
  preds$p0[idx] <- p[[y_classes[1]]]
  preds$p1[idx] <- p[[y_classes[2]]]

  colnames(preds) <- paste0("p_", y_classes)

  preds

}



