
#' Reguarized logistic regression
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
#' mdl <- ds_reg_logreg("v2x_veracc_osp", states, alpha_n = 1)
#' preds <- predict(mdl, new_data = states)
#'
#' @export
#' @import stats
#' @concept ds_model
#' @family Other DS models
ds_reg_logreg <- function(space, data, ...) {

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
  if (any(is.na(full_data[, ynamedown]), is.na(full_data[, ynameup]))) {
    warning(sprintf("Discarding %s incomplete outcome set cases",
                    sum(!keep_idx)))

    keep_idx <- stats::complete.cases(train_data)
    train_data <- train_data[keep_idx, ]
    train_x    <- train_x[keep_idx, ]

  }

  up_mdl   <- reg_logreg(x = train_x, y = train_data[, ynameup], ...)

  down_mdl <- reg_logreg(x = train_x, y = train_data[, ynamedown], ...)

  new_ds_reg_logreg(up_mdl, down_mdl, space)
}

#' Constructor
#' @keywords internal
new_ds_reg_logreg <- function(up_mdl, down_mdl, yname) {
  structure(
    list(
      up_mdl   = up_mdl,
      down_mdl = down_mdl
    ),
    yname = yname,
    class = "ds_reg_logreg"
  )
}

#' @export
#' @importFrom stats predict
predict.ds_reg_logreg <- function(object, new_data, ...) {

  if (any(!c("gwcode", "year") %in% names(new_data))) {
    stop("'new_data' must contain 'gwcode' and 'year' columns")
  }

  up_mdl   <- object$up_mdl
  down_mdl <- object$down_mdl
  yname    <- attr(object, "yname")

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

#' Reguarized logistic regression
#'
#' Standardized interface for self-tuning regularized logistic regression.
#'
#' @param x Data frame with features.
#' @param y Binary vector indicating outcome event.
#' @param folds Number of folds to use for CV tuning
#' @param alpha_n Number of alpha values to sample for CV tuning
#' @param cost Cost measure to use, see [glmnet::cv.glmnet()]
#' @param lambda Decision rule to pick lambda, one of "min", "1se", "0.5se"
#'
#' @details Tuning is performed using cross-validation with [glmnet::cv.glmnet()].
#'   Both lambda and alpha values are tuned. The lambda values are left to the
#'   model default and a uniform grid of alpha values is used. The lambda value
#'   is picked with [glmnet::cv.glmnet()]'s more robust 1se value (i.e. not the
#'   absolute minimum, but closest value within 1 SD of the minimum value). Then
#'   the globally optimum alpha value is picked.
#'
#' @examples
#' library(modeldata)
#' data(credit_data)
#' credit_data <- credit_data[complete.cases(credit_data), ]
#'
#' mdl <- reg_logreg(credit_data[, setdiff(colnames(credit_data), "Status")],
#'                     credit_data$Status,
#'                     folds = 5, alpha_n = 4)
#' # plots to review tuning results
#' plot(mdl)
#' plot(mdl, "alpha")
#' plot(mdl, "lambda")
#' preds <- predict(mdl, new_data = credit_data)
#' head(preds)
#'
#' @export
#' @concept base_model
#' @family Other base models
reg_logreg <- function(x, y, folds = 5, alpha_n = 3, cost = "mse", lambda = "1se") {

  cv_k    <- folds
  alpha_n <- alpha_n

  stopifnot(lambda %in% c("min", "1se", "0.5se"))
  lambda_rule <- lambda

  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop("Package \"glmnet\" needed for this function to work. Please install it.",
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

  m <- model.frame(~ -1 + ., data = x, na.action = "na.omit")
  model_terms <- terms(m)
  X <- model.matrix(model_terms, data = x)

  # lambda is auto-picked by cv.glmnet, but setup alpha grid values
  # since lambda is constant for a given alpha, use uniform spacing rather
  # than random to get better coverage

  # if alpha_n = 1 this will end up with alpha = 1
  alpha <- sort(seq(1, 0, length.out = alpha_n))

  # make sure all iterations use the same internal CV splits
  fold_id <- sample(rep(1:cv_k, length.out = nrow(X)))



  cvmodel <- list()
  for (i in seq_along(alpha)) {
    mdl_i <- glmnet::cv.glmnet(y = y, x = X, foldid = fold_id,
                               alpha = alpha[i],
                               family = "binomial", type.measure = cost)
    mdl_i$alpha <- alpha[i]

    lambda <- mdl_i$lambda
    cvm    <- mdl_i$cvm
    if (cost=="auc") cvm = -cvm
    cvsd   <- mdl_i$cvsd

    cvmin = min(cvm, na.rm = TRUE)
    idmin = cvm <= cvmin
    lambda.min = max(lambda[idmin], na.rm = TRUE)
    idmin = match(lambda.min, lambda)
    semin = (cvm + 0.5*cvsd)[idmin]
    idmin = cvm <= semin
    lambda.0.5se = max(lambda[idmin], na.rm = TRUE)
    mdl_i$lambda.0.5se <- lambda.0.5se

    cvmodel[[i]] <- mdl_i
  }

  # extract alpha, lambda, and fit measure grid
  hp_grid <- lapply(cvmodel, function(mdl_i) {
    tibble::tibble(alpha = mdl_i$alpha, lambda = mdl_i$lambda, cvm = mdl_i$cvm)
  })
  hp_grid <- dplyr::bind_rows(hp_grid)

  loptim_grid <- tibble::tibble(
    alpha = alpha,
    lambda.min   = sapply(cvmodel, `[[`, "lambda.min"),
    lambda.1se   = sapply(cvmodel, `[[`, "lambda.1se"),
    lambda.0.5se = sapply(cvmodel, `[[`, "lambda.0.5se"),
  )
  loptim_grid <- tidyr::pivot_longer(
    loptim_grid, -"alpha",
    names_to = "rule", names_pattern = "lambda\\.([a-z0-9\\.]+)",
    values_to = "lambda")
  loptim_grid <- dplyr::left_join(loptim_grid, hp_grid,
                                by = c("alpha" = "alpha", "lambda" = "lambda"))

  # Pick alpha value
  # ID min value; if it is 1 or 0, try to move one closer to center
  grid <- loptim_grid[loptim_grid$rule==lambda_rule, ]
  if (cost=="auc") {
    grid$cvm <- -grid$cvm
  }
  min_idx <- which.min(grid$cvm)
  if (alpha_n > 2 & min_idx %in% c(1, alpha_n)) {
    if (min_idx==1) idx <- min_idx + 1
    if (min_idx==alpha_n) idx <- min_idx - 1
  } else {
    idx <- min_idx
  }
  alpha_pick  <- grid[idx, "alpha", drop = TRUE]
  loptim_grid$pick <- as.integer(loptim_grid$alpha==alpha_pick &
                                 loptim_grid$rule==lambda_rule)
  tune_res <- as.list(loptim_grid[loptim_grid$pick==1, c("alpha", "lambda", "cvm")])

  final_model <- cvmodel[alpha==alpha_pick][[1]]$glmnet.fit

  new_reg_logreg(final_model,
                 levels(y),
                 model_terms,
                 hp_grid,
                 loptim_grid,
                 tune_res)
}

#' Constructor
#' @keywords internal
new_reg_logreg <- function(model, y_classes, model_terms, hp_grid, loptim_grid, tune_res) {
  structure(
    list(model = model,
         model_terms = model_terms,
         tune = list(
           hp_grid = hp_grid,
           loptim_grid = loptim_grid,
           tune_res = tune_res
         )),
    y_classes = y_classes,
    class = "reg_logreg"
  )
}

#' Plot reg_logreg
#'
#' @param x see [reg_logreg()]
#' @param type one of "grid", "lambda", "alpha"; see examples
#' @param base use base plot, not ggplot2?
#' @param ... not used
#'
#' @export
#' @importFrom grDevices colorRampPalette
#' @importFrom graphics plot points text
plot.reg_logreg <- function(x, type = NULL, base = FALSE, ...) {
  hp_grid   <- x$tune$hp_grid
  loptim_grid <- x$tune$loptim_grid
  tune_res  <- x$tune$tune_res

  if (is.null(type)) type <- "grid"
  stopifnot(type %in% c("grid", "alpha", "lambda"))

  if (requireNamespace("ggplot2", quietly = TRUE) & isFALSE(base)) {

    if (type=="grid") {
      p <- ggplot2::ggplot(hp_grid) +
        ggplot2::scale_x_log10() +
        ggplot2::geom_point(ggplot2::aes(x = .data$lambda, y = .data$alpha, color = .data$cvm)) +
        ggplot2::scale_color_distiller("CVM", palette = "Spectral") +
        ggplot2::geom_point(data = loptim_grid,
                   ggplot2::aes(x = .data$lambda, y = .data$alpha, shape = .data$rule),
                   size = 3, color = "red") +
        ggplot2::scale_shape_manual(
          "Lambda rule",
          values = c("min" = 3, "0.5se" = 2, "1se" = 4)) +
        ggplot2::geom_point(data = tibble::as_tibble(tune_res),
                   ggplot2::aes(x = .data$lambda, y = .data$alpha),
                   shape = 19, size = 3, color = "red") +
        ggplot2::annotate("text", x = tune_res$lambda, y = tune_res$alpha,
                          label = sprintf("CVM: %s", round(tune_res$cvm, 3)),
                          hjust = -.2, vjust = -1) +
        ggplot2::labs(x = "lambda", y = "alpha") +
        ggplot2::theme_bw()
      return(p)
    }

    if (type=="lambda") {
      p <- ggplot2::ggplot(hp_grid) +
        ggplot2::geom_line(ggplot2::aes(x = .data$lambda, y = .data$cvm,
                      color = factor(.data$alpha)), alpha = 0.2) +
        ggplot2::geom_point(ggplot2::aes(x = .data$lambda, y = .data$cvm,
                       color = factor(.data$alpha))) +
        ggplot2::scale_color_discrete("Alpha") +
        ggplot2::scale_x_log10() +
        ggplot2::geom_point(data = loptim_grid,
                   ggplot2::aes(x = .data$lambda, y = .data$cvm, shape = .data$rule),
                   size = 3, color = "red") +
        ggplot2::scale_shape_manual(
          "Lambda rule",
          values = c("min" = 3, "0.5se" = 2, "1se" = 4)) +
        ggplot2::labs(x = "Lambda", y = "CVM") +
        ggplot2::geom_point(data = tibble::as_tibble(tune_res),
                   ggplot2::aes(x = .data$lambda, y = .data$cvm),
                   shape = 19, size = 3, color = "red") +
        ggplot2::annotate("text", x = tune_res$lambda, y = tune_res$cvm,
                          label = sprintf("CVM: %s", round(tune_res$cvm, 3)),
                          hjust = 1.2, vjust = -1) +
        ggplot2::theme_bw()
      return(p)
    }

    if (type=="alpha") {
      p <- ggplot2::ggplot(hp_grid) +
        ggplot2::geom_point(ggplot2::aes(x = .data$alpha, y = .data$cvm, color = .data$lambda)) +
        ggplot2::scale_color_distiller(
          "Lambda", palette = "Spectral",
          trans = "log",
          labels = scales::number_format(accuracy = 0.001)) +
        ggplot2::geom_point(data = loptim_grid,
                   ggplot2::aes(x = .data$alpha, y = .data$cvm, shape = .data$rule),
                   size = 3, color = "red") +
        ggplot2::scale_shape_manual(
          "Lambda rule",
          values = c("min" = 3, "0.5se" = 2, "1se" = 4)) +
        ggplot2::labs(x = "Alpha", y = "CVM") +
        ggplot2::geom_point(data = tibble::as_tibble(tune_res),
                   ggplot2::aes(x = .data$alpha, y = .data$cvm),
                   shape = 19, size = 3, color = "red") +
        ggplot2::annotate("text", x = tune_res$alpha, y = tune_res$cvm,
                          label = sprintf("CVM: %s", round(tune_res$cvm, 3)),
                          hjust = -.2, vjust = -1) +
        ggplot2::theme_bw()
      return(p)
    }

    stop("something went wrong")

  } else {

    if (type=="grid") {
      pal  <- colorRampPalette(grDevices::cm.colors(10))
      cols <- pal(100)
      x <- hp_grid$cvm
      xmin <- min(x)
      xmax <- max(x)
      x <- (x - xmin)/(xmax - xmin) * 99 + 1
      x <- round(x)
      cols <- cols[x]
      plot(log10(hp_grid$lambda), hp_grid$alpha, col = cols,
           xlab = "log10(lambda)", ylab = "alpha")
      points(log10(loptim_grid$lambda), loptim_grid$alpha,
             pch = 3, cex = 1.5, col = "red")
      points(log10(tune_res$lambda), tune_res$alpha,
             pch = 19, cex = 1.5, col = "red")
      text(x = log10(tune_res$lambda), y = tune_res$alpha,
           labels = sprintf("CVM: %s", round(tune_res$cvm, 3)),
           adj = c(-.2, -1))
      return(invisible(x))
    }

    stop("Only type = 'grid' is implemented for base")

  }
  invisible(x)
}


#' @export
predict.reg_logreg <- function(object, new_data, ...) {

  # missing value handling:
  # this will subset out missing values, but in predictions let's return those
  # by keeping track of index of X in new_data using row names
  X <- model.matrix(object$model_terms, data = new_data)
  idx = match(rownames(X), rownames(new_data))

  y_classes <- attr(object, "y_classes")
  p <- predict(object$model, newx = X, type = "response",
               s = object$tune$tune_res$lambda)
  # these probabilities are for the second class level
  # from ?glmnet:
  # for a factor, the last level in alphabetical order is the target class
  p <- p[, 1, drop = TRUE]
  preds <- tibble::tibble(
    p0 = rep(NA_real_, nrow(new_data)),
    p1 = rep(NA_real_, nrow(new_data))
  )
  preds$p0[idx] <- 1 - p
  preds$p1[idx] <- p
  colnames(preds) <- paste0("p_", y_classes)
  preds

}



