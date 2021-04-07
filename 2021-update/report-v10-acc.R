#
#   Scoring the v10 2020-2021 forecasts
#

# The forecasts to score
fcast_file <- "archive/fcasts-rf-v10.csv"
# The data file from which truth values are taken
truth_file <- "archive/states-v11.rds"
# Caption for the report table
table_caption <- "Partial accuracy of the v10 forecasts for 2020--2021 with outcomes for 2020 outcomes"

library(tidyverse)
library(here)
library(demspacesR)
library(yardstick)
library(ggrepel)
library(kableExtra)

states <- readRDS(here::here(truth_file))
# The _next2 dv indicators are missing for the last 2 years in the data since
# one or both years are not observed yet. I have to manually construct the
# partial outcome indicator using the "dv_..._change" indicators, which are not
# lead variables.
# truth <- states %>%
#   select(gwcode, year, ends_with("next2")) %>%
#   pivot_longer(ends_with("next2"), names_to = "outcome", values_to = "truth") %>%
#   mutate(outcome = str_remove(outcome, "_next2")) %>%
#   mutate(outcome = str_remove(outcome, "dv_")) %>%
#   mutate(direction = ifelse(str_detect(outcome, "down$"), "truth_down", "truth_up")) %>%
#   mutate(outcome = str_remove(outcome, "_(up|down)")) %>%
#   pivot_wider(names_from = direction, values_from = truth) %>%
#   mutate(truth_same = ifelse(truth_up==0 & truth_down==0, 1L, 0L))
#
# Instead of trying to compare year to year and shift stuff, i can just take
# the 2020 year data, code outcomes based on whether _change was "up" or
# "down", and then hard set the year to 2019 to get the lead version i need.
#
# The data I need should look like:
#
#   gwcode  year outcome           truth_up truth_down truth_same
#    <dbl> <dbl> <chr>                <int>      <int>      <int>
# 1      2  1970 v2x_veracc_osp           0          0          1
# 2      2  1970 v2xcs_ccsi               0          0          1
# 3      2  1970 v2xcl_rol                0          0          1
#
# where each of the "truth_" variables is actually a 2-year lead indicator.
truth <- states %>%
  filter(year==2020) %>%
  select(gwcode, year, ends_with("_change")) %>%
  pivot_longer(ends_with("change"), names_to = "outcome", values_to = "truth") %>%
  mutate(outcome = str_remove(outcome, "_change")) %>%
  mutate(outcome = str_remove(outcome, "dv_")) %>%
  mutate(
    # format truth so that it matches the "truth_up", ... column names we want
    truth = paste0("truth_", truth),
    # dummy value column, need to add 0's for missing after we make wider
    value = 1) %>%
  # wider and fill in 0's
  pivot_wider(names_from = "truth", values_from = "value", values_fill = 0) %>%
  mutate(year = 2019)
# spot check; truth should be 1 only for "up" + year==2020 in states
states %>%
  filter(dv_v2x_veracc_osp_change=="up", year==2020) %>%
  select(gwcode, year, dv_v2x_veracc_osp_change)
# only 2 cases, 436 and 553
truth %>%
  filter(outcome=="v2x_veracc_osp", truth_up==1)
# ok, only those same 2 cases
sum(truth$truth_up[truth$outcome=="v2x_veracc_osp"]==1)
# and, there are only 2 positives for this outcome, i.e. no others
# checks out
#
# back to regular programming ******

fcasts <- read_csv(here::here(fcast_file))
fcasts <- fcasts %>%
  left_join(truth, by = c("gwcode" = "gwcode", "from_year" = "year",
                            "outcome" = "outcome"))

# Keep only the live forecast, not test forecasts
fcasts <- fcasts %>%
  filter(from_year==max(from_year))

pr_auc_vec(factor(fcasts$truth_up, levels = c("1", "0")), fcasts$p_up)
roc_auc_vec(factor(fcasts$truth_up, levels = c("1", "0")), fcasts$p_up)

long <- fcasts %>%
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
      label = "v10-acc", caption = table_caption) %>%
  kable_styling() %>%
  pack_rows("Downards movement", 1, 6) %>%
  pack_rows("Upwards movement", 7, 12) %>%
  pack_rows("Average", 13, 13) %>%
  writeLines("output/v10-acc.tex")




long <- fcasts %>%
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


