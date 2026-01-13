#
# This code can be used to add the R and test files for a new model,
# using a template that sets up the basic structure and requirements
#

library("whisker")
library("stringr")
library("usethis")

oldwd <- getwd()
setwd(here::here("demspaces.dev"))

# set these data components
# the short name should avoid R namespace clashes, e.g. don't use "glmnet"
# as one of the functions created will equal the short_name
data <- list(name       = "XGBoost",
             short_name = "xgb")




r_template <- readLines("inst/templates/model.R")
r_str <- whisker.render(r_template, data)

test_template <- readLines("inst/templates/test-model.R")
test_str <- whisker.render(test_template, data)

file_name <- stringr::str_replace(data$short_name, "_", "-")
r_fp    <- sprintf("R/%s.R", file_name)
test_fp <- sprintf("tests/testthat/test-%s.R", file_name)

writeLines(r_str, con = r_fp)
writeLines(test_str, con = test_fp)

usethis::edit_file(r_fp)
usethis::edit_file(test_fp)

setwd(oldwd)

