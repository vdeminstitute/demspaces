
#' XGBoost
#'
#' Demonstrates the interface. Otherwise only difference is that it internally
#' normalizes input data before fitting and predicting.
#'
#' @template ds_model
#' @param ... document other arguments
#'
#' @examples
#' data("states")
#'
#' mdl <- ds_xgb("v2x_veracc_osp", states)
#' preds <- predict(mdl, new_data = states)
#'
#' @export
ds_xgb <- function(space, data, ...) {

  new_ds_xgb(up_mdl, down_mdl, standardize, space)
}

#' Constructor
#' @keywords internal
new_ds_xgb <- function(..., yname) {
  structure(
    list(
      NULL
    ),
    yname = yname,
    class = "ds_xgb"
  )
}

#' @export
#' @importFrom stats predict
predict.ds_xgb <- function(object, new_data, ...) {

  if (any(!c("gwcode", "year") %in% names(new_data))) {
    stop("'new_data' must contain 'gwcode' and 'year' columns")
  }

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

#' XGBoost
#'
#' Standardized interface for ...
#'
#' @param x Data frame with features.
#' @param y Binary vector indicating outcome event.
#'
#' @examples
#' credit_data <- modeldata::credit_data
#'
#' mdl <- xgb(credit_data[, setdiff(colnames(credit_data), "Status")],
#'                     credit_data$Status)
#'
#' @export
xgb <- function(x, y, ...) {

  if (!requireNamespace("xgboost", quietly = TRUE)) {
    stop("Package \"xboost\" needed for this function to work. Please install it.",
         call. = FALSE)
  }

  if (inherits(y, "data.frame")) {
    y = y[[1]]
  }
  if (inherits(y, "factor")) {
    y_levels = levels(y)
    y <- 2L - as.integer(y)  # take 1st level as target
    if (min(y) < 0 | max(y) > 1) {
      stop("something wrong with y")
    }
  }

  # throw error is any missing
  cx <- complete.cases(x)
  cy <- complete.cases(y)
  if (!all(cy, cx)) {
    stop("Missing values detected; x and y inputs cannot have missing values")
  }

  # xgb.DMatrix needs an all numeric matrix as input; ID and convert any
  # character or factor columns
  x <- convert_data_to_numeric(x)

  # process dots / params
  params <- list(...)
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

  dtrain <- xgb.DMatrix(as.matrix(x), label = y, nthread = params$nthread)

  model <- xgboost(data = dtrain,
                   params = params,
                   nrounds = nrounds,
                   verbose = 0L)

  new_xgb(model, y_levels)
}

#' Convert non-numeric to numeric for XGB
#' @keywords internal
convert_data_to_numeric <- function(x) {
  factor_vars <- sapply(x, is.factor)
  if (any(factor_vars)) {
    warning("Converting factor columns in x to integer")
    for (col_idx in which(factor_vars==1)) {
      x[, col_idx] <- as.integer(x[, col_idx])
    }
  }
  char_vars <- sapply(x, is.character)
  if (any(char_vars)) {
    warning("Converting character columns in x to integer")
    for (col_idx in which(char_vars==1)) {
      x[, col_idx] <- as.integer(x[, col_idx])
    }
  }
  x
}

#' Constructor
#' @keywords internal
new_xgb <- function(model, y_classes) {
  structure(
    list(model = model),
    y_classes = y_classes,
    class = "xgb"
  )
}

#' @export
predict.xgb <- function(object, new_data, ...) {

  # missing value handling:
  # this will subset out missing values, but in predictions let's return those
  # by keeping track of index of X in new_data using row names
  new_data <- new_data[, object$model$feature_names]
  x_data   <- new_data[complete.cases(new_data), ]
  idx      <- match(rownames(x_data), rownames(new_data))

  x_data <- convert_data_to_numeric(x_data)

  y_classes <- attr(object, "y_classes")
  p <- predict(object$model, newdata = as.matrix(x_data))

  preds <- tibble::tibble(
    p0 = rep(NA_real_, nrow(new_data)),
    p1 = rep(NA_real_, nrow(new_data))
  )
  preds$p0[idx] <- p
  preds$p1[idx] <- 1 - p

  colnames(preds) <- paste0("p_", y_classes)

  preds

}



