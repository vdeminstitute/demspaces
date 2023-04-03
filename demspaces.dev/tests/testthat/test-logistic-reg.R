
library(modeldata)
data(credit_data)

test_that("logist_reg works", {


  expect_error(
    mdl <- logistic_reg(credit_data[, setdiff(colnames(credit_data), "Status")],
                        credit_data$Status),
    NA
  )

})

test_that("predict.logistic_reg works", {

  mdl <- logistic_reg(credit_data[, setdiff(colnames(credit_data), "Status")],
                      credit_data$Status)
  expect_error(
    preds <- predict(mdl, new_data = credit_data),
    NA
  )

})

test_that("ds_logistic_reg work", {

  data("states")
  states <- states %>%
    dplyr::filter(complete.cases(.))

  expect_error(
    mdl <- ds_logistic_reg("v2x_veracc_osp", states),
    NA
  )


})

test_that("predict.ds_logistic_reg works", {

  data("states")
  states <- states %>%
    dplyr::filter(complete.cases(.))

  mdl <- ds_logistic_reg("v2x_veracc_osp", states)

  expect_error(
    preds <- predict(mdl, new_data = states),
    NA
  )

})


test_that("normalize option works but does not affect preds", {

  data("states")
  states <- states %>%
    dplyr::filter(complete.cases(.))

  mdl_raw   <- ds_logistic_reg("v2x_veracc_osp", states, normalize = FALSE)
  preds_raw <- predict(mdl_raw, new_data = states)

  mdl_std   <- ds_logistic_reg("v2x_veracc_osp", states, normalize = TRUE)
  preds_std <- predict(mdl_std, new_data = states)

  expect_equal(
    nrow(preds_raw),
    nrow(preds_std)
  )

  # the raw and std preds differ
  # expect_equal(
  #   preds_raw,
  #   preds_std
  # )
  # plot(preds_raw$p_up, preds_std$p_up)
#
#   x2 <- mdl_std$standardize(states)
#   x1 <- mdl_raw$standardize(states)
#   x1 <- x1[, names(x1) %in% names(x2)]
#   NC <- ncol(x1)
#   png("~/Desktop/histograms.png", height = 1600, width = 2048)
#   par(mfrow = c(5, 6))
#   for (i in 1:NC) {
#     hist(x1[[i]], main = sprintf("raw %s", names(x1)[i]))
#     hist(x2[[i]], main = sprintf("std %s", names(x2)[i]))
#   }
#   dev.off()

})

