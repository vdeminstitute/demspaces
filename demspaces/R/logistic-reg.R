
#' Logistic regression
#'
#' Demonstrates the interface. Otherwise only difference is that it internally
#' normalizes input data before fitting and predicting.
#'
#' @param space (`character(1)`) \cr
#'   Name of the V-Dem indicator for a democratic space
#' @param data ([base::data.frame()])
#'   A data frame or similar object
#' @param normalize Standardize data using [make_standardizer()]?
#'
#' @examples
#' data("states")
#'
#' mdl <- ds_logistic_reg("v2x_veracc_osp", states)
#' preds <- predict(mdl, new_data = states)
#'
#' @export
#' @concept ds_model
#' @family Other DS models
ds_logistic_reg <- function(space, data, normalize = FALSE) {

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

  standardize <- identity
  if (isTRUE(normalize)) {
    standardize <- make_standardizer(train_x)
  }
  train_x     <- standardize(train_x)

  # Check for missing values and subset;
  # do this after make standardizer so that predict gives the same values as
  # when identity standardizer is used (otherwise set difference gives small
  # difference in mean and sd used for normalization, which leds to diffs
  # in predicted probs)
  if (any(is.na(full_data[, ynamedown]), is.na(full_data[, ynameup]))) {
    warning(sprintf("Discarding %s incomplete outcome set cases",
                    sum(!keep_idx)))

    keep_idx <- stats::complete.cases(train_data)
    train_data <- train_data[keep_idx, ]
    train_x    <- train_x[keep_idx, ]

  }

  up_mdl   <- logistic_reg(x = train_x, y = train_data[, ynameup])

  down_mdl <- logistic_reg(x = train_x, y = train_data[, ynamedown])

  new_ds_logistic_reg(up_mdl, down_mdl, standardize, space)
}

#' Constructor
#' @keywords internal
new_ds_logistic_reg <- function(up_mdl, down_mdl, standardize, yname) {
  structure(
    list(
      up_mdl   = up_mdl,
      down_mdl = down_mdl,
      standardize = standardize
    ),
    yname = yname,
    class = "ds_logistic_reg"
  )
}

#' @export
#' @importFrom stats predict
predict.ds_logistic_reg <- function(object, new_data, ...) {

  if (any(!c("gwcode", "year") %in% names(new_data))) {
    stop("'new_data' must contain 'gwcode' and 'year' columns")
  }

  up_mdl   <- object$up_mdl
  down_mdl <- object$down_mdl
  yname    <- attr(object, "yname")

  # Standardize data
  x_data <- object$standardize(new_data)

  p_up     <- predict(up_mdl,   new_data = new_data)[["p_1"]]
  p_down   <- predict(down_mdl, new_data = new_data)[["p_1"]]
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

#' Logistic regression
#'
#' Standardized interface for logistic regression
#'
#' @param x Data frame with features.
#' @param y Binary vector indicating outcome event.
#'
#' @examples
#' credit_data <- modeldata::credit_data
#'
#' mdl <- logistic_reg(credit_data[, setdiff(colnames(credit_data), "Status")],
#'                     credit_data$Status)
#'
#' @export
#' @concept base_model
#' @family Other base models
logistic_reg <- function(x, y) {

  if (inherits(y, "data.frame")) {
    y = y[[1]]
  }
  y   <- as.factor(y)

  train_data  <- dplyr::bind_cols(`.y` = y, x)
  fit <- stats::glm(.y ~ ., data = train_data, family = stats::binomial(link = "logit"))

  new_logistic_reg(fit, levels(y))
}

#' Constructor
#' @keywords internal
new_logistic_reg <- function(model, y_classes) {
  structure(
    list(model = model),
    y_classes = y_classes,
    class = "logistic_reg"
  )
}

#' @export
predict.logistic_reg <- function(object, new_data, ...) {

  # ?glm states that for factor responses, the first level denotes failure
  # and all other levels denote success; so, predict(type = "response") will
  # gives us P for the second class
  y_classes <- attr(object, "y_classes")
  p <- predict(object$model, newdata = new_data, type = "response")
  preds <- tibble::tibble(
    p0 = 1 - p,
    p1 = p
  )
  colnames(preds) <- paste0("p_", y_classes)
  preds
}



