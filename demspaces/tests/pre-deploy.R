#
#   Pre-deployment tests, e.g.:
#
#     - make sure Shiny app tarball is current
#     - make sure archived forecasts and data are current
#

library(here)
library(testthat)

# The path will differ on GitHub and locally when tests are run, figure out
# where we are
correct_path <- function(...) {
  curr_root <- here::here()
  if (grepl("demspaces/demspaces/demspaces", curr_root)) {
    out <- here::here("..", ...)
  } else if (grepl("demspaces/demspaces", curr_root)) {
    out <- here::here("..", ...)
  } else {
    out <- here::here(...)
  }
  out
}

get_mtime <- function(...) {
  file.info(correct_path(...))[, "mtime"]
}


#
#   Make sure the Shiny app tarball is current ----
#

test_that("tarball is current", {

  # #27
  skip_on_ci()

  files <- c(
    "global.r", "server.r", "ui.r", "styles.css",
    paste0("data/", dir(correct_path("dashboard/data")))
  )
  files <- paste0("dashboard/", files)
  file_modtime <- get_mtime(files)

  tarball_modtime <- get_mtime("dashboard/demspaces-dashboard.tar.gz")

  expect_true(all(tarball_modtime >= file_modtime))
})

#
#   Make sure everything is using latest forecasts ----
#

test_that("dashboard/data-raw/input/fcasts-rf.csv is current", {

  # #27
  skip_on_ci()

  expect_gte(
    get_mtime("dashboard/data-raw/input/fcasts-rf.csv"),
    get_mtime("modelrunner/output/fcasts-rf.csv")
  )
})


#
#   Archive is current ----
#

test_that("archived is current", {

  # #27
  skip_on_ci()

  expect_gte(
    get_mtime("archive/fcasts-rf-v12.1.csv"),
    get_mtime("modelrunner/output/fcasts-rf-v12.1.csv")
  )

  expect_gte(
    get_mtime("archive/scores/fcasts-rf-v12.1-score-summary.csv"),
    get_mtime("archive/fcasts-rf-v12.1.csv")
  )

  expect_gte(
    get_mtime("archive/data/states-v12.1.rds"),
    get_mtime("create-data/output/states-v12.1.rds")
  )

  expect_gte(
    get_mtime("archive/data/states-v12.1-signature.yml"),
    get_mtime("create-data/output/states-v12.1-signature.yml")
  )
})

test_that("archive human readable forecasts are current", {

  # #27
  skip_on_ci()

  # Run human-readable.R if this fails
  expect_gte(
    get_mtime("archive/forecasts-v12.1.csv"),
    get_mtime("archive/fcasts-rf-v12.1.csv")
  )
})
