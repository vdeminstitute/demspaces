#
#   Comparison of the new and last year's forecasts: what has changed?
#

devtools::load_all("demspaces"))
library(dplyr)
library(readr)
library(ggplot2)
library(tidyr)

fcast11 <- read_csv(here::here("archive/fcasts-rf-v11.csv"))
fcast11 <- fcast11[fcast11$from_year==max(fcast11$from_year), ]
fcast11$v <- "11"

fcast12 <- read_csv(here::here("archive/fcasts-rf-v12.csv"))
fcast12 <- fcast12[fcast12$from_year==max(fcast12$from_year), ]
fcast12$v <- "12"

fcast12.1 <- read_csv(here::here("archive/fcasts-rf-v12.1.csv"))
fcast12.1 <- fcast12.1[fcast12.1$from_year==max(fcast12.1$from_year), ]
fcast12.1$v <- "12.1"

fcasts <- rbind(fcast11, fcast12, fcast12.1)

fcasts %>%
  select(-p_same) %>%
  pivot_longer(c(p_up, p_down), names_to = "direction") %>%
  mutate(v = paste0("v", v),
         direction = ifelse(direction=="p_up", "Opening", "Closing")) %>%
  ggplot(aes(x = v, y = value, group = v)) +
  facet_wrap(~direction, scales = "free_x") +
  geom_violin(aes(fill = direction), alpha = 0.8) +
  geom_boxplot(aes(fill = direction), width = 0.2, alpha = 0.4) +
  scale_fill_manual(guide = "none", values = color_direction(c("Opening", "Closing"))) +
  theme_bw() +
  labs(x = "", y = "Pr(Event)")

# Save just the data and re-gen plot in report Rmd
new_forecast_plot <- fcasts %>%
  select(-p_same) %>%
  pivot_longer(c(p_up, p_down), names_to = "direction") %>%
  mutate(v = paste0("v", v),
         direction = ifelse(direction=="p_up", "Opening", "Closing"))
saveRDS(new_forecast_plot, here::here("2022-update/report-data/new-forecast-plot.rds"))

# Table of averages to confirm plot impression
tbl <- fcasts %>%
  select(-p_same) %>%
  pivot_longer(c(p_up, p_down), names_to = "direction") %>%
  group_by(direction, v) %>%
  summarize(mean = mean(value)) %>%
  mutate(v = paste0("v", v)) %>%
  pivot_wider(names_from = "v", values_from = "mean")
tbl

# Table of top 5 forecasts for each space and direction
fcasts_long <- fcast12.1 %>%
  select(outcome, gwcode, p_up, p_down) %>%
  pivot_longer(c(p_up, p_down), names_to = "direction", values_to = "p") %>%
  mutate(direction = ifelse(direction=="p_up", "Opening", "Closing")) %>%
  group_by(outcome, direction) %>%
  arrange(desc(p))

tbl1 <- fcasts_long %>%
  slice_head(n = 5) %>%
  mutate(id = 1:5,
         gwcode = country_names(gwcode, shorten = TRUE),
         outcome = spaces$Space[match(outcome, spaces$Indicator)]) %>%
  pivot_wider(names_from = "direction", values_from = c(gwcode, p)) %>%
  arrange(outcome) %>%
  select(outcome, gwcode_Closing, p_Closing, gwcode_Opening, p_Opening)
tbl1
saveRDS(tbl1, here::here("2022-update/report-data/tbl-topN.rds"))

# Tables of largest changes for each space and direction
delta <- fcasts %>%
  group_by(outcome, gwcode) %>%
  summarize(delta_up = diff(p_up),
            delta_down = diff(p_down))






