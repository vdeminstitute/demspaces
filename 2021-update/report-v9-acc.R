#
#   Scoring the v9 2019-2020 forecasts
#

library(tidyverse)
library(here)
library(demspacesR)
library(yardstick)
library(ggrepel)
library(kableExtra)

states11 <- readRDS(here::here("archive/states-v11.rds"))
truth11 <- states11 %>%
  select(gwcode, year, ends_with("next2")) %>%
  pivot_longer(ends_with("next2"), names_to = "outcome", values_to = "truth") %>%
  mutate(outcome = str_remove(outcome, "_next2")) %>%
  mutate(outcome = str_remove(outcome, "dv_")) %>%
  mutate(direction = ifelse(str_detect(outcome, "down$"), "truth_down", "truth_up")) %>%
  mutate(outcome = str_remove(outcome, "_(up|down)")) %>%
  pivot_wider(names_from = direction, values_from = truth) %>%
  mutate(truth_same = ifelse(truth_up==0 & truth_down==0, 1L, 0L))

fcasts9 <- read_csv(here::here("archive/fcasts-rf-v9.csv"))
fcasts9 <- fcasts9 %>%
  left_join(truth11, by = c("gwcode" = "gwcode", "from_year" = "year",
                            "outcome" = "outcome"))

# Keep only the live forecast, not test forecasts
fcasts9 <- fcasts9 %>%
  filter(from_year==max(from_year))

pr_auc_vec(factor(fcasts9$truth_up, levels = c("1", "0")), fcasts9$p_up)
roc_auc_vec(factor(fcasts9$truth_up, levels = c("1", "0")), fcasts9$p_up)

long <- fcasts9 %>%
  select(outcome, gwcode, p_up, p_down, truth_up, truth_down) %>%
  pivot_longer(c(truth_up, truth_down), values_to = "truth") %>%
  pivot_longer(c(p_up, p_down), values_to = "p", names_to = "direction") %>%
  mutate(name = str_remove(name, "truth_"),
         direction = str_remove(direction, "p_")) %>%
  filter(name==direction) %>%
  select(-name)

data("spaces")
spaces$Description <- NULL
long <- left_join(long, spaces, by = c("outcome" = "Indicator"))

acc <- long %>%
  mutate(truth = factor(truth, levels = c("1", "0"))) %>%
  group_by(Space, direction) %>%
  summarize(Cases = sum(truth=="1"),
            In_top20 = sum(truth=="1" & rank(p) > (n() - 20)),
            `AUC-ROC` = roc_auc_vec(truth, p),
            `AUC-PR`  = pr_auc_vec(truth, p),
            Pos_rate = mean(truth=="1"),
            .groups = "drop")

# Summarize overall performance across spaces/directions
smry <- acc %>%
  select(-Space, -direction) %>%
  summarize_all(mean) %>%
  cbind(Space = "")

# Write table for report
acc %>%
  arrange(direction, Space) %>%
  select(-direction) %>%
  rbind(smry) %>%
  kbl(booktabs = TRUE, format = "latex", digits = c(0, 0, 0, 2, 2, 2),
      label = "v9-acc", caption = "Accuracy of the v9 forecasts for 2019--2020") %>%
  kable_styling() %>%
  pack_rows("Downards movement", 1, 6) %>%
  pack_rows("Upwards movement", 7, 12) %>%
  pack_rows("Average", 13, 13) %>%
  writeLines("output/v9-acc.tex")





long <- fcasts9 %>%
  select(outcome, gwcode, p_up, p_down, truth_up, truth_down) %>%
  pivot_longer(c(truth_up, truth_down), values_to = "truth") %>%
  pivot_longer(c(p_up, p_down), values_to = "p", names_to = "direction") %>%
  mutate(name = str_remove(name, "truth_"),
         direction = str_remove(direction, "p_")) %>%
  filter(name==direction) %>%
  select(-name)



long$country <- states::country_names(long$gwcode, shorten = TRUE)
long$country[long$truth!="1"] <- NA
long <- long %>%
  group_by(outcome, direction) %>%
  arrange(outcome, direction, p) %>%
  mutate(position = 1:n()) %>%
  ungroup()

col <- c(rgb(red = 254, green = 232, blue = 200, max = 255),
         rgb(red = 227, green = 74, blue = 51, max = 255))

ggplot(long, aes(x = position)) +
  facet_grid(Space ~ direction) +
  geom_bar(aes(fill = factor(truth), y = 1), stat = "identity", width = 1) +
  geom_step(aes(y = p)) +
  ggplot2::scale_fill_manual(values = col) +
  ggplot2::scale_y_continuous("Y-hat\n", breaks = c(0, 0.25, 0.5, 0.75, 1.0)) +
  ggplot2::scale_x_continuous("", breaks = NULL, expand = c(0, 0)) +
  ggplot2::theme(legend.position = "none",
                 panel.background = ggplot2::element_blank(),
                 panel.grid = ggplot2::element_blank())

# v9 forecasts i can assess
# use the test forecasts to get an idea of drop due to ground shifting


# Look at year to year decreases for all predictions, maybe the high risk
# forecasts still had relatively high movements


