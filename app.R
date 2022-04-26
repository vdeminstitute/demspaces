#
#   Run the demspaces Shiny dashboard
#

pkgload::load_all(".")

outcome_explorer_app()

# This is old stuff for the dashboard:
#
# library(here)
# library(DT)
# library(shiny)
# library(leaflet)
# library(highcharter)
# library(shinyWidgets)
# library(shinyBS)
#runApp(appDir = here::here("dashboard"))
