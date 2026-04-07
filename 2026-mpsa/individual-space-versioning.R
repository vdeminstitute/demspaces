#
#   How is the individual space and it's underlying indicator, v2xcl_rol,
#   looking over V-Dem versions? (Using the ERT-lite flavor.)
#

library(glue)
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)
library(states)
library(ggplot2)
library(patchwork)

library(ggridges)
library(plotly)

# Just do one of the more recent years, and I want to be able to make statements
# about "looking next year, in 2 years", so we need a 3-version slice of data.


# ert_lite: this is our data for individual space, starting from 2016 and for
# VDem versions 13:15
dv_files <- paste0("2026-mpsa/input/", glue("dv-data_v{v}_ert-lite.rds", v=13:15))
ert_lite <- dv_files |>
  map(\(path) {
    version <- str_extract(path, "v([0-9]{1,2})", group = 1)
    dv <- read_rds(path)
    dv <- dv |> filter(year > 2015)
    dv$vdem_version <- version

    dv <- dv |> select(gwcode, year, vdem_version, v2xcl_rol, dv_v2xcl_rol_change)
    dv
  }) |>
  list_rbind() |>
  arrange(gwcode, vdem_version)

# Add country names
lookup_country_name <- function(x) {
  sfind(x) |> filter(list=="GW") |> tail(1) |> pull(country_name)
}

ert_lite <- ert_lite |>
  mutate(country_name = sapply(gwcode, lookup_country_name))


# index_data: this is the VDem 9 through 15 data on v2xcl_rol (individual space),
# from 2016 onwards.
v <- c(as.character(9:10), "11.1", as.character(12:15))
vdem_files <- glue("create-data/input/V-Dem-CY-Full+Others-v{v}.rds")
index_data <- vdem_files |>
  map(\(path) {
    version <- str_extract(path, "v([0-9]{1,2})", group = 1)

    vdem <- read_rds(path) |>
      as_tibble()

    vdem <- vdem |>
      filter(year > 2015) |>
      select(COWcode, year, v2xcl_rol)

    vdem <- vdem |>
      mutate(
        gwcode = COWcode,
        gwcode = case_when(gwcode == 255 ~ 260,
                           gwcode == 679 ~ 678,
                           gwcode == 345 & year >= 2006 ~ 340,
                           TRUE ~ gwcode)
      ) |>
      # Some places like Palestine and Hong Kong will drop out
      filter(!is.na(gwcode))

    vdem$vdem_version <- version

    vdem |>
      select(gwcode, year, vdem_version, v2xcl_rol)
  }) |>
  list_rbind() |>
  arrange(gwcode, year, vdem_version)


# Here are the sequences for how the VDem versions code 2021 individual space.
# I am filtering for sequences that have some difference between the V-Dem
# versions.
#
# The reason I'm looking at 2021, and not 2022 (the last year in v13), is because
# actually we have ERT-lite edge effects because it also looks 1-year ahead in
# it's coding. So the 2022 values actually can change because of 2023 data,
# which in v13 is not available yet so some of the cases are miscoded because
# of the ERT-lite coding algorithm.
#
# (The OG ERT has a longer look-ahead period, I changed it to just 1-year for
# ERT-lite, because of this "we coded the wrong value this year" issue. It means
# that some of the 0 codings for ERT-lite in the last year of data will flip
# when next year's data is available, even if there are no changes due to
# versioning.)
#
# So I'm looking at 2021 to avoid spurious changes that are not actually due to
# V-Dem versioning.

ert_lite |>
  filter(year==2021) |>
  group_by(gwcode, country_name, year) |>
  filter(length(unique(dv_v2xcl_rol_change)) > 1) |>
  select(gwcode, country_name, year, vdem_version, dv_v2xcl_rol_change) |>
  arrange(gwcode, country_name, year, vdem_version) |>
  summarize(
    individual_ert_lite_seq = paste(case_when(
      dv_v2xcl_rol_change=="up" ~ "u",
      dv_v2xcl_rol_change=="down" ~ "d",
      dv_v2xcl_rol_change=="same" ~ "s",
      TRUE ~ "?"
    ), collapse = ",")
  ) |> View()


# Make it easier to plot the v2xcl_rol index + the ERT-lite codings for a country
plot_ert_lite_and_index <- function(country_code) {
  x_limits = c(2015.5, 2024.5)

  p1 <- index_data |>
    filter(gwcode==country_code) |>
    ggplot(aes(x = year, y = v2xcl_rol, color = factor(vdem_version))) +
    scale_x_continuous(limits = x_limits, breaks = c(2016:2024)) +
    geom_line()


  p2 <- ert_lite |>
    filter(gwcode==country_code) |>
    mutate(vdem_version = factor(vdem_version, levels = as.character(15:13))) |>
    ggplot(aes(x = year, y = vdem_version, fill = factor(dv_v2xcl_rol_change))) +
    scale_fill_manual(values = c("down" = "red", "up" = "blue", "same" = "gray50")) +
    geom_tile(color = "black") +
    scale_x_continuous(breaks = 2016:2024)

  p1 / p2

}

