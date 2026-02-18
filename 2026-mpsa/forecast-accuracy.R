#
#   Compare the nominal to actual accuracy of all forecasts
#
#   One complication here is that the first 3 sets of forecasts prior to v12.1
#   used the original conception of the DV, before the ERT-lite changes in v12.1.
#
#   Too much work to address this, so meh.
#
#   Seems that they did use the same cutpoints, so that's good.
#

library(dplyr)
library(readr)
library(stringr)
library(yardstick)


file_path <- function(...) {
  file.path("2026-mpsa", ...)
}


fcasts <- read_csv(file_path("input/fcasts-rf-v9.csv"))

fcasts <- fcasts |>
  dplyr::filter(from_year==max(from_year))

dv <- read_rds(file_path("input/dv-data_v11.1_original.rds"))

dv <- dv |> dplyr::filter(year==unique(fcasts$from_year))
dv <- dv |> select(gwcode, year, ends_with("change"))
dv <- dv |>
  tidyr::pivot_longer(-c(gwcode, year), names_to = "outcome", values_to = "change") |>
  mutate(outcome = str_remove(outcome, "dv_"),
         outcome = str_remove(outcome, "_change"))
dv <- dv |>
  mutate(truth_up = as.integer(change=="up"),
         truth_down = as.integer(change=="down"),
         truth_same = as.integer(change=="same"))

joint <- fcasts |>
  full_join(dv, by = c("gwcode" = "gwcode", "from_year" = "year", "outcome" = "outcome"))

mean(joint$truth_up)
pr_auc_vec(factor(joint$truth_up, levels = c("1", "0")), joint$p_up)
brier_class_vec(factor(joint$truth_up, levels = c("1", "0")), joint$p_up)
brier_class_vec(factor(rep(0, length(joint$truth_up)), levels = c("1", "0")), joint$p_up)

mean(joint$truth_down)
pr_auc_vec(factor(joint$truth_down, levels = c("1", "0")), joint$p_down)
brier_class_vec(factor(joint$truth_down, levels = c("1", "0")), joint$p_down)
brier_class_vec(factor(rep(0, length(joint$truth_down)), levels = c("1", "0")), joint$p_down)

mean(joint$truth_same)
pr_auc_vec(factor(joint$truth_same, levels = c("1", "0")), joint$p_same)
brier_class_vec(factor(joint$truth_same, levels = c("1", "0")), joint$p_same)
brier_class_vec(factor(rep(1, length(joint$truth_same)), levels = c("1", "0")), joint$p_same)

