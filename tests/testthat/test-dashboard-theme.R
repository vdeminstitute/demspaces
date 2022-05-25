
test_that("dashboard theme funcs work", {
  expect_equal(
    color_direction(c("Opening", "Same", "Closing", "foo")),
    c(Opening = "#0082BA", Same = "#D0D0D1", Closing = "#F37321",
      foo = "#D0D0D1")
  )
})
