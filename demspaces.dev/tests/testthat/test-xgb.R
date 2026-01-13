
credit_data <- modeldata::credit_data
credit_data <- credit_data[complete.cases(credit_data), ]

credit_features <- credit_data[, setdiff(colnames(credit_data), "Status")]

test_that("xgb works", {

  expect_error(
    mdl <- xgb(credit_features, credit_data$Status),
    NA
  )
  expect_s3_class(mdl, "xgb")

})

test_that("predict.xgb works", {

  mdl <- xgb(credit_features, credit_data$Status)

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


test_that("ds_xgb work", {

  expect_error(
    mdl <- ds_xgb("v2x_veracc_osp", states),
    NA
  )

})

test_that("predict.ds_xgb works", {

  mdl <- ds_xgb("v2x_veracc_osp", states)

  expect_error(
    preds <- predict(mdl, new_data = states),
    NA
  )

})
