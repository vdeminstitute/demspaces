#
#   Deploy mod outcome dashboard app to shinyapps.io
#
#   NOTE: make sure demspaces is installed from GitHub, not local source,
#         otherwise rsconnect will not recognize it needs to be installed from
#
#   https://basil-analytics.shinyapps.io/demspaces-mod/
#

library(rsconnect)

oldwd <- getwd()
setwd(here::here())

app_dir <- "dashboard"
app_files <- c(
  "data",
  "global.r",
  "server.r",
  "setup.r",
  "ui.r",
  "startup.r",
  "styles.css"
)

deployApp(appDir = app_dir, appFiles = app_files, appName = "demspaces-mod")

# to check how dependencies are resolved:
#appDependencies(appDir = app_dir, appFiles = app_files)

setwd(oldwd)
