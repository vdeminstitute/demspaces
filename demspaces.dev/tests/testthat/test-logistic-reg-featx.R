
library(modeldata)
data(credit_data)

credit_data <- credit_data[complete.cases(credit_data), ]

credit_features <- credit_data[, setdiff(colnames(credit_data), "Status")]

test_that("feature extraction works", {

  expect_error(
    featx <- make_extract_features(credit_features),
    NA)
  expect_type(featx, "closure")

  expect_error(
    new_features <- featx(credit_features),
    NA
  )
  expect_s3_class(new_features, "data.frame")

})

test_that("logistic_reg_featx works", {

  expect_error(
    mdl <- logistic_reg_featx(credit_features, credit_data$Status),
    NA
  )
  expect_s3_class(mdl, "logistic_reg_featx")

})

test_that("predict.logistic_reg_featx works", {

  mdl <- logistic_reg_featx(credit_features, credit_data$Status)

  expect_error(
    preds <- predict(mdl, new_data = credit_data),
    NA
  )

  expect_equal(
    colnames(preds),
    paste0("p_", levels(credit_data$Status))
  )

})

test_that("results differ from plain logistic_reg", {

  mdl1 <- logistic_reg_featx(credit_features, credit_data$Status)
  mdl2 <- logistic_reg(credit_features, credit_data$Status)

  preds1 <- predict(mdl1, new_data = credit_data)
  preds2 <- predict(mdl2, new_data = credit_data)

  expect_true(all(head(preds1$p_good)!=head(preds2$p_good)))
})


test_that("ds_logistic_reg_featx work", {

  data("states")
  states <- states %>%
    dplyr::filter(complete.cases(.))

  expect_error(
    mdl <- ds_logistic_reg_featx("v2x_veracc_osp", states),
    NA
  )


})

test_that("predict.ds_logistic_reg_featx works", {

  data("states")
  states <- states %>%
    dplyr::filter(complete.cases(.))

  mdl <- ds_logistic_reg("v2x_veracc_osp", states)

  expect_error(
    preds <- predict(mdl, new_data = states),
    NA
  )

})
