

# Stuff that needs to be cleaned up and should go somewhere else ----------

space_colors <- as.list(RColorBrewer::brewer.pal(7, "Set1")[-6])
names(space_colors) <- c("v2xcs_ccsi", "v2x_pubcorr", "v2x_veracc_osp",
                         "v2x_horacc_osp", "v2xcl_rol", "v2x_freexp_altinf")
plotsFontSize <- "13px"


#' @param year_range range of years to show
blankTimeSeriesFun <- function(year_range){
  blank_dat <- data.frame(year = year_range, Value = NA)
  plot_title <- "V-Dem index scores for [select country]"

  blank_dat %>%
    highcharter::hchart(type = "line", highcharter::hcaes(x = year, y = Value), name = "blank")%>%
    highcharter::hc_yAxis(min = 0, max = 1,
                          title = list(text = "",
                                       style = list(color = "#002649",
                                                    fontSize = "9pt",
                                                    fontWeight = "bold")),
                          labels = list(style = list(color = "#002649",
                                                     fontSize = "9pt",
                                                     fontWeight = "bold")))%>%
    highcharter::hc_xAxis(
      data = blank_dat$year, tickInterval = 1,
      title = list(text = "",
                   style = list(color = "#002649",
                                fontSize = "9pt",
                                fontWeight = "bold")),
      labels = list(style = list(color = "#002649",
                                 fontSize = "9pt",
                                 fontWeight = "bold"
      ), rotation = "-45"))%>%
    highcharter::hc_plotOptions(series = list(marker = list( enabled = FALSE, radius = 1.2, symbol = "circle"), states = list(hover = list (enabled = TRUE, radius = 3))))%>%
    highcharter::hc_tooltip(shared = TRUE, crosshairs = TRUE) %>%
    highcharter::hc_title(text = plot_title,
                          margin = 20, align = "center",
                          style = list(color = "#002649",
                                       fontSize = "9pt",
                                       fontWeight = "bold"))
}



#' @param changes Highlight past opening/closing events?
#'
timeSeriesPlotFun <- function(dat, to_plot, CIs = FALSE, changes = FALSE,
                              year_range) {
  blank_dat <- data.frame(year = year_range, Value = NA)
  country_name <- unique(dat$country_name)
  plot_title <- paste0("V-Dem index scores for ", country_name)

  PlotHC <- blank_dat %>%
    highcharter::hchart(type = "line", highcharter::hcaes(x = year, y = Value), name = "blank")%>%
    highcharter::hc_yAxis(min = 0, max = 1,
                          title = list(text = "",
                                       style = list(color = "#002649",
                                                    fontSize = "9pt",
                                                    fontWeight = "bold")),
                          labels = list(
                            style = list(color = "#002649",
                                         fontSize = "9pt",
                                         fontWeight = "bold")))%>%
    highcharter::hc_xAxis(data = blank_dat$year, tickInterval = 1,
                          title = list(text = "",
                                       style = list(color = "#002649",
                                                    fontSize = "9pt",
                                                    fontWeight = "bold")),
                          labels = list(style = list(color = "#002649",
                                                     fontSize = "9pt",
                                                     fontWeight = "bold"), rotation = "-45"))%>%
    highcharter::hc_plotOptions(series = list(marker = list( enabled = FALSE, radius = 1.2, symbol = "circle"), states = list(hover = list (enabled = TRUE, radius = 3))))%>%
    highcharter::hc_tooltip(shared = TRUE, crosshairs = TRUE) %>%
    highcharter::hc_title(
      text = plot_title, margin = 20, align = "center",
      style = list(color = "#002649", fontSize = "9pt", fontWeight = "bold")
    ) #%>%

  ind_label <- list(
    v2x_veracc_osp = "Vertical Accountability Index",
    v2xcs_ccsi = "Core Civil Society Index",
    v2xcl_rol = "Equality Before the Law &amp; Ind Liberty Index",
    v2x_freexp_altinf = "Freedom of Expression &amp; Alt Info Index",
    v2x_horacc_osp = "Horizontal Accountability Index",
    v2x_pubcorr = "Public Corruption Index"
  )

  if (length(to_plot) > 0) {
    for (vv in to_plot) {

      id <- paste0("p", match(vv, demspacesR::spaces$Indicator))
      space_name <- demspacesR::spaces$Space[match(vv, demspacesR::spaces$Indicator)]
      series_name <- paste0("<b>", space_name, " Space </b><br> <span style='font-size: 85%'> ", ind_label[[vv]])

      # Space series
      PlotHC <- PlotHC%>%
        highcharter::hc_add_series(
          data = dat, type = "line",
          highcharter::hcaes(x = year, y = !!vv),
          name = series_name, color = space_colors[[vv]], id = id)

      # Check if there were any past observed changes
      if (changes) {
        up_col   <- paste0("y_", vv, "_up")
        up_grp   <- paste0("group_", vv, "_up")
        down_col <- paste0("y_", vv, "_down")
        down_grp <- paste0("group_", vv, "_down")
        PlotHC <- PlotHC %>%
          highcharter::hc_add_series(
            data = dat, type = "line",
            highcharter::hcaes(x = year, y = !!up_col, group = !!up_grp),
            color = space_colors[[vv]], name = "", linkedTo = id,
            lineWidth = 8, showInLegend = FALSE,  enableMouseTracking = FALSE,
            opacity = 0.4)
        PlotHC <- PlotHC %>%
          highcharter::hc_add_series(
            data = dat, type = "line",
            highcharter::hcaes(x = year, y = !!down_col, group = !!down_grp),
            color = space_colors[[vv]], name = "", linkedTo = id,
            lineWidth = 8, showInLegend = FALSE,  enableMouseTracking = FALSE,
            opacity = 0.3)
      }

      if(CIs){
        stop("AB 2022-03-02: I haven't fixed this yet after refactoring the plot code to use a loop")
        PlotHC <- PlotHC %>%
          highcharter::hc_add_series(data = dat, type = "arearange", highcharter::hcaes(x = year, low = v2xcs_ccsi_codelow, high = v2xcs_ccsi_codehigh),
                                     name = "Asociational CI", fillOpacity = 0.15, lineWidth = 0, color = space_colors[[vv]], linkedTo = id)
      }
    }
  }

  PlotHC
}



