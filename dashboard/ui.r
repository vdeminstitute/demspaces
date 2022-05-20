navbarPage(
  "The Democratic Space Barometer",


  # TAB: main dashboard ----

  tabPanel(
    "Dashboard",

    # Top row with text ----
    fluidRow(
      column(
        12,
        style = "background-color:#F5F5F5;",
        h1("2022-2023 Forecasts")
      )
    ),

    fluidRow(
      class = "content-row",
      column(
        6,
        # UPDATE: two-year window
        p("The Democratic Space Barometer estimates the probability that a country will experience at least one ", tags$b("opening event"), " (shift towards more democratic governance) or at least one ", tags$b("closing event"), " (shift towards more autocratic governance) within a", tags$b(" two-year window (2022-2023).")),
      ),
      column(
        6,
        ## Adds hoverover popup text for each space
        p("We estimate the probability of opening and closing events across", tags$b("six spaces of democratic governance:")),
        p(
          tags$em(
            tags$b(
              a(id = "AssText", style = "text-decoration: none;", " Associational, "),
              bsPopover(id = "AssText", title = "<b>Civil Society",
                        content = "Measured using the <b>V-Dem&apos;s Core Civil Society Index</b>, which ranges from 0 to 1 and captures CSO autonomy from the state and citizens&apos; ability to freely and actively pursue their political and civic goals, however conceived. It takes into account CSO entry and exit, repression, and participation",
                        options = list(container = "body")),

              a(id = "EcoText", style = "text-decoration: none;", " Economic, "),
              bsPopover(id = "EcoText", title = "<b>Public Corruption",
                        content = "Measured using the <b>V-Dem&apos;s Public Corruption Index</b>, which ranges from 0 to 1 and captures the extent in which public sector employees grant favors in exchange for bribes (or other material inducements), and how often they steal, embezzle, or misappropriate public funds or other state resources for personal or family use.",
                        options = list(container = "body")),

              a(id = "ElecText", style = "text-decoration: none;", " Electoral, "),
              bsPopover(id = "ElecText", title = "<b>Citizens&apos; check on government",
                        content = "Measured using the <b>V-Dem&apos;s Vertical Accountability Index</b>, which ranges from 0 to 1 and captures the ability of the population to hold their government accountable through elections and political parties. It captures election quality, enfranchisement, direct election of chief executive, and opposition party freedoms.",
                        options = list(container = "body")),

              a(id = "GovText", style = "text-decoration: none;", " Governing, "),
              bsPopover(id = "GovText", title = "<b>Government checks and balance",
                        content = "Measured using the <b>V-Dem&apos;s Horizontal Accountability Index</b>, which ranges from 0 to 1 and captures the degree to which the legislative and judicial branches can hold the executive branch accountable as well as legislative and judical oversight over the bureaucracy and security services.",
                        options = list(container = "body")),

              a(id = "IndText", style = "text-decoration: none;", " Individual, "),
              bsPopover(id = "IndText", title = "<b>Individual freedoms",
                        content = "Measured using the <b>V-Dem&apos;s Equality Before the Law and Individual Liberty Index</b>, which ranges from 0 to 1 and captures the extent to which the laws are transparent and rigorously enforced and public administration impartial, and the extent to which citizens enjoy access to justice, secure property rights, freedom from forced labor, freedom of movement, physical integrity rights, and freedom of religion.",
                        options = list(container = "body")))),
          "and ",
          tags$em(
            tags$b(
              a(id = "infoText", style = "text-decoration: none;", "Informational"),
              bsPopover(id = "infoText", title = "<b>Media",
                        content = "Measured using the <b>V-Dem&apos;s Freedom of Expression and Alternative Sources of Information Index</b>, which ranges from 0 to 1 and captures media censorship, harassment of journalists, media bias, media self-censorship, whether the media is critical and pluralistic, as well as the freedom of discussion and academic and cultural expression.",
                        options = list(container = "body"))
            )
          )
        )
      )
    ),

    # Global view (top half of dashboard with map) ----

    fluidRow(
      column(12, style = "background-color:#F5F5F5;",
             h1(tags$span("Global View")))
    ),

    fluidRow(
      column(2,
             radioButtons("direction", h4("Type"),
                          choiceNames = list(tags$span(style = "font-size: 100%; font-weight:bold; color: #F37321; ", "Closing Event"),
                                             tags$span(style = "font-size: 100%; font-weight:bold; color: #0082BA; ", "Opening Event")),
                          choiceValues = c("Closing", "Opening"),
                          selected = "Closing",
                          inline = F)),
      column(3,
             # div(class = "option-group",
             selectInput("space", h4("Space"),
                         choices = c("Associational" = "v2xcs_ccsi",
                                     "Economic" = "v2x_pubcorr",
                                     "Electoral" = "v2x_veracc_osp",
                                     "Governing" = "v2x_horacc_osp",
                                     "Individual" = "v2xcl_rol",
                                     "Informational" = "v2x_freexp_altinf"),
                         selected = "v2xcs_ccsi")),
      column(5,
             selectInput("region", h4("Region"),
                         choices = c("Global" = 0,
                                     "E. Europe and Central Asia" = 1,
                                     "Latin America and the Caribbean" = 2,
                                     "Middle East and N. Africa" = 3,
                                     "Sub-Saharan Africa" = 4,
                                     "W. Europe and N. America*" = 5,
                                     "Asia and Pacific" = 6),
                         selected = 0)
      )
    ),

    hr(),
    fluidRow(
      column(
        12,
        h4(tags$span(style = "font-size: 80%; font-weight:bold;", textOutput("SpaceDescript_name")), tags$span(style = "font-size: 80%;", textOutput("SpaceDescript_text")))
      )
    ),
    fluidRow(
      column(
        6,
        h4(tags$span(style = "font-size: 80%; font-weight:bold;", textOutput("SpaceDescript_vedm")), tags$span(style = "font-size: 80%;", textOutput("SpaceDescript_index")))
      ),
      column(
        5,
        h4(tags$span(style = "font-size: 80%; font-weight:bold;", textOutput("SpaceDescript_thres2")), tags$span(style = "font-size: 80%;", textOutput("SpaceDescript_thres")))
      )
    ),

    hr(),
    fluidRow(
      column(6,
             id = "hcbarplotID",
             highchartOutput("hcbarplot",  width = "100%", height = "550px"),
             p(class = "help", "The bar chart shows all three probabilities for the top 20 countries ordered from highest to lowest according to the type of event and region. Click on a bar for more case-specific information.")
             # ,hr()
      ),
      column(6,
             id = "mapPanel",
             leafletOutput("map1", width = "100%", height = "550px"),
             p(class = "help", "The map focuses on type of event for the specified space. Additional information for each country is available by clicking on the map.")
             # ,hr()
      )
    ),

    # Country view (bottom half of dashboard) ----

    fluidRow(
      column(12, style = "background-color:#F5F5F5;",
             h1(tags$span("Country View")))
    ),

    fluidRow(
      class = "content-row",
      column(12,
             p("Select a country below or from the map above for case-specific information.")
      ),
      column(5,
             selectInput("countrySelect", choices = countryNamesText,
                         label = NULL, selectize = TRUE))
    ),

    fluidRow(
      column(
        5, id = "hcbarplotID1",
        highchartOutput("riskPlot", height = "525px"), br(), br(),
        p(class = "help", "The bar chart shows the estimated risk across all spaces for a country. Click on a bar to view that variable's time trend.")
      ),
      column(
        7, id = "hcbarplotID2",
        highchartOutput("TimeSeriesPlot", height = "520px"), #br(),
        checkboxGroupInput(
          "checkGroup", label = h4(""), inline = T,
          choiceNames = list(
            tags$span("Associational", style = paste("color:", space_colors[["v2xcs_ccsi"]], "; font-weight: bold; font-size:80%;", sep = "")),
            tags$span("Economic", style = paste("color:", space_colors[["v2x_pubcorr"]], "; font-weight: bold; font-size:80%;", sep = "")),
            tags$span("Electoral", style = paste("color:", space_colors[["v2x_veracc_osp"]], "; font-weight: bold; font-size:80%;", sep = "")),
            tags$span("Governing", style = paste("color:", space_colors[["v2x_horacc_osp"]], "; font-weight: bold; font-size:80%;", sep = "")),
            tags$span("Individual", style = paste("color:", space_colors[["v2xcl_rol"]], "; font-weight: bold; font-size:80%;", sep = "")),
            tags$span("Informational", style = paste("color:", space_colors[["v2x_freexp_altinf"]], "; font-weight: bold; font-size:80%;", sep = ""))),
          choiceValues = c("v2xcs_ccsi", "v2x_pubcorr", "v2x_veracc_osp",
                           "v2x_horacc_osp", "v2xcl_rol", "v2x_freexp_altinf")
        ),
        # Toggle to select/deselect all (#13)
        actionButton("tsSelectAll", label = "Select all"),
        # Highlight past opening/closing changes in the time series?
        checkboxInput("tsPlotShowChanges", label = "Highlight past opening/closing events"),
        p(class = "help", "The time-series chart shows a country's scores for the V-Dem indices we use to capture each space.")
      )
    )),

  # TAB: Tables ----

  tabPanel(
    "Tables",
    wellPanel(class = "panel panel-default",
              fluidRow(
                column(12,
                       h2("Data Table"),
                       p("Use the options below to filter the table by spaces, regions, and/or countries. You can select more than one space and region/country. Empty search bars return all of the data. Download the data by clicking on the button below."),

                       p("The columns labeled 'Estimate' report the estimated probability for opening/closing events within a space. The columns labeled 'Ranking' report where a country's specific estimate falls relative to all other countries, 1 (highest) to 169 (lowest). The columns labeled 'Category' break these rankings into five equal categories: Highest, High, Medium, Low, Lowest.")
                )
              ),

              fluidRow(#column(1),
                column(3,
                       selectInput("space2", h4("Space"), multiple = TRUE,
                                   choices = c("Associational",
                                               "Economic",
                                               "Electoral",
                                               "Governing",
                                               "Individual",
                                               "Informational")#,selected = "Associational"
                       )),
                column(4,
                       selectInput("region2", h4("Regions and/or Countries"), multiple = TRUE,
                                   choices = c("Global",
                                               "E. Europe and Central Asia",
                                               "Latin America and the Caribbean",
                                               "Middle East and N. Africa",
                                               "Sub-Saharan Africa",
                                               "W. Europe and N. America*",
                                               "Asia and Pacific", countryNamesText))), #, selected = "Global"
                column(3, h4("Update"), actionButton("update", style = "width: 100%;", label = "Enter"))
              )),

    fluidRow(
      column(1), column(10, DT::dataTableOutput("tableprint"))),
    fluidRow(column(1), column(3, downloadButton("downloadData", "Download Data"))),

    hr()

  ),

  # TAB: About ----

  tabPanel(
    "About",

    div(
      class = "outer",
      tags$head(includeCSS("styles.css")),
      fluidPage(
        id = "MainPage",

        wellPanel(
          class = "panel panel-default",
          fluidRow(
            column(
              12,
              h2("Creators and Background"),
              p("The Democratic Space Barometer is the product of a collaboration between Andreas Beger (Basil Analytics), Laura Maxwell (V-Dem), and Rick Morgan (V-Dem).", br(), br(), "The six conceptual dimensions we focus on come from the International Republican Institute's Closing Space Barometer, which includes an analytical framework for assessing the processes that facilitate a substantial reduction (closing events) within these six spaces. This framework was developed based on a series of workshops conducted with Democracy, Human Rights, and Governance (DRG) donors and implementing partners in 2016 and represent the conceptual features of democratic space which are most amenable to DRG assistance programs.", br(),  br(), "We adapted these conceptual spaces, expanded the scope to include substantial improvements (opening events), and developed an operationalization method to identify opening and closing events within each space. This dashboard, and the forecast that drive it, is the output of these efforts."),

              h2("Resources"),
              p("Data, code, including the dashboard, project reports and other materials can be found on Github at:"),
              p(a(href= "https://github.com/vdeminstitute/demspaces", "https://github.com/vdeminstitute/demspaces")),
              h3("Running the dashboard locally"),
              p("If you are a R user, you can also run the dashboard locally."),
              p("First, check that the dependencies (R packages) listed in", a(href = "https://github.com/vdeminstitute/demspaces/blob/main/dashboard/setup.r", "dashboard/setup.r"), "are installed."),
              p("Then, the following code will download and run the dashboard:"),
              HTML("<pre><code class='language-r'>library(shiny)
runUrl('https://github.com/vdeminstitute/demspaces/raw/main/dashboard/demspaces-dashboard.tar.gz')</code></pre>"),

              h2("Democratic Spaces"),

              # UPDATE: two-year window
              p("The Democratic Space Barometer estimates the probability that a country will experience at least one ", tags$b("opening event"), " (shift towards more democratic governance) or at least one ", tags$b("closing event"), " (shift towards more autocratic governance) within a", tags$b(" two-year window (2022-2023)."), " We estimate the probability of opening and closing events across", tags$b("six spaces of democratic governance:")),

              ## Adds hoverover popup text for each space
              h3("Associational"),
              p(tags$b("Civil Society."), "Measured using the ", tags$b("V-Dem's Core Civil Society Index"), ", which ranges from 0 to 1 and captures CSO autonomy from the state and citizens'; ability to freely and actively pursue their political and civic goals, however conceived. It takes into account CSO entry and exit, repression, and participation"),
              h3("Economic"),
              p(tags$b("Public corruption."), "Measured using the", tags$b("V-Dem's Public Corruption Index"), "which ranges from 0 to 1 and captures the extent in which public sector employees grant favors in exchange for bribes (or other material inducements), and how often they steal, embezzle, or misappropriate public funds or other state resources for personal or family use."),
              h3("Electoral"),
              p(tags$b("Citizens' check on government."), "Measured using the", tags$b("V-Dem's Vertical Accountability Index"), "which ranges from 0 to 1 and captures the ability of the population to hold their government accountable through elections and political parties. It captures election quality, enfranchisement, direct election of chief executive, and opposition party freedoms."),
              h3("Governing"),
              p(tags$b("Government checks and balance."), "Measured using the", tags$b("V-Dem's Horizontal Accountability Index"), "which ranges from 0 to 1 and captures the degree to which the legislative and judicial branches can hold the executive branch accountable as well as legislative and judical oversight over the bureaucracy and security services."),
              h3("Individual"),
              p(tags$b("Individual freedoms."), "Measured using the", tags$b("V-Dem's Equality Before the Law and Individual Liberty Index"), "which ranges from 0 to 1 and captures the extent to which the laws are transparent and rigorously enforced and public administration impartial, and the extent to which citizens enjoy access to justice, secure property rights, freedom from forced labor, freedom of movement, physical integrity rights, and freedom of religion."),
              h3("Informational"),
              p(tags$b("Media."), "Measured using the", tags$b("V-Dem's Freedom of Expression and Alternative Sources of Information Index"), "which ranges from 0 to 1 and captures media censorship, harassment of journalists, media bias, media self-censorship, whether the media is critical and pluralistic, as well as the freedom of discussion and academic and cultural expression."),

              h2("Outcomes and models"),
              p("From year to year, these spaces can", tags$b("open (liberalize)"), "or", tags$b(" close (autocratize)."), "To capture these events, we focus on", tags$b(" year-to-year changes"), " within the V-Dem indices we identify for each space."),
              p("We classify opening (closing) events as year-to-year increases (decreases) in a country's V-Dem index score greater than (less than) or equal to an ", tags$b("empirically defined threshold"), " that is unique for each space", HTML("&ndash;"),

                tags$em(tags$b(a(id = "ThresText", style = "text-decoration: none;", " six thresholds altogether."))),
                bsPopover(id = "ThresText", title = "<b>Opening/Closing event thresholds",
                          content = "<b>Year-to-year changes in <br>select V-Dem index</b><br> Associational: <b>+/- 0.05</b><br> Economic: <b>+/- 0.03</b><br>Electoral: <b>+/- 0.08</b><br>Governing: <b>+/- 0.06</b><br>Individual: <b>+/- 0.04</b><br>Informational: <b>+/- 0.05</b><br><br>The V-Dem indices we use to measure each space are on a continuous scale from 0 (autocratic) to 1 (democratic).",
                          options = list(container = "body"))),

              # UPDATE: from 1970 to ...
              p("We use a set of", tags$b(" 12 random forest classification models")," and a country-year dataset with global coverage (169 countries) from 1970 to 2020 to derive our risk estimates."),

              h2("Interpretation of results"),

              p("Our models estimate two probabilities for each country:"),
              tags$ol(
                tags$li("That there will be at least one, but maybe two,", tags$b("closing"), "events over the next two years"),
                tags$li("That there will be at least one, but maybe two,", tags$b("opening"), "events over the next two years")
              ),
              p("From these two probabilities we also derive the probability:"),
              tags$ol(
                start = "3",
                tags$li("That there will be ", tags$b(" no closing and no opening events"), " over the next two years")
              ),
              p(tags$b("These three probabilities do not sum up to one. The occurrence of a substantial opening event and a substantial closing event over a two-year span are not mutually exclusive events."), "Though rare, a country can experience back-to-back opening and closing events within the same space."),

              p("The estimated probability for \"any opening event within the next two years\" really captures three distinct combinations of events:", tags$b(" one opening and no closing, two opening and no closing, as well as one opening and one closing."), " Similarly for \"any closing event within the next two years\". The probability for \"no change\" on the other hand only captures one scenario: no opening or closing events in the two-year window."),

              p("As a result of these relationships, it is sometimes the case that the forecast models produce relatively large probabilities for both opening and closing events in a country. This can be seen in the visualization tools we present in the 'Figures' tab. One way to think of these instances is that the situation in that country in that space is very fluid, potentially indicating that the country is at a crossroads and prime for intervention. This, of course, requires more case- and space-specific evidence than our models can provide.")
            )
          )
        )
      )
    )
  ) # END: 'TAB: About'
) # END: navbarPage

