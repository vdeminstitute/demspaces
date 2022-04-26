#
#   Deploy outcome explorer app to shinyapps.io
#
#   NOTE: make sure demspacesR is installed from GitHub, not local source,
#         otherwise rsconnect will not recognize it needs to be installed from
#
#   https://basil-analytics.shinyapps.io/demspaces/
#

library(rsconnect)

app_dir <- "./"
stopifnot(basename(getwd())=="demspaces")
app_files <- c(
  "DESCRIPTION",
  "NAMESPACE",
  ".Rbuildignore",
  "app.R",
  "data",
  "R"
)

deployApp(appDir = app_dir, appFiles = app_files)

# to check how dependencies are resolved:
#appDependencies(appDir = app_dir, appFiles = app_files)
