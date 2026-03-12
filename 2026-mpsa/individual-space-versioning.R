#
#   How is the individual space and it's underlying indicator, v2xcl_rol,
#   looking over V-Dem versions? (Using the ERT-lite flavor.)
#

library(glue)
library(readr)
library(dplyr)
library(tidyr)
library(states)
library(ggplot2)
library(patchwork)

# Just do one of the more recent years, and I want to be able to make statements
# about "looking next year, in 2 years", so we need a 3-version slice of data.


# ert_lite: this is our data for individual space, starting from 2016 and for
# VDem versions 13:15
dv_files <- paste0("2026-mpsa/input/", glue("dv-data_v{v}_ert-lite.rds", v=13:15))
ert_lite <- dv_files |>
  map(\(path) {
    version <- str_extract(path, "v[0-9]{1,2}") |> str_remove("v")

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


# index_data: this is the VDem 13, 14, 15 data on v2xcl_rol (individual space),
# from 2016 onwards.
vdem_files <- glue("create-data/input/V-Dem-CY-Full+Others-v{v}.rds", v = 13:15)
index_data <- vdem_files |>
  map(\(path) {
    version <- str_extract(path, "v[0-9]{1,2}") |> str_remove("v")

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
# when next year's data is avaiable, even if there are no changes due to
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




