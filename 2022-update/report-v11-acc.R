#
#   Partial scoring of the v11 forecasts
#

# The forecasts to score
fcast_file <- "archive/fcasts-rf-v11.csv"
# The data file from which truth values are taken
truth_file <- "archive/data/states-v12.rds"

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
  filter(year==2021) %>%
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
  mutate(year = 2020)

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
            In_top42 = sum(truth=="1" & rank(p) > (n() - 42)),
            `AUC-ROC` = roc_auc_vec(truth, p),
            `AUC-PR`  = pr_auc_vec(truth, p),
            Pos_rate = mean(truth=="1"),
            .groups = "drop")

# Summarize overall performance across spaces/directions
smry <- acc %>%
  select(-Space, -direction) %>%
  summarize_all(mean) %>%
  cbind(Space = "Average", direction = "")

# Add row with average stats
tbl <- acc %>%
  arrange(direction, Space) %>%
  rbind(smry)

write_csv(tbl, "report-data/acc-v11.csv")


# Separation plots --------------------------------------------------------

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

long$country <- states::country_names(long$gwcode, shorten = TRUE)
long$country[long$truth!="1"] <- NA
long <- long %>%
  group_by(outcome, direction) %>%
  arrange(outcome, direction, p) %>%
  # shuffle tied cases randomly
  mutate(position = rank(p, ties.method = "random")) %>%
  ungroup()

# Regular separation plots

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

# Table-like separation plots

# color match to blue/orange for up/down movements
col <- c("gray95",
         "#0082BA",
         "#F37321")
long$truth <- ifelse(long$truth==1 & long$direction == "down", 2, long$truth)
long$direction <- ifelse(long$direction=="up", "Opening", "Closing")

ggplot(long, aes(x = position)) +
  facet_grid(direction ~ Space) +
  geom_bar(stat = "identity", aes(fill = factor(truth), y = 1), width = 1) +
  coord_flip() +
  geom_step(aes(y = p)) +
  scale_fill_manual(guide = FALSE, values = col) +
  ggplot2::scale_y_continuous(NULL, breaks = NULL, expand = c(0, 0)) +
  ggplot2::scale_x_continuous(NULL, breaks = NULL, expand = c(0, 0)) +
  ggplot2::theme(legend.position = "none",
                 panel.background = ggplot2::element_blank(),
                 panel.grid = ggplot2::element_blank()) +
  theme_minimal() +
  theme(panel.background = element_rect(color = "black"),
        panel.spacing = unit(1, "lines"),
        plot.margin = unit(rep(0.8, 4), "cm"))

ggsave(here::here("2021-update/output/v11-sepplot.png"),
       height = 6, width = 9)

# List all positives ------------------------------------------------------

df <- long %>%
  # add rank
  group_by(outcome, direction) %>%
  arrange(desc(p)) %>%
  mutate(rank = 1:n()) %>%
  ungroup() %>%
  #
  filter(truth > 0) %>%
  group_by(direction, Space) %>%
  arrange(desc(p), country) %>%
  summarize(
    cases = n(),
    text = paste0(country, ", ", rank, ", ", round(p, 2), collapse = "; ")
  )

# construct tex/md text that i can paste into the report
str <- ""
for (d in c("Closing", "Opening")) {
  total <- sum(df$cases[df$direction==d])
  line <- sprintf("### %s\n\n", d)
  str <- c(str, line)
  for (s in sort(unique(df$Space))) {
    text <- df$text[df$direction==d & df$Space==s]
    line <- sprintf("**%s**: %s\n\n", s, text)
    str <- c(str, line)
  }
}

str <- paste0(str, collapse = "")
writeLines(str, here::here("2021-update/output/v11-case-text.md"))
