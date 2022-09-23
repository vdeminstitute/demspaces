
library(modeldata)
data(credit_data)

credit_data <- credit_data[complete.cases(credit_data), ]

credit_features <- credit_data[, setdiff(colnames(credit_data), "Status")]

test_that("rf works", {

  expect_error(
    mdl <- rf(credit_features, credit_data$Status),
    NA
  )
  expect_s3_class(mdl, "rf")

})

test_that("predict.rf works", {
  mdl <- rf(credit_features, credit_data$Status)
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


test_that("ds_rf work", {
  expect_error(
    mdl <- ds_rf("v2x_veracc_osp", states),
    NA
  )
})

test_that("sidestepping mtry tuning works", {
  expect_error(
    mdl <- ds_rf("v2x_veracc_osp", states, mtry = 3),
    NA
  )
  expect_true(mdl$up_mdl$model$mtry==3)
  expect_error(
    mdl <- ds_rf("v2x_veracc_osp", states, mtry = 4),
    NA
  )
  expect_true(mdl$up_mdl$model$mtry==4)
})


# predict.ds_rf method -------------------------------------------------------

mdl <- ds_rf("v2x_veracc_osp", states)

test_that("predict.ds_rf works", {
  expect_error(
    preds <- predict(mdl, new_data = states),
    NA
  )
})

test_that("unlikely forecast adjustment (#15) works", {
  preds <- predict(mdl, new_data = states, cutpoint = 0.1)

  # make sure all "impossible" predictions are now 0
  expect_setequal(preds$p_down[states$v2x_veracc_osp < 0.1], 0)
  expect_setequal(preds$p_up[states$v2x_veracc_osp > (1 - 0.1)], 0)

})

