#' Make data standardizer
#'
#' Create a data standardizer function using the relevant statistics in a
#' input data frame.
#'
#' @param x a [base::data.frame()] or similar object
#'
#' @return The returned object is a function that will standarize all non-binary
#'   variables using the means and SDs for relevant columns in the input `x`
#'   data frame.
#'
#'   The point of doing it this way is that we need to record the relevant
#'   training data means and SDs so we can standardize test data at the
#'   prediction stage as well.
#'
#'   One option would be to record the trainin data means and SDs instead,
#'   but we will in any case use that to call another function that does
#'   the standardization, so we might as well do it now.
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
#' standardize <- make_standardizer(train_x)
#' prepped_train_x <- standardize(train_x)
#'
#' do.call(rbind,
#'         lapply(prepped_train_x, function(x) {
#'           data.frame(mean = mean(x), SD = sd(x))
#'         }))
#'
#' # the training data means and SDs are used for standardization
#' prepped_test_x <- standardize(test_x)
#' do.call(rbind,
#'         lapply(prepped_test_x, function(x) {
#'           data.frame(mean = mean(x), SD = sd(x))
#' }))
#'
#' @export
make_standardizer <- function(x) {

  stopifnot(all(stats::complete.cases(x)))

  sds <- sapply(x, stats::sd)
  if (any(sds==0)) {
    stop("Constant value variables detected, cannnot normalize")
  }

  bin_vars <- names(x)[sapply(x, is_binary_var)]

  # Warning: All elements of `...` must be named.
  # this is from https://github.com/tidymodels/recipes/pull/364
  suppressWarnings({
  preproc <- recipes::recipe(x, formula = ~ .) %>%
    recipes::add_role(dplyr::one_of(bin_vars), new_role = "binary_predictor") %>%
    recipes::step_normalize(-recipes::has_role("binary_predictor"))


  trained <- recipes::prep(preproc, training = x)
  })

  function(x) {
    # Warning: All elements of `...` must be named.
    # this is from https://github.com/tidymodels/recipes/pull/364
    suppressWarnings(
      recipes::bake(trained, new_data = x)
    )
  }
}

# ID binary variables
is_binary_var <- function(x) {
  if (all(range(x)==c(0, 1))) {
    if (all(unique(x) %in% c(0, 1))) {
      return(TRUE)
    }
  }
  FALSE
}

