
#' ds_fcast constructor
#'
#' @param x a data frame of forecasts
#'
#' @export
#'
#' @examples
#' data("states")
#'
#' mdl <- ds_logistic_reg("v2x_veracc_osp", states)
#' preds <- predict(mdl, new_data = states)
#' head(ds_fcast(preds))
ds_fcast <- function(x) {
  if (inherits(x, "ds_fcast")) return(x)
  xnames <- names(x)
  stopifnot(setequal(xnames, c("outcome", "from_year", "for_years", "gwcode",
                               "p_up", "p_same", "p_down")))
  class(x) <- c("ds_fcast", class(x))
  x
}

#' Score forecasts
#'
#' @param x [ds_fcast()]
#' @param truth_data states data
#'
#' @examples
#' data("states")
#'
#' mdl <- ds_logistic_reg("v2x_veracc_osp", states)
#' preds <- predict(mdl, new_data = states)
#' fcasts <- ds_fcast(preds)
#' score_ds_fcast(fcasts, states)
#' @export
score_ds_fcast <- function(x, truth_data) {
  x <- ds_fcast(x)
  x <- add_truth_data_ds_fcast(x, truth_data)

  suppressWarnings({
  stats <- list(
    "Pos-rate up"   = mean(x$up=="1",   na.rm = TRUE),
    "Pos-rate down" = mean(x$down=="1", na.rm = TRUE),
    "Log-loss up"   = safe_mn_log_loss(x$up, x$p_up),
    "Log-loss down" = safe_mn_log_loss(x$down, x$p_down),
    "ROC-AUC up"   = safe_roc_auc(x$up, x$p_up),
    "ROC-AUC down" = safe_roc_auc(x$down, x$p_down),
    "PR-AUC up"    = safe_roc_pr(x$up, x$p_up) ,
    "PR-AUC down"  = safe_roc_pr(x$down, x$p_down)
  ) %>% tibble::enframe(value = "Value") %>%
    tidyr::unnest(.data$Value) %>%
    tidyr::separate(.data$name, into = c("Measure", "Direction"), sep = " ")
  })
  stats
}

safe_roc_auc <- function(y, phat) {
  tryCatch({
    yardstick::roc_auc_vec(y, phat)
  }, error = function(e) NA_real_)
}

safe_roc_pr <- function(y, phat) {
  tryCatch({
    yardstick::pr_auc_vec(y, phat)
  }, error = function(e) NA_real_)
}

safe_mn_log_loss <- function(y, phat) {
  tryCatch({
    yardstick::mn_log_loss_vec(y, phat)
  }, error = function(e) NA_real_)
}


#' Add truth data to forecasts
#'
#' @param x [ds_fcast()]
#' @param truth_data states data
#'
#' @export
#' @importFrom rlang .data
add_truth_data_ds_fcast <- function(x, truth_data) {
  stopifnot(inherits(x, "ds_fcast"))

  truth_data <- truth_data %>%
    dplyr::select(.data$gwcode, .data$year, dplyr::ends_with("next2"))

  truth_data <- truth_data %>%
    tidyr::gather(key = "var", value = "value", -.data$gwcode, -.data$year) %>%
    dplyr::mutate(change = dplyr::case_when(
      stringr::str_detect(.data$var, "\\_up\\_") ~ "up",
      stringr::str_detect(.data$var, "\\_down\\_") ~ "down",
      TRUE ~ NA_character_
    )) %>%
    dplyr::mutate(var = stringr::str_replace(.data$var, "dv\\_", ""),
                  var = stringr::str_replace(.data$var, "\\_(up|down)\\_next2", ""),
                  # yardstick requires factor labels
                  value = factor(.data$value, levels = c("1", "0")))

  truth_data <- truth_data %>%
    tidyr::spread(.data$change, .data$value)

  xaug <- x %>%
    dplyr::left_join(truth_data, by = c("gwcode", "from_year" = "year", "outcome" = "var"))
  xaug
}