# END stuff to change -----------------------------------------------------

outcome_explorer_ui <- function() {

  df <- demspaces::spaces_for_app_orig
  countryNamesText <- c("", sort(unique(as.character(df$country_name))))

  shiny::fluidPage(

    # App title ----
    shiny::titlePanel("Democratic Spaces Outcome Explorer"),

    # Sidebar layout with input and output definitions ----
    shiny::sidebarLayout(

      # Sidebar panel for inputs ----
      shiny::sidebarPanel(

        shiny::radioButtons("outcomeVersion", label = "Outcome version",
                            choices = c("Original", "ERT-lite")),

        shiny::selectInput("countrySelect", choices = countryNamesText,
                           label = "Country", selectize = TRUE),

        shiny::checkboxGroupInput(
          "checkGroup", label = "Indicators",
          choiceNames = list(
            shiny::tags$span("Associational", style = paste("color:", space_colors[["v2xcs_ccsi"]], "; font-weight: bold; font-size:80%;", sep = "")),
            shiny::tags$span("Economic", style = paste("color:", space_colors[["v2x_pubcorr"]], "; font-weight: bold; font-size:80%;", sep = "")),
            shiny::tags$span("Electoral", style = paste("color:", space_colors[["v2x_veracc_osp"]], "; font-weight: bold; font-size:80%;", sep = "")),
            shiny::tags$span("Governing", style = paste("color:", space_colors[["v2x_horacc_osp"]], "; font-weight: bold; font-size:80%;", sep = "")),
            shiny::tags$span("Individual", style = paste("color:", space_colors[["v2xcl_rol"]], "; font-weight: bold; font-size:80%;", sep = "")),
            shiny::tags$span("Informational", style = paste("color:", space_colors[["v2x_freexp_altinf"]], "; font-weight: bold; font-size:80%;", sep = ""))),
          choiceValues = c("v2xcs_ccsi", "v2x_pubcorr", "v2x_veracc_osp",
                           "v2x_horacc_osp", "v2xcl_rol", "v2x_freexp_altinf")
        ),
        # Toggle to select/deselect all (#13)
        shiny::actionButton("tsSelectAll", label = "Select all"),
        # Highlight past opening/closing changes in the time series?
        shiny::checkboxInput("tsPlotShowChanges", label = "Highlight past opening/closing events"),

        shiny::sliderInput("yearRange", "Years", step = 1L, sep = "", min = 1990L,
                           max = 2021L, value = c(2011L, 2021L))

      ),

      # Main panel for displaying outputs ----
      shiny::mainPanel(

        # Output: Histogram ----
        highcharter::highchartOutput("TimeSeriesPlot", height = "520px")

      )
    )
  )

}


outcome_explorer_server <- function(input, output, session) {

  # Initialize plot to blank plot
  output$TimeSeriesPlot <-  highcharter::renderHighchart({blankTimeSeriesFun(year_range = input$yearRange)})

  # Initialize data to default original
  dat <- demspaces::spaces_for_app_orig

  shiny::observeEvent(
    c(input$countrySelect, input$checkGroup, input$tsPlotShowChanges,
      input$yearRange, input$outcomeVersion), {

        # Check which data to use
        if (input$outcomeVersion=="Original") {
          dat <- demspaces::spaces_for_app_orig
        } else {
          dat <- demspaces::spaces_for_app_mod
        }

        # Shortcuts
        country_name <- input$countrySelect
        clickedSelected <- input$checkGroup
        #plotCIs <- input$plotCIs

        if(country_name != "") {
          dat_new <- dat[dat$country_name == country_name, ]
          dat_new <- dat_new[dat_new$year >= input$yearRange[1], ]
          output$TimeSeriesPlot <- highcharter::renderHighchart({timeSeriesPlotFun(dat_new, clickedSelected, changes = input$tsPlotShowChanges, year_range = input$yearRange)})
        } else {
          output$TimeSeriesPlot <- highcharter::renderHighchart({blankTimeSeriesFun(year_range = input$yearRange)})
        }
      })

  # "Select all" button for time series plot on bottom right (#13) ----
  # By default, this button should select all time series; however, if all are
  # already selected, un-select all.
  shiny::observeEvent(input$tsSelectAll, {
    checked <- input$checkGroup
    if (length(checked)==6) {
      new_selection <- character(0)
    } else {
      new_selection <- spaces$Indicator
    }
    shiny::updateCheckboxGroupInput(inputId = "checkGroup", selected = new_selection)
  })
  output
}

#' @export
outcome_explorer_app <- function() {
  shiny::shinyApp(outcome_explorer_ui, outcome_explorer_server)
}
