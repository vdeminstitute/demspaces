
credit_data <- recipes::credit_data
credit_data <- credit_data[complete.cases(credit_data), ]

credit_features <- credit_data[, setdiff(colnames(credit_data), "Status")]

test_that("{{{short_name}}} works", {

  expect_error(
    mdl <- {{{short_name}}}(credit_features, credit_data$Status),
    NA
  )
  expect_s3_class(mdl, "{{{short_name}}}")

})

test_that("predict.{{{short_name}}} works", {

  mdl <- {{{short_name}}}(credit_features, credit_data$Status)

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


test_that("ds_{{{short_name}}} work", {

  expect_error(
    mdl <- ds_{{{short_name}}}("v2x_veracc_osp", states),
    NA
  )

})

test_that("predict.ds_{{{short_name}}} works", {

  mdl <- ds_{{{short_name}}}("v2x_veracc_osp", states)

  expect_error(
    preds <- predict(mdl, new_data = states),
    NA
  )

})
