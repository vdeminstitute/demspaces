#
#   Pre-deployment tests, e.g.:
#
#     - make sure Shiny app tarball is current
#     - make sure archived forecasts and data are current
#

library(here)

get_mtime <- function(...) {
  file.info(here::here(...))[, "mtime"]
}

#
#   Make sure the Shiny app tarball is current ----
#

test_that("tarball is current", {
  files <- c(
    "global.r", "server.r", "ui.r", "styles.css",
    paste0("data/", dir(here::here("dashboard/data")))
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
  expect_gte(
    get_mtime("dashboard/data-raw/input/fcasts-rf.csv"),
    get_mtime("modelrunner/output/fcasts-rf.csv")
  )
})


#
#   Archive is current ----
#

test_that("archived is current", {
  expect_gte(
    get_mtime("archive/fcasts-rf-v12.csv"),
    get_mtime("modelrunner/output/fcasts-rf-v12.csv")
  )

  expect_gte(
    get_mtime("archive/scores/fcasts-rf-v12-score-summary.csv"),
    get_mtime("archive/fcasts-rf-v12.csv")
  )

  expect_gte(
    get_mtime("archive/data/states-v12.rds"),
    get_mtime("create-data/output/states-v12.rds")
  )

  expect_gte(
    get_mtime("archive/data/states-v12-signature.yml"),
    get_mtime("create-data/output/states-v12-signature.yml")
  )
})

test_that("archive human readable forecasts are current", {
  # Run human-readable.R if this fails
  expect_gte(
    get_mtime("archive/forecasts-v12.csv"),
    get_mtime("archive/fcasts-rf-v12.csv")
  )
})