# India
# Has a change in 2022, but I think's it's spurious and due to the ERT-lite
# lookahead coding. Big level shift from v13 to v14/15 though.
plot_ert_lite_and_index(750) + plot_annotation(title = "India")
ggsave("~/Desktop/individual-india.png")

# Afghanistan
# This is maybe all due to MCMC variation?
plot_ert_lite_and_index(700) + plot_annotation(title = "Afghanistan")
ggsave("~/Desktop/individual-afghanistan.png")

# Poland
# Usual suspect. Maybe some coding changes in 2020, and some MCMC variation
# over 2017 - 2019?
plot_ert_lite_and_index(290) + plot_annotation(title = "Poland")
ggsave("~/Desktop/individual-poland.png")

# Hungary
# Nothing to see, looks like Orban hasn't messed with this aspect
plot_ert_lite_and_index(310) + plot_annotation(title = "Hungary")
ggsave("~/Desktop/individual-hungary.png")

# Russia
# Is the level shift from v13 to the others due to coding changes?
# Also looks like the v14, v15 2019 coding diff is due to MCMC diff.
plot_ert_lite_and_index(365) + plot_annotation(title = "Russia")
ggsave("~/Desktop/individual-russia.png")





# index_variance: this is just the maximum difference between the v2xcl_rol
# coding for 2022 between the 3 v13, 14, 15 VDem versions.
#
# I did this for 2022 because we don't have the edge effects to worry about here.
#
# This is the simplest look possible: just looking at level, not at year 2 year
# diff or anything like that.
#
# Which countries in 2022 had the largest level shift? Lowest?
index_variance <- index_data |>
  filter(year==2022) |>
  group_by(gwcode) |>
  summarize(
    index_range = diff(range(v2xcl_rol)),
    index_var = var(v2xcl_rol),
    index_values = paste0(sprintf("%.2f", v2xcl_rol), collapse = "|")
  ) |>
  arrange(index_range)

# Smallest
head(index_variance)

# Biggest
tail(index_variance)



# El Salvador has the biggest range for 2022
# Big divergence but not so dramatic otherwise
plot_ert_lite_and_index(92) + plot_annotation(title = "El Salvador")

# Mauritania, 2nd bigest
# Huge v13 level shift
plot_ert_lite_and_index(435) + plot_annotation(title = "Mauritania")

# Pakistan, 3rd highest
# Lots of interesting stuff. Looks like the v13, v14 coding diff for 2017, 2018
# is due to MCMC variation, and then coding changes in v14 that explain the
# diff for 2019, 2020?
plot_ert_lite_and_index(770) + plot_annotation(title = "Pakistan")
ggsave("~/Desktop/individual-pakistan.png")

# Germany, low low low
plot_ert_lite_and_index(260) + plot_annotation(title = "Germany")

# RM start ####


# Fixed year, e.g. 2018, v2xcs_rol, if you compare v9 to v10, what is the distribution of differences; v9 to v11, ..., v10 to v11, ... etc.
# How much can I expect the most recent year of data to change next year? Take v9 last year, compare it to v10 same year; take v10 last year, compare it to v11 same year; etc.

index_data_wide <- index_data |>
  pivot_wider(id_cols = c(gwcode, year), names_from = "vdem_version", names_prefix = "v", values_from = "v2xcl_rol") |>
  select(gwcode, year, v9, v10, v11, v12, v13, v14, v15)

# All unique pairs of version columns
version_cols <- paste0("v", 9:15)
pairs <- combn(version_cols, 2, simplify = FALSE)

# Compute pairwise differences and bind as new columns
diff_cols <- pairs |>
  map(\(p) index_data_wide[[p[1]]] - index_data_wide[[p[2]]]) |>         # compute difference for each pair
  set_names(map_chr(pairs, \(p) paste0(p[1], "_minus_", p[2]))) |>  # name "v10_minus_v9"
  as_tibble()
diff_col_names <- names(diff_cols)

index_data_difs <- bind_cols(index_data_wide, diff_cols) |>
  mutate(country_name = map_chr(gwcode, lookup_country_name),
         last_yr_diff = coalesce(!!!syms(diff_col_names))) |>
  select(country_name, gwcode, year, last_yr_diff, all_of(diff_col_names), everything()) |>
  filter(year > 2017) # 2018 is the last reported year in v9

version_last_yr <- index_data_difs |>
  summarise(across(all_of(version_cols), \(x) max(year[!is.na(x)])))

