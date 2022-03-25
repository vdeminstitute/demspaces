#
#   Run the demspaces Shiny dashboard
#

library(here)
library(DT)
library(shiny)
library(leaflet)
library(highcharter)
library(shinyWidgets)
library(shinyBS)

runApp(appDir = here::here("dashboard"))
