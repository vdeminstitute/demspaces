#
#   v9 test forecast accuracy, with v9 data
#

library(tidyverse)
library(here)
library(demspacesR)
library(yardstick)
library(ggrepel)
library(kableExtra)

states9 <- readRDS(here::here("archive/states-v9.rds"))
truth9 <- states9 %>%
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
  left_join(truth9, by = c("gwcode" = "gwcode", "from_year" = "year",
                            "outcome" = "outcome"))

# Keep only the test forecasts with observed outcomes
fcasts9 <- fcasts9 %>%
  filter(complete.cases(.))

pr_auc_vec(factor(fcasts9$truth_up, levels = c("1", "0")), fcasts9$p_up)
roc_auc_vec(factor(fcasts9$truth_up, levels = c("1", "0")), fcasts9$p_up)

long <- fcasts9 %>%
  select(outcome, from_year, gwcode, p_up, p_down, truth_up, truth_down) %>%
  pivot_longer(c(truth_up, truth_down), values_to = "truth") %>%
  pivot_longer(c(p_up, p_down), values_to = "p", names_to = "direction") %>%
  mutate(name = str_remove(name, "truth_"),
         direction = str_remove(direction, "p_")) %>%
  filter(name==direction) %>%
  select(-name)

data("spaces")
spaces$Description <- NULL
long <- left_join(long, spaces, by = c("outcome" = "Indicator"))

acc_by_year <- long %>%
  mutate(truth = factor(truth, levels = c("1", "0"))) %>%
  group_by(Space, direction, from_year) %>%
  summarize(Cases = sum(truth=="1"),
            `Top 20` = sum(truth=="1" & rank(p) > (n() - 20)),
            `AUC-ROC` = roc_auc_vec(truth, p),
            `AUC-PR`  = pr_auc_vec(truth, p),
            `Pos. rate` = mean(truth=="1"),
            .groups = "drop")

# rows with no positive:
acc_by_year %>%
  filter(Cases==0)

acc <- acc_by_year %>%
  filter(Cases!=0) %>%
  group_by(Space, direction) %>%
  summarize(Cases = mean(Cases),
            `Top 20` = mean(`Top 20`),
            `AUC-ROC` = mean(`AUC-ROC`),
            `AUC-PR` = mean(`AUC-PR`),
            `Pos. rate` = mean(`Pos. rate`),
            .groups = "drop")

# Summarize overall performance across spaces/directions
smry <- acc %>%
  select(-Space, -direction) %>%
  summarize_all(mean) %>%
  cbind(Space = "")

# Write table for report
# footnote about 2010 closing electoral no events
acc$Space[acc$Space=="Electoral" & acc$direction=="down"] <- "Electoral\\textsuperscript{*}"
acc %>%
  arrange(direction, Space) %>%
  select(-direction) %>%
  rbind(smry) %>%
  kbl(booktabs = TRUE, format = "latex", digits = c(0, 1, 1, 2, 2, 2),
      escape = FALSE,  # for footnote marker
      label = "v9-test-acc", caption = "Average accuracy of the v9 test forecasts from 2005--2016, scored with v9 V-Dem data") %>%
  kable_styling() %>%
  pack_rows("Closing movement", 1, 6) %>%
  pack_rows("Opening movement", 7, 12) %>%
  pack_rows("Average", 13, 13) %>%
  footnote(general = "All values are averages over performance scores for the 12 distinct test forecasts between 2005--2016.",
           symbol = "There were 0 closing events in 2010; this year is not figured in the average performance calculation.",
           threeparttable = TRUE) %>%
  writeLines(here::here("2021-update/output/v9-test-acc.tex"))

