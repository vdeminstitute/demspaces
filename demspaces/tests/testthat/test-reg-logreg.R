
library(modeldata)
data(credit_data)

credit_data <- credit_data[complete.cases(credit_data), ]

credit_features <- credit_data[, setdiff(colnames(credit_data), "Status")]

test_that("reg_logreg works", {

  expect_error(
    mdl <- reg_logreg(credit_features, credit_data$Status,
                      folds = 3, alpha_n = 1),
    NA
  )
  expect_s3_class(mdl, "reg_logreg")

})

test_that("predict.reg_logreg works", {

  mdl <- reg_logreg(credit_features, credit_data$Status,
                    folds = 3, alpha_n = 1)

  expect_error(
    preds <- predict(mdl, new_data = credit_data),
    NA
  )

  expect_equal(
    colnames(preds),
    paste0("p_", levels(credit_data$Status))
  )

})


data("states")
states <- states %>%
  dplyr::filter(complete.cases(.))


test_that("ds_reg_logreg work", {

  expect_error(
    mdl <- ds_reg_logreg("v2x_veracc_osp", states, alpha_n = 1),
    NA
  )

})

test_that("predict.ds_reg_logreg works", {

  mdl <- ds_reg_logreg("v2x_veracc_osp", states, alpha_n = 1)

  expect_error(
    preds <- predict(mdl, new_data = states),
    NA
  )

})
