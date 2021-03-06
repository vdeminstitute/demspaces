#
#   Originally written by Rick Morgan and Laura Maxwell
#

library(dplyr)
library(tidyr)
library(leaflet)
library(shiny)
library(highcharter)
library(shinyWidgets)
library(shinyBS)
library(here)
library(sf)


# Load data ---------------------------------------------------------------

map_data <- readRDS("data/map_dat.rds")
map_color_data <- readRDS("data/map_color_data.rds")

country_characteristic_dat <- readRDS("data/country_characteristic_dat.rds")
countryNamesText <- c("", sort(unique(as.character(country_characteristic_dat$country_name))))

prob1_dat <- readRDS("data/prob1_dat.rds")
table_dat <- readRDS("data/table_dat.rds")


# Year range for V-Dem indicator plot at bottom right
YEAR_RANGE <- sort(unique(country_characteristic_dat$year))


data_table_format <- htmltools::withTags(table(
  class = 'display',
  thead(
    tr(
      th(colspan = 2, style = 'text-align: center; border: 0; color:#A51E36; font-size: 150%;', '2021-2022 Forecasts'),
      th(colspan = 3, style = 'text-align: center; color:#002649;', 'Opening'),
      th(colspan = 3, style = 'text-align: center; color:#002649;', 'Closing')
    ),
    tr(
      th(style = 'text-align: center; color:#002649;', 'Country'),
      th(style = 'text-align: center; color:#002649;', 'Space'),
      th(style = 'text-align: center; color:#002649;', 'Estimate'),
      th(style = 'text-align: center; color:#002649;', 'Ranking'),
      th(style = 'text-align: center; color:#002649;', 'Category'),
      th(style = 'text-align: center; color:#002649;', 'Estimate'),
      th(style = 'text-align: center; color:#002649;', 'Ranking'),
      th(style = 'text-align: center; color:#002649;', 'Category')
    )
  )
))

## Set colors
ts_colors <- RColorBrewer::brewer.pal(7, "Set1")
plotsFontSize <- "13px"
v2xcs_ccsi_color <- ts_colors[1]  #"#AA4643"
v2x_pubcorr_color <- ts_colors[2] #"#BC449E"
v2x_veracc_osp_color <- ts_colors[3] #"#4572A7"
v2x_horacc_osp_color <- ts_colors[4]#"#3D96AE"
v2xcl_rol_color <- ts_colors[5] #"#80699B"
v2x_freexp_altinf_color <- ts_colors[7] #"#89A54E"


# Top N risk plot function ------------------------------------------------
#
#   This is the plot next to the map
#

