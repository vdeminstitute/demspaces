#
#   Supporting code for questions about the 2021 update/forecasts; see the memo
#   at DemSpaces2021-Questions.Rmd.
#

library(here)
library(tidyverse)
library(readr)

setwd(here::here("2021-update"))

fcasts09 <- read_csv(here::here("archive/fcasts-rf-v9.csv")) %>%
  mutate(v = "DemSpaces 2019")
fcasts10 <- read_csv(here::here("archive/fcasts-rf-v10.csv")) %>%
  mutate(v = "DemSpaces 2020")
fcasts11 <- read_csv(here::here("archive/fcasts-rf-v11.csv")) %>%
  mutate(v = "DemSpaces 2021")

fcasts <- bind_rows(fcasts09, fcasts10, fcasts11) %>%
  mutate(p_same = NULL) %>%
  pivot_longer(c(p_up, p_down), names_to = "direction", values_to = "p") %>%
  mutate(direction = ifelse(direction=="p_up", "up", "down"))

#' > At a glance, it appears that the highest probabilities for both opening and
#' > closing are significantly higher than the highest probabilities in last
#' > year’s forecasts (60%+ whereas last year I think the highest probabilities
#' > were just over 50%). Does this year’s forecast predict higher probabilities
#' > both on average, and throughout the distribution? In other words is any
#' > difference just at the extremes or were the increased probabilities across
#' > the board? And do you think this reflects an actual underlying increase of
#' > probability of transition in the real world, or is it some artefact of the
#' > data somehow?

# Looking at the distribution of forecasts for the v9, 10, and 11 forecasts,
# yes, it does seem that the maximum values are higher.
last_by_v <- fcasts %>%
  group_by(v) %>%
  filter(from_year==max(from_year)) %>%
  ungroup() %>%
  mutate(facet = "Final forecasts from all versions, years differ")

ggplot(last_by_v, aes(x = factor(v), y = p)) +
  geom_violin() +
  geom_boxplot()

# But maybe the 2021 model is just generally more discriminative
all_2018 <- fcasts %>%
  filter(from_year==2018) %>%
  mutate(facet = "Forecast from all versions for 2019 - 2020") %>%
  mutate(suffix = match(v, unique(v)),
         for_years = paste0(for_years, "_", suffix))
bind_rows(last_by_v, all_2018) %>%
  ggplot(aes(x = for_years, y = p, color = v)) +
  geom_violin() +
  geom_boxplot(width = .1) +
  facet_wrap(~ facet, ncol = 1, scales = "free_x") +
  scale_color_brewer("Version", type = "qual", palette = 6) +
  theme_bw() +
  theme(legend.position = "top") +
  labs(x = "Years covered by forecast", y = "P(Opening or Closing Event)")
ggsave("output/faq/fcast-violin-plots.png", height = 5, width = 5)


# Are the average forecasts, i.e. general level of instability, also higher?
fcasts %>%
  filter(from_year > 2017) %>%
  group_by(from_year, v) %>%
  summarize(max = max(p), mean = mean(p), median = median(p))

fcasts %>%
  ggplot(aes(x = factor(for_years, levels = rev(unique(for_years))), y = p,
             color = v)) +
  coord_flip() +
  facet_wrap( ~ v, nrow = 1) +
  geom_violin() +
  geom_boxplot(width = .1) +
  scale_color_brewer("Version", type = "qual", palette = 6) +
  theme_bw() +
  theme(legend.position = "top") +
  labs(x = "P(Opening or Closing Event)", y = "")
ggsave("output/faq/fcast-violin-plots-by-year.png", height = 8, width = 8)

# Just in case, here it is by direction, too. I don't think this adds that much.
ggplot(fcasts, aes(x = factor(for_years, levels = rev(unique(for_years))), y = p)) +
  coord_flip() +
  facet_grid(direction ~ v) +
  geom_violin() +
  geom_boxplot(width = .5)

# Distill some key info from that mass of violin/box plots above
tbl_stats <- fcasts %>%
  group_by(for_years, v) %>%
  summarize(max = max(p), mean = mean(p), median = median(p))

tbl_stats %>%
  pivot_longer(c(max, mean, median)) %>%
  ggplot(aes(x = for_years, y = value, color = v, group = v)) +
  geom_line() +
  facet_wrap(~ name, ncol = 1, scales = "free_y") +
  scale_color_brewer("Version", type = "qual", palette = 6) +
  labs(x = "Forecast Horizon", y = "Correlation",
       title = "Forecast Summary Statistics by Year and Version") +
  theme_bw() +
  theme(legend.position = "top",
        axis.text.x = element_text(angle = 45, hjust = 1))
ggsave("output/faq/fcast-stats-over-time.png", height = 8, width = 8)


# Correlation between up and down forecasts -------------------------------

# Relatedly, and also at a glance, it looks like in the higher rankings, there are substantial differences between probability of opening and closing in the same country. So the most dramatic example is Ecuador, with a 72% chance of closing, but only a 25% chance of opening. I feel like last year those probabilities tended to be closer together on average, with most countries having similar probabilities for both opening and closing, which we have been interpreting as “high potential volatility.” Do you have any thoughts or hypotheses about why the forecast might appear to be “clearer” on either opening or closing this time around?

