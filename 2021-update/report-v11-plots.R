#
#   Tables and plots of the current forecasts for the report
#

fcast_file <- "archive/fcasts-rf-v11.csv"

library(tidyverse)
library(here)
library(demspacesR)
library(states)
library(kableExtra)
library(cowplot)

data("spaces")
spaces$Description <- NULL

fcasts <- read_csv(here::here(fcast_file))
fcasts <- fcasts[fcasts$from_year==max(fcasts$from_year), ]
fcasts$Country <- country_names(fcasts$gwcode, shorten = TRUE)
fcasts <- fcasts[, c("gwcode", "Country", "p_up", "p_same", "p_down", "outcome")]

# add forecast ranks for each outcome
fcasts <- fcasts %>%
  group_by(outcome) %>%
  mutate(rank_up = n() - rank(p_up, ties.method = "min") + 1,
         rank_down = n() - rank(p_down, ties.method = "min") + 1) %>%
  select(Country, rank_down, rank_up, p_down, p_up, p_same, outcome) %>%
  ungroup()

for (i in 1:nrow(spaces)) {

  ind_i <- spaces$Indicator[i]
  space_i <- spaces$Space[i]

  cat(tolower(space_i), "\n")

  fn <- sprintf("2021-update/output/fcast-%s.tex", tolower(space_i))

  tbl <- fcasts %>%
    filter(outcome==ind_i) %>%
    select(-outcome) %>%
    arrange(desc(p_down))

  tbl %>%
    `colnames<-`(c("Country", "Down", "Up", "Down", "Up", "Same")) %>%
    kbl(format = "latex", booktabs = TRUE, digits = c(0, 0, 0, 2, 2, 2),
        longtable = TRUE) %>%
    kable_styling() %>%
    add_header_above(c(" ", "Rank" = 2, "Probability" = 3)) %>%
    writeLines(here::here(fn))

  # for plotting i need tied ranks to be resolved into distinct numbers;

  N <- 30
  # margins for each of the 2 sub-plots
  spmar <- c(0.8, 0.5, 0.5, 0.5)
  col <- list(open = "#0082BA", close = "#F37321")  # "#F3732195"

  #
  #   Plot for P(up)
  #

  p <- tbl %>%
    arrange(desc(p_up)) %>%
    head(N) %>%
    ggplot(aes(x = reorder(Country, p_up), y = p_up)) +
    geom_bar(stat = "identity", width = 0.8, fill = col$open, color = col$open) +
    coord_flip() +
    geom_text(aes(label = Country), hjust = 0, nudge_y = 0.01) +
    scale_y_continuous("Estimated probability of opening",
                       limits = c(0, 1.02), expand = c(0, 0), position = "right",
                       breaks = seq(0, 1, by = 0.2)) +
    scale_x_discrete(NULL, labels = N:1) +
    theme_minimal() +
    theme(panel.grid.major.y = element_blank(),
          panel.grid.minor.y = element_blank(),
          panel.grid.minor.x = element_blank(),
          axis.title.x = element_text(hjust = 0, face = "bold"),
          plot.margin = unit(spmar, "cm"))

  inset <- tbl %>%
    ggplot(aes(x = reorder(Country, p_up), y = p_up)) +
    geom_bar(stat = "identity", width = 1) +
    coord_flip() +
    theme_minimal() +
    theme(panel.background = element_rect(color = "black"),
          panel.grid = element_blank()) +
    scale_x_discrete(NULL, labels = NULL, breaks = NULL) +
    scale_y_continuous(NULL, labels = NULL, limits = c(0, 1), expand = c(0, 0)) +
    annotate("rect", xmin = 169-N, xmax = 169, ymin = 0, ymax = 1,
             fill = NA, col = "red", size = 0.5)

  pup <- ggdraw(p) +
    draw_plot(inset, 0.71, 0.03, 0.25, 0.3)

  #
  #   Plot for P(down)
  #

  p <- tbl %>%
    arrange(desc(p_down)) %>%
    head(N) %>%
    ggplot(aes(x = reorder(Country, p_down), y = p_down)) +
    geom_bar(stat = "identity", width = 0.8, fill = col$close, color = col$close) +
    coord_flip() +
    geom_text(aes(label = Country), hjust = 0, nudge_y = 0.01) +
    scale_y_continuous("Estimated probability of closing",
                       limits = c(0, 1.02), expand = c(0, 0), position = "right",
                       breaks = seq(0, 1, by = 0.2)) +
    scale_x_discrete(NULL, labels = N:1) +
    theme_minimal() +
    theme(panel.grid.major.y = element_blank(),
          panel.grid.minor.y = element_blank(),
          panel.grid.minor.x = element_blank(),
          axis.title.x = element_text(hjust = 0, face = "bold"),
          plot.margin = unit(spmar, "cm"))

  inset <- tbl %>%
    ggplot(aes(x = reorder(Country, p_down), y = p_down)) +
    geom_bar(stat = "identity", width = 1) +
    coord_flip() +
    theme_minimal() +
    theme(panel.background = element_rect(color = "black"),
          panel.grid = element_blank()) +
    scale_x_discrete(NULL, labels = NULL, breaks = NULL) +
    scale_y_continuous(NULL, labels = NULL, limits = c(0, 1), expand = c(0, 0)) +
    annotate("rect", xmin = 169-N, xmax = 169, ymin = 0, ymax = 1,
             fill = NA, col = "red", size = 0.5)

  pdown <- ggdraw(p) +
    draw_plot(inset, 0.71, 0.03, 0.25, 0.3)

  plot_grid(pdown, pup) +
    draw_label(
      sprintf("Top %s forecasts for the %s space", N, space_i),
      fontface = 'italic',
      x = 0,
      y = 1,
      hjust = 0,
      size = 20
    ) +
    theme(
      # add margin on the left of the drawing canvas,
      # so title is aligned with left edge of first plot
      plot.margin = margin(20, 0, 0, 10)
    )
  fn <- sprintf("2021-update/output/topN-%s.png", tolower(space_i))
  ggsave(filename = here::here(fn), height = 7, width = 7*1.5)

}



# Correlation between opening/closing fcasts ------------------------------

cor(fcasts$p_down, fcasts$p_up)

gg <- fcasts$outcome
ss <- split(fcasts, gg)
ss <- lapply(ss, function(x) cor(x$p_down, x$p_up))
unlist(ss)

