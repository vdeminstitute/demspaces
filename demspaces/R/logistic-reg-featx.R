
#' Logistic regression with feature extraction
#'
#' Logistic regression with a feature extraction step applied to the training
#' data, e.g. PCA.
#'
#' @param space (`character(1)`) \cr
#'   Name of the V-Dem indicator for a democratic space
#' @param data ([base::data.frame()])
#'   A data frame or similar object
#' @param n_comp the number of components to keep
#'
#' @examples
#' data("states")
#'
#' mdl   <- ds_logistic_reg_featx("v2x_veracc_osp", states)
#' preds <- predict(mdl, new_data = states)
#' head(preds)
#'
#' @export
#' @concept ds_model
#' @family Other DS models
ds_logistic_reg_featx <- function(space, data, n_comp = 5) {

  full_data <- data
  yname     <- space

  # drop DV vars that we should exclude, except for our actual outcome pair
  ynameup   <- paste0("dv_", yname, "_up_next2")
  ynamedown <- paste0("dv_", yname, "_down_next2")

  full_data <- full_data %>%
    dplyr::select(-dplyr::starts_with("dv"), dplyr::one_of(c(ynameup, ynamedown)))

  train_data <- full_data[setdiff(names(full_data), c("gwcode", "year"))]

  # Prepare feature data
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
  # do this after make standardizer so that predict gives the same values as
  # when identity standardizer is used
  if (any(is.na(full_data[, ynamedown]), is.na(full_data[, ynameup]))) {
    warning(sprintf("Discarding %s incomplete outcome set cases",
                    sum(!keep_idx)))

    keep_idx <- stats::complete.cases(train_data)
    train_data <- train_data[keep_idx, ]
    train_x    <- train_x[keep_idx, ]

  }

  up_mdl   <- logistic_reg_featx(x = train_x, y = train_data[, ynameup], n_comp)

  down_mdl <- logistic_reg_featx(x = train_x, y = train_data[, ynamedown], n_comp)

  new_ds_logistic_reg_featx(up_mdl, down_mdl, standardize = identity, space,
                            n_comp)
}

#' Constructor
#' @keywords internal
new_ds_logistic_reg_featx <- function(up_mdl, down_mdl, standardize, yname,
                                      n_comp) {

  out <- new_ds_logistic_reg(up_mdl, down_mdl, standardize, yname)
  attr(out, "n_comp") <- n_comp
  class(out) <- c("ds_logistic_reg_featx", class(out))
  out
}


#' @export
#' @importFrom stats predict
predict.ds_logistic_reg_featx <- function(object, new_data, ...) {
  NextMethod()
}

#' Logistic regression with feature extraction
#'
#' Standardized interface for logistic regression with a feature extraction
#' step, e.g. PCA.
#'
#' @param x Data frame with features.
#' @param y Binary vector indicating outcome event.
#' @param n_comp Number of components to keep.
#'
#' @examples
#' library(modeldata)
#' data(credit_data)
#' credit_data <- credit_data[complete.cases(credit_data), ]
#'
#' mdl <- logistic_reg_featx(
#'   credit_data[, setdiff(colnames(credit_data), "Status")],
#'   credit_data$Status)
#'
#' @export
#' @concept base_model
#' @family Other base models
logistic_reg_featx <- function(x, y, n_comp = 5) {

  stopifnot(all(stats::complete.cases(x)),
            all(!is.na(y)))

  extract_features <- make_extract_features(x, n_comp)

  x_new <- extract_features(x)

  mdl <- logistic_reg(x_new, y)
  mdl$extract_features <- extract_features
  class(mdl) <- c("logistic_reg_featx", class(mdl))
  mdl
}

#' Make feature extractor
#'
#' Creates a feature extractor function
#'
#' @param x a [base::data.frame()] or similar object with only feature variables
#' @param n_comp the number of components to keep
#'
#' @examples
#' library("dplyr")
#' library("stats")
#' data("states")
#'
#' # assume that the input consists entirely of features, and no NAs
#' train_x <- states %>%
#'   filter(year < 2010) %>%
#'   select(-starts_with("dv_"), -gwcode, -year) %>%
#'   filter(complete.cases(.))
#'
#' test_x <- states %>%
#'   filter(year > 2009) %>%
#'   select(-starts_with("dv_"), -gwcode, -year) %>%
#'   filter(complete.cases(.))
#'
#' featx <- make_extract_features(train_x)
#' featx(train_x)
#'
#' @export
make_extract_features <- function(x, n_comp = 5) {

  featx <- recipes::recipe( ~ ., data = x) %>%
    recipes::step_normalize(recipes::all_numeric()) %>%
    recipes::step_pca(recipes::all_numeric(), num_comp = n_comp)
  # we want to fit the PCA parameters using the x data, and re-use it later
  # for prediction
  # Warning: All elements of `...` must be named.
  # this is from https://github.com/tidymodels/recipes/pull/364
  suppressWarnings(
    featx_fitted <- recipes::prep(featx, training = x)
  )

  function(x) {
    # Warning: All elements of `...` must be named.
    # this is from https://github.com/tidymodels/recipes/pull/364
    suppressWarnings(
      recipes::bake(featx_fitted, new_data = x)
    )
  }
}


#' @export
predict.logistic_reg_featx <- function(object, new_data, ...) {

  features <- object$extract_features(new_data)
  # this will go to predict.logistic_reg, but using the process data
  NextMethod(new_data = features)

}
