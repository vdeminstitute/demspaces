#' ----
#' title: "Initial checks for v12 update"
#' author: "Andreas Beger"
#' date: `r Sys.Date()`
#' ----

library(dplyr)
library(here)
library(readr)
library(demspacesR)
library(states)
library(ggplot2)
library(tidyr)

data(spaces)

v11 <- read_csv(here::here("archive/fcasts-rf-v11.csv"))
v12 <- read_csv(here::here("archive/fcasts-rf-v12.csv"))

states12 <- readRDS(here::here("archive/data/states-v12.rds"))

# Where are the closing and opening movements for 2021?
states12 %>%
  filter(year > 2020) %>%
  select(gwcode, year, ends_with("change")) %>%
  pivot_longer(ends_with("change")) %>%
  count(year, name, value) %>%
  pivot_wider(names_from = "value", values_from = "n") %>%
  arrange(name, year)

# Combine the current forecasts with last year's forecast to check
# the overall correlation and look at some new/old cases.
dfa <- v11 %>%
  filter(from_year==max(from_year)) %>%
  rename(p_up_v11 = p_up, p_down_v11 = p_down, p_same_v11 = p_same) %>%
  select(-from_year, -for_years)
dfb <- v12 %>%
  filter(from_year==max(from_year)) %>%
  rename(p_up_v12 = p_up, p_down_v12 = p_down, p_same_v12 = p_same)  %>%
  select(-from_year, -for_years)
fcasts_wide <- full_join(dfa, dfb, by = c("outcome", "gwcode"))

# make a long version of this too, more convenient for some stuff
dfa <- v11 %>%
  filter(from_year==max(from_year)) %>%
  mutate(version = "v11")
dfb <- v12 %>%
  filter(from_year==max(from_year)) %>%
  mutate(version = "v12")
fcasts_long <- bind_rows(dfa, dfb)



fcasts <- fcasts_wide
for (pred in c("p_up", "p_down", "p_same")) {
  cat(pred, "\n")
  v11n <- paste0(pred, "_v11")
  v12n <- paste0(pred, "_v12")
  cat(cor(fcasts[[v11n]], fcasts[[v12n]]), "\n")
  cat(cor(sqrt(fcasts[[v11n]]), sqrt(fcasts[[v12n]])), "\n\n")
}

# What are the biggest changes?
fcasts$down_change <- with(fcasts, p_down_v12 - p_down_v11)
fcasts$up_change <- with(fcasts, p_up_v12 - p_up_v11)
fcasts$Space <- spaces$Space[match(fcasts$outcome, spaces$Indicator)]
fcasts$Country <- states::country_names(fcasts$gwcode, shorten = TRUE)
fcasts <- fcasts %>% select(Country, Space, outcome,
                            p_up_v11, p_up_v12, up_change,
                            p_down_v11, p_down_v12, down_change)

# Danger: increase in risk for downward movement
fcasts %>%
  arrange(desc(down_change)) %>%
  group_by(Space) %>%
  dplyr::slice_head(n = 5) %>%
  select(Country, Space, outcome, p_down_v11, p_down_v12, down_change) %>%
  knitr::kable("simple")

# Resilience: decrease in risk for downward movement
fcasts %>%
  arrange((down_change)) %>%
  group_by(Space) %>%
  dplyr::slice_head(n = 5) %>%
  select(Country, Space, outcome, p_down_v11, p_down_v12, down_change) %>%
  knitr::kable("simple")

# Opportunity: increase in opening possibility
fcasts %>%
  arrange(desc(up_change)) %>%
  group_by(Space) %>%
  dplyr::slice_head(n = 5) %>%
  select(Country, Space, outcome, p_up_v11, p_up_v12, up_change) %>%
  knitr::kable("simple")

# Retrenchment: decrease in opening possibility
fcasts %>%
  arrange(up_change) %>%
  group_by(Space) %>%
  dplyr::slice_head(n = 5) %>%
  select(Country, Space, outcome, p_up_v11, p_up_v12, up_change) %>%
  knitr::kable("simple")

# One problem: this doesn't account for differences in outcome characteristics
# in the difference spaces
ggplot(fcasts_long, aes(x = p_up)) +
  geom_density() +
  facet_wrap(~outcome + version) +
  theme_light()

fcasts_long %>%
  group_by(outcome, version) %>%
  summarize(mean_p_up = mean(p_up),
            mean_p_down = mean(p_down))


# Dig into France Associational down risk