# That is correct, the correlation between opening and closing forecasts is
# lower in the 2021 update than it was before.
fcasts %>%
  group_by(v) %>%
  filter(from_year==max(from_year)) %>%
  pivot_wider(names_from = "direction", values_from = "p") %>%
  ggplot(aes(x = up, y = down, color = factor(v))) +
  geom_point(alpha = 0.5) +
  facet_wrap( ~ for_years) +
  geom_abline(slope = 1) +
  scale_color_brewer("Version", type = "qual", palette = 6) +
  labs(x = "Opening Forecast", y = "Closing Forecast",
       title = "DemSpaces Forecasts Since Inception") +
  theme_bw() +
  theme(legend.position = "top")
ggsave("output/faq/correlation-by-version.png", height = 5, width = 8)

# However, this again seems to reflect the model improvement during the 2021
# update
fcasts %>%
  filter(for_years == "2019 - 2020") %>%
  pivot_wider(names_from = "direction", values_from = "p") %>%
  ggplot(aes(x = up, y = down, color = factor(v))) +
  geom_point(alpha = 0.5) +
  facet_wrap( ~ v) +
  geom_abline(slope = 1) +
  scale_color_brewer(guide = "none", type = "qual", palette = 6) +
  labs(x = "Opening Forecast", y = "Closing Forecast",
       title = "Forecasts for 2019 - 2020, from different DemSpaces versions") +
  theme_bw()
ggsave("output/faq/correlation-2019.png", height = 5, width = 8)

fcasts %>%
  filter(for_years > "2010 - 2011") %>%
  pivot_wider(names_from = "direction", values_from = "p") %>%
  ggplot(aes(x = up, y = down)) +
  geom_point() +
  facet_grid(for_years ~ v) +
  scale_x_continuous(limits = c(0, 1)) +
  scale_y_continuous(limits = c(0, 1)) +
  geom_abline(intercept = 0, slope = 1) +
  geom_smooth(method = "lm", se = FALSE, formula = "y ~ x")


tbl <- fcasts %>%
  pivot_wider(names_from = "direction", values_from = "p") %>%
  group_by(for_years, v) %>%
  summarize(cor = cor(up, down)) %>%
  pivot_wider(names_from = "v", values_from = "cor")

tbl %>%
  pivot_longer(starts_with("DemSpaces"), names_to = "v", values_to = "cor") %>%
  ggplot(aes(y = cor, x = for_years, color = factor(v), group = v)) +
  geom_line() +
  geom_point() +
  scale_color_brewer("Version", type = "qual", palette = 6) +
  labs(x = "Forecast Horizon", y = "Correlation",
       title = "Correlation between Opening and Closing Forecasts") +
  theme_bw() +
  theme(legend.position = "top",
        axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_y_continuous(limits = c(0, 1))
ggsave("output/faq/correlation-up-down-over-time.png", height = 5, width = 8)


# Ground truth ------------------------------------------------------------

states9 <- read_rds(here::here("archive/states-v9.rds")) %>%
  mutate(v = "V-Dem 2019") %>%
  select(gwcode, year, ends_with("_change"), v)
states10 <- read_rds(here::here("archive/states-v10.rds")) %>%
  mutate(v = "V-Dem 2020") %>%
  select(gwcode, year, ends_with("_change"), v)
states11 <- read_rds(here::here("archive/states-v11.rds")) %>%
  mutate(v = "V-Dem 2021") %>%
  select(gwcode, year, ends_with("_change"), v)

states <- bind_rows(states9, states10, states11) %>%
  pivot_longer(ends_with("_change"), names_to = "space", values_to = "change") %>%
  mutate(space = str_remove(space, "dv_"),
         space = str_remove(space, "_change"),
         event = as.integer(change %in% c("up", "down")))

states %>%
  group_by(v, year) %>%
  summarize(events = sum(event)) %>%
  ggplot(aes(x = year, y = events, color = v)) +
  geom_line() +
  scale_color_brewer("Data version", type = "qual", palette = 6) +
  labs(x = "Year", y = "Events",
       title = "Totaly Yearly Number of Opening and Closing Events",
       subtitle = "Accross all 6 spaces") +
  theme_bw() +
  theme(legend.position = "top",
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("output/faq/events-over-time.png", height = 5, width = 8)

states %>%
  filter(year >= 2005) %>%
  mutate(event = NULL,
         opening = as.integer(change=="up"), closing = as.integer(change=="down")) %>%
  pivot_longer(c(opening, closing), names_to = "direction", values_to = "event") %>%
  group_by(v, direction, year) %>%
  summarize(events = sum(event)) %>%
  ggplot(aes(x = year, y = events, color = direction)) +
  geom_line() +
  facet_wrap(~v)

states %>%
  filter(year >= 2005) %>%
  mutate(event = NULL,
         opening = as.integer(change=="up"), closing = as.integer(change=="down")) %>%
  group_by(v, year) %>%
  summarize(opening = sum(opening), closing = sum(closing)) %>%
  mutate(open_over_close = opening / closing) %>%
  ggplot(aes(x = year, y = open_over_close, color = v)) +
  geom_line() +
  scale()

scale_color_brewer("Data version", type = "qual", palette = 6) +
  labs(x = "Year", y = "Events",
       title = "Totaly Yearly Number of Opening and Closing Events",
       subtitle = "Accross all 6 spaces") +
  theme_bw() +
  theme(legend.position = "top",
        axis.text.x = element_text(angle = 45, hjust = 1))
