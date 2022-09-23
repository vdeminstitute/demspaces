
#' {{{name}}}
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
#' mdl <- ds_logistic_reg("v2x_veracc_osp", states)
#' preds <- predict(mdl, new_data = states)
#'
#' @export
ds_{{{short_name}}} <- function(space, data, ...) {

  new_ds_{{{short_name}}}(up_mdl, down_mdl, standardize, space)
}

#' Constructor
#' @keywords internal
new_ds_{{{short_name}}} <- function(..., yname) {
  structure(
    list(
      NULL
    ),
    yname = yname,
    class = "ds_{{{short_name}}}"
  )
}

#' @export
#' @importFrom stats predict
predict.ds_{{{short_name}}} <- function(object, new_data, ...) {

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

#' {{{name}}}
#'
#' Standardized interface for ...
#'
#' @param x Data frame with features.
#' @param y Binary vector indicating outcome event.
#'
#' @examples
#' credit_data <- recipes::credit_data
#'
#' mdl <- {{{short_name}}}(credit_data[, setdiff(colnames(credit_data), "Status")],
#'                     credit_data$Status)
#'
#' @export
{{{short_name}}} <- function(x, y) {

  if (inherits(y, "data.frame")) {
    y = y[[1]]
  }

  new_{{{short_name}}}(fit, levels(y))
}

#' Constructor
#' @keywords internal
new_{{{short_name}}} <- function() {
  structure(
    list(NULL),
    class = "{{{short_name}}}"
  )
}

#' @export
predict.{{{short_name}}} <- function(object, new_data, ...) {

  NULL

}