index_data_difs_long <- index_data_difs  |>
  select(country_name, gwcode, year, last_yr_diff, all_of(diff_col_names)) |>
  pivot_longer(cols = -c(country_name, gwcode, year), names_to = "version_diff") |>
  filter(!is.na(value))

# Let's just look at v9 relative to others for 2018

compare_versions_boxplot <- function(dat, ref_version = "v9", version_last_yr, interactive = F){
  use_version_last_yr <- as.numeric(version_last_yr[ref_version]) # this is made above. sloppy but ehh

  title_text <- "Comparing country-year coding of v2xcl_rol across versions"
  subtitle_text <- paste0("Year: ", use_version_last_yr, " | Reference version: ", ref_version)

  use_dat <- dat |>
    filter(str_detect(version_diff, paste0(ref_version, "_")),
           year == use_version_last_yr)


  if (!interactive) {
    return(
      use_dat |>
        ggplot(aes(x = version_diff, y = value, fill = version_diff)) +
        geom_boxplot(alpha = 0.7, show.legend = FALSE) +
        labs(x = NULL, y = "Difference") +
        plot_annotation(title = title_text,
                        subtitle = subtitle_text) +
        theme_minimal()
    )
  }

  plot_ly(use_dat,
          x = ~version_diff,
          y = ~value,
          color = ~version_diff,
          type = "box",
          boxpoints = "suspectedoutliers",
          text = ~country_name,
          showlegend = FALSE) |>
    layout(
      title = list(
        text = paste0("<b>", title_text, "</b><br><sup>", subtitle_text, "</sup>"),
        x = 0
      ),
      xaxis = list(title = ""),
      yaxis = list(title = "Difference")
    )
}

use_version <- version_cols[1]
compare_versions_boxplot(dat = index_data_difs_long, ref_version = use_version, version_last_yr, interactive = T)

plot_ert_lite_and_index(770) + plot_annotation(title = "Pakistan")
plot_ert_lite_and_index(517) + plot_annotation(title = "Rwanda")
plot_ert_lite_and_index(92) + plot_annotation(title = "El Salvador")
plot_ert_lite_and_index(435) + plot_annotation(title = "Mauritania")
plot_ert_lite_and_index(750) + plot_annotation(title = "India")
plot_ert_lite_and_index(581) + plot_annotation(title = "Comoros")

# Comparing change in how the last year of the data is coded in the following version
# ie last year in v9 is 2018, so how much different are the v10's 2018 scores from v9
use_versions <- c("last_yr_diff", "v9_minus_v10", "v10_minus_v11", "v11_minus_v12",
                  "v12_minus_v13", "v13_minus_v14", "v14_minus_v15")
version_last_yr_n <- as.numeric(version_last_yr)

use_dat <- index_data_difs_long |>
  filter(version_diff %in% use_versions) |>
  mutate(keep = case_when(str_detect(version_diff, "v9_") & year == version_last_yr_n[1] ~ 1,
                          str_detect(version_diff, "v10_") & year == version_last_yr_n[2] ~ 1,
                          str_detect(version_diff, "v11_") & year == version_last_yr_n[3] ~ 1,
                          str_detect(version_diff, "v12_") & year == version_last_yr_n[4] ~ 1,
                          str_detect(version_diff, "v13_") & year == version_last_yr_n[5] ~ 1,
                          str_detect(version_diff, "v14_") & year == version_last_yr_n[6] ~ 1,
                          str_detect(version_diff, "v15_") & year == version_last_yr_n[7] ~ 1,
                          version_diff == "last_yr_diff" ~ 1,
                          TRUE ~ 0),
         version_diff = factor(version_diff, levels = use_versions)) |>
  filter(keep == 1)

use_dat |>
  ggplot(aes(x = version_diff, y = value, fill = version_diff)) +
  geom_boxplot(alpha = 0.7, show.legend = FALSE) +
  labs(x = NULL, y = "Difference") +
  plot_annotation(title = "Comparing how v2xcl_rol was coded in last year of  each version to how that year was coded in the next version") +
  theme_minimal()

use_dat |>
  ggplot(aes(x = value)) +
  geom_histogram(bins = 1000) +
  labs(x = NULL, y = "Difference") +
  plot_annotation(title = "Comparing how v2xcl_rol was coded in last year of  each version to how that year was coded in the next version") +
  facet_wrap(~version_diff) +
  theme_minimal()


plot_ly(use_dat,
        x = ~version_diff,
        y = ~value,
        color = ~version_diff,
        type = "box",
        boxpoints = "suspectedoutliers",
        text = ~country_name,
        showlegend = FALSE) |>
  layout(
    title = list(
      text = "Comparing how v2xcl_rol was coded in last year of  each version to how that year was coded in the next version",
      x = 0
    ),
    xaxis = list(title = ""),
    yaxis = list(title = "Difference")
  )