#use rank data
topNriskFun <- function(dat, region, space, direction){
  canvasClickFunction <- JS("function(event) {Shiny.onInputChange('canvasClicked', [this.name, event.point.category]);}")

  region_text <- case_when(region == 0 ~ "Global",
                           region == 1 ~ "E. Europe and Central Asia",
                           region == 2 ~ "Latin America and the Caribbean",
                           region == 3 ~ "Middle East and N. Africa",
                           region == 4 ~ "Sub-Saharan Africa",
                           region == 5 ~ "W. Europe and N. America*",
                           region == 6 ~ "Asia and Pacific")

  space_text <- case_when(space == "v2xcs_ccsi" ~ "Associational",
                          space == "v2x_pubcorr" ~ "Economic",
                          space == "v2x_veracc_osp" ~ "Electoral",
                          space == "v2x_horacc_osp" ~ "Governing",
                          space == "v2xcl_rol" ~ "Individual",
                          space == "v2x_freexp_altinf" ~ "Informational")

  direction_text <- case_when(direction == "up" ~ "Opening Event",
                              direction == "down" ~ "Closing Event")

  plot_title <- paste0("Top 20 ", direction_text, " Estimates for the ", space_text, " Space")
  plot_subtitle <- paste0(region_text, ", 2021-2022")

  if(direction == "up"){
    dat <- dat %>%
      filter(country_name %in% dat$country_name[seq(1,60,3)]) %>%
      arrange(up_rank, desc(direction)) %>%
      mutate(direction = factor(direction, levels = c("Opening", "Neither", "Closing")))
    names_ <- c("Opening", "Stable", "Closing")
  }
  else{
    dat <- dat %>%
      filter(country_name %in% dat$country_name[seq(1,60,3)]) %>%
      arrange(down_rank, direction) %>%
      mutate(direction = factor(direction, levels = c("Closing", "Neither", "Opening")))
    names_ <- c("Closing", "Stable", "Opening")
  }

  dat %>%
    hchart(type = "bar", hcaes(x = country_name,
                               y = value * 100,
                               group = direction,
                               color = colors), #, pointWidth = 9, pointPadding = 0.1, marginRight = 10
           name = names_)%>% #
    hc_plotOptions(bar = list(grouping = "true")) %>%
    #hc_tooltip(formatter = JS("function(){return false;}"))%>%
    hc_xAxis(title = "",
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold")))%>%
    hc_title(text = plot_title,
             align = "left",
             style = list(color = "#002649",
                          fontSize = "9pt",
                          fontWeight = "bold")) %>%
    hc_subtitle(text = plot_subtitle,
                align = "left",
                style = list(color = "#002649",
                             fontSize = "9pt",
                             fontWeight = "bold")) %>%
    hc_yAxis(min = 0, max = 100,
             title = list(text = "Estimated Probabilities (%)",
                          style = list(color = "#002649",
                                       fontSize = "9pt",
                                       fontWeight = "bold")),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold")),
             opposite = TRUE)%>%
    hc_tooltip(pointFormat = '{point.series.name}  {point.y:.0f}%') %>%
    hc_plotOptions(series = list(events = list(click = canvasClickFunction))) %>%
    hc_legend(enabled = F) %>%
    hc_exporting(enabled = TRUE,
                 buttons = list(contextButton =
                                  list(menuItems = c("downloadPNG", "downloadJPEG", "downloadPDF", "downloadSVG", "downloadCSV"))))
}


# Plot risk for a single country ------------------------------------------
#
#   Bottom left plot
#

#use prob1_dat
riskPlotFun <- function(dat){

  canvasClickFunction1 <- JS("function(event) {Shiny.onInputChange('canvasClicked1', [this.name, event.point.category]);}")
  country_name <- unique(dat$country_name)
  plot_title <- paste0("Estimates by space for ", country_name, ", 2021-2022")

  Plot1 <- dat %>%
    arrange(names) %>%
    mutate(direction = factor(direction, levels = c("Opening", "Neither", "Closing"))) %>%
    hchart(type = "bar", hcaes(x = names,
                               y = 100*value,
                               group = direction,
                               color = colors),
           name = c("Opening", "Stable", "Closing"), pointWidth = 11, pointPadding = 0.1, marginRight = 10)%>%
    # hc_plotOptions(bar = list(stacking = "normal")) %>%
    # hc_plotOptions(bar = list(grouping = "true")) %>%
    hc_xAxis(title = list(text = ""),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold")),
             categories = c("Associational", "Economic", "Electoral", "Governing", "Individual", "Informational"))%>%
    hc_yAxis(min = 0, max = 100, title = list(text = "Estimated probabilities (%)",
                                              style = list(color = "#002649",
                                                           fontSize = "9pt",
                                                           fontWeight = "bold")),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold")))%>%
    hc_title(text = plot_title,
             align = "left",
             style = list(color = "#002649",
                          fontSize = "9pt",
                          fontWeight = "bold")) %>%
    hc_tooltip(pointFormat = '{point.series.name} {point.y:.0f}%') %>%
    hc_plotOptions(series = list(events = list(click = canvasClickFunction1))) %>%
    # hc_add_event_point(event = "click") %>%
    hc_legend(enabled = F) %>%
    hc_exporting(enabled = TRUE,
                 buttons = list(contextButton =
                                  list(menuItems = c("downloadPNG", "downloadJPEG", "downloadPDF", "downloadSVG", "downloadCSV"))))
}

blankRiskPlotFun <- function(){
  blank_dat <- data.frame(outcomes = c("Associational", "Economic", "Electoral", "Governing", "Individual", "Informational"), prob_1 = 0)
  plot_title <- "Estimates by space for [select country], 2021-2022"
  blank_dat%>%
    hchart(type = "bar", hcaes(x = outcomes, y = prob_1), name = "Estimated probabilities (%)", pointPadding = -0.1)%>%
    hc_xAxis(title = list(text = "", style = list(color = "#002649",
                                                  fontSize = "9pt",
                                                  fontWeight = "bold")),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold")),
             categories = list("Associational", "Economic", "Electoral", "Governing", "Individual", "Informational"))%>%
    hc_yAxis(min = 0, max = 100, title = list(text = "Estimated probabilities (%)",
                                              style = list(color = "#002649",
                                                           fontSize = "9pt",
                                                           fontWeight = "bold")),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold"))) %>%
    hc_title(text = plot_title,
             align = "left",
             style = list(color = "#002649",
                          fontSize = "9pt",
                          fontWeight = "bold"))
}


# Plot historic space data for a country ----------------------------------
#
#   Bottom right plot
#

timeSeriesPlotFun <- function(dat, to_plot, CIs = F){
  blank_dat <- data.frame(year = YEAR_RANGE, Value = NA)
  country_name <- unique(dat$country_name)
  plot_title <- paste0("V-Dem index scores for ", country_name)

  PlotHC <- blank_dat%>%
    hchart(type = "line", hcaes(x = year, y = Value), name = "blank")%>%
    hc_yAxis(min = 0, max = 1,
             title = list(text = "",
                          style = list(color = "#002649",
                                       fontSize = "9pt",
                                       fontWeight = "bold")),
             labels = list(
               style = list(color = "#002649",
                            fontSize = "9pt",
                            fontWeight = "bold")))%>%
    hc_xAxis(data = blank_dat$year, tickInterval = 1,
             title = list(text = "",
                          style = list(color = "#002649",
                                       fontSize = "9pt",
                                       fontWeight = "bold")),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold"), rotation = "-45"))%>%
    hc_plotOptions(series = list(marker = list( enabled = FALSE, radius = 1.2, symbol = "circle"), states = list(hover = list (enabled = TRUE, radius = 3))))%>%
    hc_tooltip(shared = TRUE, crosshairs = TRUE) %>%
    hc_title(text = plot_title,
             margin = 20, align = "center",
             style = list(color = "#002649",
                          fontSize = "9pt",
                          fontWeight = "bold")) #%>%
  # hc_exporting(enabled = TRUE,
  #              buttons = list(contextButton =
  #                               list(menuItems = c("downloadPNG", "downloadJPEG", "downloadPDF", "downloadSVG", "downloadCSV"))))

  if("v2xcs_ccsi" %in% to_plot){
    PlotHC <- PlotHC%>%
      hc_add_series(data = dat, type = "line", hcaes(x = year, y = v2xcs_ccsi),
                    name = "<b>Asociational Space </b><br> <span style='font-size: 85%'> Core Civil Society Index", color = v2xcs_ccsi_color, id = "p2")
    if(CIs){
      PlotHC <- PlotHC%>%
        hc_add_series(data = dat, type = "arearange", hcaes(x = year, low = v2xcs_ccsi_codelow, high = v2xcs_ccsi_codehigh),
                      name = "Asociational CI", fillOpacity = 0.15, lineWidth = 0, color = v2xcs_ccsi_color, linkedTo = "p2")
    }
  }
  if(!("v2xcs_ccsi" %in% to_plot)){
    PlotHC <- PlotHC%>%
      hc_rm_series(name = c("<b>Asociational Space </b><br> <span style='font-size: 85%'> Core Civil Society Index", "Asociational CIs"))
  }

  if("v2x_pubcorr" %in% to_plot){
    PlotHC <- PlotHC%>%
      hc_add_series(data = dat, type = "line", hcaes(x = year, y = v2x_pubcorr),
                    name = "<b>Economic Space </b><br> <span style='font-size: 85%'> Public Corruption Index", color = v2x_pubcorr_color, id = "p7")
    if(CIs){
      PlotHC <- PlotHC%>%
        hc_add_series(data = dat, type = "arearange", hcaes(x = year, low = v2x_pubcorr_codelow, high = v2x_pubcorr_codehigh),
                      name = "Economic CI", fillOpacity = 0.15, lineWidth = 0, color = v2x_pubcorr_color, linkedTo = "p7")
    }
  }
  if(!("v2x_pubcorr" %in% to_plot)){
    PlotHC <- PlotHC%>%
      hc_rm_series(name = c("<b>Economic Space </b><br> <span style='font-size: 85%'> Public Corruption Index", "Economic CIs"))
  }

  if("v2x_veracc_osp" %in% to_plot){
    PlotHC <- PlotHC%>%
      hc_add_series(data = dat, type = "line", hcaes(x = year, y = v2x_veracc_osp),
                    name = "<b>Electoral Space </b><br> <span style='font-size: 85%'> Vertical Accountability Index", color = v2x_veracc_osp_color, id = "p8")
    if(CIs){
      PlotHC <- PlotHC%>%
        hc_add_series(data = dat, type = "arearange", hcaes(x = year, low = v2x_veracc_osp_codelow, high = v2x_veracc_osp_codehigh),
                      name = "Electoral CI", fillOpacity = 0.15, lineWidth = 0, color = v2x_veracc_osp_color, linkedTo = "p8")
    }
  }
  if(!("v2x_veracc_osp" %in% to_plot)){
    PlotHC <- PlotHC%>%
      hc_rm_series(name = c("<b>Electoral Space </b><br> <span style='font-size: 85%'> Vertical Accountability Index", "Electoral CIs"))
  }

  if("v2x_horacc_osp" %in% to_plot){
    PlotHC <- PlotHC%>%
      hc_add_series(data = dat, type = "line", hcaes(x = year, y = v2x_horacc_osp),
                    name = "<b>Governing Space </b><br> <span style='font-size: 85%'> Horizontal Accountability Index", color = v2x_horacc_osp_color, id = "p9")
    if(CIs){
      PlotHC <- PlotHC%>%
        hc_add_series(data = dat, type = "arearange", hcaes(x = year, low = v2x_horacc_osp_codelow, high = v2x_horacc_osp_codehigh),
                      name = "Governing CI", fillOpacity = 0.15, lineWidth = 0, color = v2x_horacc_osp_color, linkedTo = "p9")
    }
  }
  if(!("v2x_horacc_osp" %in% to_plot)){
    PlotHC <- PlotHC%>%
      hc_rm_series(name = c("<b>Governing Space </b><br> <span style='font-size: 85%'> Horizontal Accountability Index", "Governing CIs"))
  }

  if("v2xcl_rol" %in% to_plot){
    PlotHC <- PlotHC%>%
      hc_add_series(data = dat, type = "line", hcaes(x = year, y = v2xcl_rol),
                    name = "<b>Individual Space </b><br> <span style='font-size: 85%'> Equality Before the Law &amp; Ind Liberty Index", color = v2xcl_rol_color, id = "p6")
    if(CIs){
      PlotHC <- PlotHC%>%
        hc_add_series(data = dat, type = "arearange", hcaes(x = year, low = v2xcl_rol_codelow, high = v2xcl_rol_codehigh),
                      name = "Individual CI", fillOpacity = 0.15, lineWidth = 0, color = v2xcl_rol_color, linkedTo = "p6")
    }
  }
  if(!("v2xcl_rol" %in% to_plot)){
    PlotHC <- PlotHC%>%
      hc_rm_series(name = c("<b>Individual Space </b><br> <span style='font-size: 85%'> Equality Before the Law &amp; Ind Liberty Index", "Individual CIs"))
  }

  if("v2x_freexp_altinf" %in% to_plot){
    PlotHC <- PlotHC%>%
      hc_add_series(data = dat, type = "line", hcaes(x = year, y = v2x_freexp_altinf),
                    name = "<b>Informatonal Space </b><br> <span style='font-size: 85%'> Freedom of Expression &amp; Alt Info Index", color = v2x_freexp_altinf_color, id = "p4")
    if(CIs){
      PlotHC <- PlotHC%>%
        hc_add_series(data = dat, type = "arearange", hcaes(x = year, low = v2x_freexp_altinf_codelow, high = v2x_freexp_altinf_codehigh),
                      name = "Informatonal CI", fillOpacity = 0.15, lineWidth = 0, color = v2x_freexp_altinf_color, linkedTo = "p4")
    }
  }
  if(!("v2x_freexp_altinf" %in% to_plot)){
    PlotHC <- PlotHC%>%
      hc_rm_series(name = c("<b>Informatonal Space </b><br> <span style='font-size: 85%'> Freedom of Expression &amp; Alt Info Index", "Informatonal CIs"))
  }
  PlotHC
}



blankTimeSeriesFun <- function(){
  blank_dat <- data.frame(year = YEAR_RANGE, Value = NA)
  plot_title <- "V-Dem index scores for [select country]"

  blank_dat%>%
    hchart(type = "line", hcaes(x = year, y = Value), name = "blank")%>%
    hc_yAxis(min = 0, max = 1,
             title = list(text = "",
                          style = list(color = "#002649",
                                       fontSize = "9pt",
                                       fontWeight = "bold")),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold")))%>%
    hc_xAxis(data = blank_dat$year, tickInterval = 1,
             title = list(text = "",
                          style = list(color = "#002649",
                                       fontSize = "9pt",
                                       fontWeight = "bold")),
             labels = list(style = list(color = "#002649",
                                        fontSize = "9pt",
                                        fontWeight = "bold"
             ), rotation = "-45"))%>%
    hc_plotOptions(series = list(marker = list( enabled = FALSE, radius = 1.2, symbol = "circle"), states = list(hover = list (enabled = TRUE, radius = 3))))%>%
    hc_tooltip(shared = TRUE, crosshairs = TRUE) %>%
    hc_title(text = plot_title,
             margin = 20, align = "center",
             style = list(color = "#002649",
                          fontSize = "9pt",
                          fontWeight = "bold"))
}

