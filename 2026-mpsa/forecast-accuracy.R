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
library(purrr)
library(tidyr)
library(ggplot2)
library(tinytable)


file_path <- function(...) {
  file.path("2026-mpsa", ...)
}

fcast_files <- dir(file_path("input"), pattern = "fcasts", full.names = TRUE)
fcasts <- list()
for (ff in fcast_files) {
  ds_version <- str_extract(ff, "v[0-9]{1,2}(.[0-9])?")
  fcasts[[ds_version]] <- read_csv(ff) |>
    dplyr::filter(from_year==max(from_year))

  # The fcasts have this format:
  # A tibble: 5 × 7
  #   outcome           from_year for_years   gwcode   p_up p_same p_down
  #   <chr>                 <dbl> <chr>        <dbl>  <dbl>  <dbl>  <dbl>
  # 1 v2x_freexp_altinf      2019 2020 - 2021      2 0.0207  0.849  0.133
  # 2 v2x_freexp_altinf      2019 2020 - 2021     20 0.0227  0.869  0.111
  # 3 v2x_freexp_altinf      2019 2020 - 2021     40 0.304   0.624  0.102
  # 4 v2x_freexp_altinf      2019 2020 - 2021     41 0.240   0.566  0.255
  # 5 v2x_freexp_altinf      2019 2020 - 2021     42 0.153   0.635  0.25
}

truth_files <- dir(file_path("input"), pattern = "dv-data", full.names = TRUE)
truth <- list()
for (ff in truth_files) {
  vd_version <- str_extract(ff, "v[0-9]{1,2}")
  outcome_version <- ifelse(str_detect(ff, "ert-lite"), "ert-lite", "original")

  dv <- read_rds(ff)

  dv <- dv |> dplyr::filter(year > 2017)
  dv <- dv |> select(gwcode, year, ends_with("change"))
  dv <- dv |>
    tidyr::pivot_longer(-c(gwcode, year), names_to = "outcome", values_to = "change") |>
    mutate(outcome = str_remove(outcome, "dv_"),
           outcome = str_remove(outcome, "_change"))
  dv <- dv |>
    mutate(truth_up = as.integer(change=="up"),
           truth_down = as.integer(change=="down"),
           truth_same = as.integer(change=="same"))

  # This code puts the truth data in a format we can more easily merge with the
  # fcast data, which is long over outcomes, but wide over (up|down|same)
  # A tibble: 5 × 7
  #   gwcode  year outcome           change truth_up truth_down truth_same
  #    <dbl> <dbl> <chr>             <chr>     <int>      <int>      <int>
  # 1      2  2018 v2x_veracc_osp    same          0          0          1
  # 2      2  2018 v2xcs_ccsi        same          0          0          1
  # 3      2  2018 v2xcl_rol         same          0          0          1
  # 4      2  2018 v2x_freexp_altinf same          0          0          1
  # 5      2  2018 v2x_horacc_osp    same          0          0          1

  truth[[vd_version]][[outcome_version]] <- dv
}

ds_version_to_outcome <- function(ds_version) {
  v <- str_remove(ds_version, "v") |> as.numeric()
  ifelse(v < 12.1, "original", "ert-lite")
}

ds_version_to_vd_version <- function(ds_version) {
  ifelse(ds_version=="v12.1", "v12", ds_version)
}

