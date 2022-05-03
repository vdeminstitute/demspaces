#
#   Prelim. analysis of the CV results for orig and mod (ERT-lite) outcomes
#
#   The first two results sets were 5-fold CV, the third was 10-fold
#

library(ggplot2)
library(dplyr)
library(tidyr)

setwd(here::here("outcome-v2"))

res_files <- dir("output", full.names = TRUE, pattern = "cv-results")
res <- lapply(res_files, readRDS)
names(res) <- res_files
res <- bind_rows(res, .id = "file")
res$chunkfile <- NULL
res$time <- NULL
res$year <- NULL

res %>%
  select(data, outcome, score) %>%
  tidyr::unnest(score) %>%
  group_by(data, outcome, Measure, Direction) %>%
  summarize(value = mean(Value),
            sd = sd(Value),
            n = n()) |>
  arrange(outcome, Direction, Measure, data)

pooled <- res %>%
  select(data, outcome, score) %>%
  tidyr::unnest(score)

pooled %>%
  filter(Measure != "Log-loss") %>%
  ggplot() +
  facet_grid(Measure ~ outcome + Direction, scales = "free_y") +
  geom_boxplot(aes(x = data, y = Value, fill = data), alpha = 0.5) +
  geom_jitter(aes(x = data, y = Value), width = 0.2, height = 0, alpha = 0.25) +
  theme_light()


tbl <- pooled %>%
  filter(Measure != "Log-loss") %>%
  group_by(Measure, data) %>%
  summarize(value = mean(Value)) %>%
  pivot_wider(names_from = "data", values_from = "value")

tbl %>%
  setNames(c("Measure", "Modified", "Original")) %>%
  knitr::kable("latex", digits = 2, booktabs = TRUE)




