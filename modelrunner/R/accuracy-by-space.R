
library(dplyr)
library(tidyr)
library(readr)
library(demspacesR)
data(spaces)

fcasts <- read_csv(here::here("modelrunner/output/fcasts-rf.csv"))

states <- readRDS(here::here("modelrunner/input/states-v12.rds"))

stats_list <- list()
for (dv in unique(fcasts$outcome)) {
  stats <- score_ds_fcast(fcasts[fcasts$outcome %in% dv, ], states)
  stats <- bind_cols(Indicator = dv, stats)
  stats_list[[dv]] <- stats
}
stats <- do.call(rbind, stats_list)
stats <- bind_cols(Space = spaces$Space[match(stats$Indicator, spaces$Indicator)],
                   stats)

tbl <- stats %>%
  pivot_wider(names_from = "Measure", values_from = "Value")

tbl %>%
  knitr::kable(digits = 3) %>%
  writeLines(here::here("modelrunner/output/accuracy-by-space.md"))