# Create all combinations of fcast and truth data we need. Rule is, ds_version D
# can be assessed with all V-Dem version D+2 and greater.
joint_list <- list()
for (ds_version in names(fcasts)) {
  for (vd_version in names(truth)) {

    # Skip if the V-Dem/truth version is not big enough to cover fcasts
    vd_v <- vd_version |> str_remove("v") |> as.integer()
    ds_v <- ds_version |> str_remove("v") |> as.integer()
    if (vd_v < (ds_v + 2)) {
      next
    }

    cat(glue::glue("DS {ds_version} - VD {vd_version}"), "\n")

    fcast_df <- fcasts[[ds_version]]
    truth_df <- truth[[vd_version]][[ds_version_to_outcome(ds_version)]]

    truth_df <- truth_df |> dplyr::filter(year==unique(fcast_df$from_year))

    joint <- fcast_df |>
      full_join(truth_df, by = c("gwcode" = "gwcode", "from_year" = "year", "outcome" = "outcome"))

    # Add in info on what fcast and truth versions we are comparing
    joint$ds_version <- ds_version
    joint$vd_version <- vd_version

    # data now look like this:
    # A tibble: 5 × 13
    #   outcome           from_year for_years   gwcode    p_up p_same p_down change truth_up truth_down truth_same ds_version vd_version
    #   <chr>                 <dbl> <chr>        <dbl>   <dbl>  <dbl>  <dbl> <chr>     <int>      <int>      <int> <chr>      <chr>
    # 1 v2x_freexp_altinf      2018 2019 - 2020      2 0.0496   0.830 0.127  same          0          0          1 v9         v15
    # 2 v2x_freexp_altinf      2018 2019 - 2020     20 0.00333  0.955 0.0422 same          0          0          1 v9         v15
    # 3 v2x_freexp_altinf      2018 2019 - 2020     40 0.347    0.603 0.0763 same          0          0          1 v9         v15
    # 4 v2x_freexp_altinf      2018 2019 - 2020     41 0.366    0.428 0.325  same          0          0          1 v9         v15
    # 5 v2x_freexp_altinf      2018 2019 - 2020     42 0.118    0.697 0.210  same          0          0          1 v9         v15

    joint_list <- c(joint_list, list(joint))
  }
}




# micro AUC-PR per up/down/same + base rates (positive rates)
calculate_stats <- function(joint) {
  tibble(
    DS = unique(joint$ds_version),
    VD = unique(joint$vd_version),
    direction = c("up", "down", "same"),
    baserate = c(mean(joint$truth_up), mean(joint$truth_down), mean(joint$truth_same)),
    auc_pr = c(pr_auc_vec(factor(joint$truth_up, levels = c("1", "0")), joint$p_up),
               pr_auc_vec(factor(joint$truth_down, levels = c("1", "0")), joint$p_down),
               pr_auc_vec(factor(joint$truth_same, levels = c("1", "0")), joint$p_same)),
    auc_roc = c(roc_auc_vec(factor(joint$truth_up, levels = c("1", "0")), joint$p_up),
                roc_auc_vec(factor(joint$truth_down, levels = c("1", "0")), joint$p_down),
                roc_auc_vec(factor(joint$truth_same, levels = c("1", "0")), joint$p_same))
  )
}

stats_micro <- joint_list |>
  map(calculate_stats) |>
  list_rbind() |>
  mutate(DS = factor(DS, levels = c("v9", "v10", "v11", "v12", "v12.1", "v13")),
         VD = factor(VD, levels = paste0("v", 11:15))) |>
  arrange(DS, direction, VD)

stats_macro_auc_pr <- stats_micro_auc_pr |>
  group_by(DS, VD) |>
  summarize(
    baserate = 0.33,
    auc_pr = mean(auc_pr),
    .groups = "drop"
  )

stats_macro_auc_pr |>
  arrange(DS) |>
  pivot_wider(names_from = "VD", values_from = "auc_pr", names_sort = TRUE)


stats_macro_change_auc_pr <- stats_micro_auc_pr |>
  dplyr::filter(direction!="same") |>
  group_by(DS, VD) |>
  summarize(
    baserate = mean(baserate),
    auc_pr = mean(auc_pr),
    .groups = "drop"
  )

# It's not going down, really. How can I have such a sudden divergence from my
# reports??
# Take a look at the accuracy of the test forecasts, is there a large immediate
# drop?
# Do a separate analysis of how many positive cases in the last 5 years of
# e.g. V9 are still positives in vX???
# Add a sequence of separation plots as well for visual check

stats_macro_change_auc_pr |>
  arrange(DS) |>
  group_by(DS) |>
  mutate(baserate = mean(baserate)) |>
  ungroup() |>
  pivot_wider(names_from = "VD", values_from = "auc_pr", names_sort = TRUE)


micro_auc_pr(joint_list[[1]])




# Get test accuracy


fcast_files <- dir(file_path("input"), pattern = "fcasts", full.names = TRUE)
all_fcasts <- list()
for (ff in fcast_files) {
  ds_version <- str_extract(ff, "v[0-9]{1,2}(.[0-9])?")
  all_fcasts[[ds_version]] <- read_csv(ff)
}

