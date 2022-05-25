#
#   Create a more human-readable version of the raw forecast data
#

library(here)
library(states)
library(dplyr)
library(readr)
library(demspacesR)

setwd(here::here("archive"))

raw <- read_csv("fcasts-rf-v12.1.csv")

raw <- raw %>% filter(for_years == max(for_years))

raw$Country <- country_names(raw$gwcode, shorten = TRUE)

data("spaces")
spaces <- spaces[, c("Space", "Indicator")]

raw <- left_join(raw, spaces, by = c("outcome" = "Indicator"))

raw <- raw %>%
  arrange(from_year, Space, Country) %>%
  rename(From_Year = from_year, For_Years = for_years) %>%
  select(From_Year, For_Years, Space, Country, p_up, p_same, p_down) %>%
  mutate(p_up = round(p_up, 3), p_same = round(p_same, 3), p_down = round(p_down, 3))

write_csv(raw, "forecasts-v12.1.csv")