truth_files <- dir(file_path("input"), pattern = "dv-data", full.names = TRUE)
all_truth <- list()
for (ff in truth_files) {
  vd_version <- str_extract(ff, "v[0-9]{1,2}")
  outcome_version <- ifelse(str_detect(ff, "ert-lite"), "ert-lite", "original")

  dv <- read_rds(ff)

  dv <- dv |> select(gwcode, year, ends_with("change"))
  dv <- dv |>
    tidyr::pivot_longer(-c(gwcode, year), names_to = "outcome", values_to = "change") |>
    mutate(outcome = str_remove(outcome, "dv_"),
           outcome = str_remove(outcome, "_change"))
  dv <- dv |>
    mutate(truth_up = as.integer(change=="up"),
           truth_down = as.integer(change=="down"),
           truth_same = as.integer(change=="same"))

  all_truth[[vd_version]][[outcome_version]] <- dv
}


test_accuracy <- list()
for (ds_version in names(all_fcasts)) {

  vd_version <- ds_version_to_vd_version(ds_version)


  # Get the data frames we need for this comparison
  fcast_df <- all_fcasts[[ds_version]]
  truth_df <- all_truth[[vd_version]][[ds_version_to_outcome(ds_version)]]

  joint <- fcast_df |>
    left_join(truth_df, by = c("gwcode" = "gwcode", "from_year" = "year", "outcome" = "outcome"))

  # Filter all tests cases to common subset, driven by v9 coverage: 2005--2018
  joint <- joint |>
    filter(from_year >= 2005, from_year <= 2018)

  # Add in info on what fcast and truth versions we are comparing
  joint$ds_version <- ds_version
  joint$vd_version <- vd_version

  # Calculate accuracy stats
  stats <- calculate_stats(joint)
  stats$test_years <- length(unique(joint$from_year))

  test_accuracy <- c(test_accuracy, list(stats))
}
test_accuracy <- bind_rows(test_accuracy)
test_accuracy <- test_accuracy |>
  mutate(VD = "test") |>
  select(-test_years)


stats_micro_with_test <- stats_micro |>
  bind_rows(test_accuracy) |>
  mutate(DS = factor(DS, levels = c("v9", "v10", "v11", "v12", "v12.1", "v13")),
         VD = factor(VD, levels = c("test", "v9", "v10", "v11", "v12", "v12.1", "v13", "v14", "v15"))) |>
  arrange(DS, direction, VD)

stats_macro_up_down_only <- stats_micro_with_test |>
  filter(direction %in% c("up", "down")) |>
  group_by(DS, VD) |>
  summarize(baserate = mean(baserate),
            auc_pr = mean(auc_pr), auc_roc = mean(auc_roc),
            .groups = "drop")

stats_macro_up_down_only |>
  mutate(test = as.integer(VD=="test"),
         VD = ifelse(VD=="test", ds_version_to_vd_version(as.character(DS)), as.character(VD)),
         VD = factor(VD, levels = c("v9", "v10", "v11", "v12", "v12.1", "v13", "v14", "v15"))
  ) |>
  ggplot(aes(x = VD, y = auc_roc, color = DS, group = DS)) +
  geom_point() +
  geom_line()

# Convert a V-Dem version to relative version, given a DS version, e.g.
# "v14", "v12.1" -> "v+2"
vd_version_relative <- function(vd_version, ds_version) {
  base <- ds_version_to_vd_version(ds_version) |> str_remove("v") |> as.integer()
  int_v <- suppressWarnings(str_remove(vd_version, "v") |> as.integer())
  paste0("v+", int_v - base)
}


stats_macro_up_down_only |>
  mutate(
    x_var = as.character(VD),
    x_var = ifelse(x_var=="test",
                   "Same (test)",
                   vd_version_relative(as.character(VD), as.character(DS))
    )
  ) |>
  ggplot(aes(x = x_var, y = auc_roc, color = DS, group = DS)) +
  geom_point() +
  geom_line() +
  labs(x = "V-Dem version used to score forecasts",
       y = "AUC-ROC",
       color = "Forecast version") +
  scale_y_continuous(limits = c(0.75, 1))

ggsave(filename="2026-mpsa/figures/auc-roc.png")


stats_macro_up_down_only |>
  mutate(
    x_var = as.character(VD),
    x_var = ifelse(x_var=="test",
                   "Same (test)",
                   vd_version_relative(as.character(VD), as.character(DS))
    )
  ) |>
  ggplot() +
  geom_point(aes(x = x_var, y = auc_pr, color = DS, group = DS)) +
  geom_line(aes(x = x_var, y = auc_pr, color = DS, group = DS)) +
  geom_hline(aes(yintercept = baserate)) +
  labs(x = "V-Dem version used to score forecasts",
       y = "AUC-PR",
       color = "Forecast version") +
  scale_y_continuous(limits = c(0, 0.75))

ggsave(filename="2026-mpsa/figures/auc-pr.png")


stats_macro_up_down_only |>
  select(-auc_roc) |>
  # Explicitly convert to character so that we can use "" for NA in pivot_wider
  # tt doesn't have a control for NA values...
  mutate(auc_pr = round(auc_pr, 2) |> as.character()) |>
  pivot_wider(
    id_cols = "DS",
    names_from = "VD",
    values_from = c("auc_pr"),
    values_fill = "",
    unused_fn = \(x) x |> range() |> round(2) |> paste0(collapse = " - ")
  ) |>
  select(DS, baserate, everything()) |>
  tt() |>
  print("typst")


stats_macro_up_down_only |>
  select(-auc_pr) |>
  # Explicitly convert to character so that we can use "" for NA in pivot_wider
  # tt doesn't have a control for NA values...
  mutate(auc_roc = round(auc_roc, 2) |> as.character()) |>
  pivot_wider(
    id_cols = "DS",
    names_from = "VD",
    values_from = c("auc_roc"),
    values_fill = ""
  ) |>
  select(DS, everything()) |>
  tt() |>
  print("typst")


# Confusion matrix-like table of what v9 outcomes look like in v10
v9 <- all_truth[["v9"]][["original"]] |>
  filter(year==max(year)) |>
  select(gwcode, year, outcome, change) |>
  rename(change_v9 = change)
v10 <- all_truth[["v10"]][["original"]] |>
  filter(year %in% unique(v9$year)) |>
  select(gwcode, year, outcome, change) |>
  rename(change_v10 = change)
both <- v9 |> left_join(v10, by = c("gwcode", "year", "outcome"))
tbl <- both |>
  count(change_v9, change_v10) |>
  mutate(change_v9 = factor(change_v9, levels = c("up", "same", "down")),
         change_v10 = factor(change_v10, levels = c("up", "same", "down"))) |>
  arrange(change_v9, change_v10) |>
  pivot_wider(names_from = "change_v10", values_from = "n", values_fill = 0)

tbl |>
  tt() |>
  print("typst")

outcome_v <- "original"
base <- all_truth[["v9"]][[outcome_v]] |>
  filter(year==max(year)) |>
  filter(change!="same") |>
  select(gwcode, year, outcome, change) |>
  mutate(VD="v9")

base$key <- with(base, paste(gwcode, year, outcome, sep = "-"))

for (vd_version in c("v10", "v11", "v12", "v13", "v14", "v15")) {
  df <- all_truth[[vd_version]][[outcome_v]] |>
    filter(year %in% unique(base$year)) |>
    select(gwcode, year, outcome, change) |>
    mutate(VD=vd_version) |>
    mutate(key = paste(gwcode, year, outcome, sep = "-"))
  add <- df |>
    filter(key %in% base$key | change!="same")
  base <- bind_rows(base, add)
}

base <- base |>
  mutate(VD = factor(VD, levels = paste0("v", 9:15))) |>
  arrange(key, VD)





# Of the positive cases (up | down) in v9, what were the sequences of directions
# in subsequent data versions?
v9_seq <- base |>
  group_by(key) |>
  filter(n()==7) |>
  summarize(
    seq = paste(case_when(
      change=="up" ~ "u",
      change=="down" ~ "d",
      change=="same" ~ "s",
      TRUE ~ "?"
    ), collapse = ",")
  )

v9_seq |>
  count(seq) |>
  View()

# Of all positive cases anywhere, what were the sequences of directions?
all_seq <- base |>
  group_by(key) |>
  summarize(
    seq = paste(case_when(
      change=="up" ~ "u",
      change=="down" ~ "d",
      change=="same" ~ "s",
      TRUE ~ "?"
    ), collapse = ",")
  )
