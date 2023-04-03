#
#   Create data for the outcome explorer app
#
#   This script creates two datasets:
#
#     - spaces_for_app_orig: the indicators for the 6 spaces as well as marked
#       opening and closing events, using the original definition of opening
#       and closing events (a large change from the previous year).
#     - spaces_for_app_mod: the same data, but using the modified outcome
#       definitions that allow for 2-year changes as well (ERT-lite).
#
#   Note that the format is identical to the "time_series_dat" data frame that
#   is used in the DemSpaces dashboard app for the lower right time series
#   plot, except that the data extend further back in history.
#

library(dplyr)
library(readr)
library(tidyr)
library(demspaces)
library(yaml)

oldwd <- getwd()
setwd(here::here("demspaces"))

# needed for changes_one_country()
devtools::load_all()

dvs <- readRDS(here::here("create-data/output/dv_data_1958_on.rds"))

cutpoints <- read_csv(here::here("create-data/output/cutpoints.csv"))
cp <- cutpoints[["up"]]
names(cp) <- cutpoints[["indicator"]]

data(spaces)


# This function does all the neccessary data transformations, the only diff
# being the type argument to changes_one_country()
construct_app_data <- function(outcome_type) {

  # I need to rebuild updown since I'm now also changing the upstream version (dv-data.rds)
  updown <- dvs[, c("gwcode", "year", spaces$Indicator)]
  updown <- updown %>% dplyr::filter(!is.na(gwcode))
  for (ind in spaces$Indicator) {
    cpi <- cp[[ind]]
    new_col <- sprintf("dv_%s_change", ind)
    updown <- updown %>%
      dplyr::group_by(gwcode) %>%
      dplyr::arrange(gwcode, year) %>%
      dplyr::mutate(temp = changes_one_country(.data[[ind]], !!cpi, type = !!outcome_type))
    updown[[new_col]] <- updown$temp
  }
  updown$temp <- NULL
  updown[, spaces$Indicator] <- NULL

  # for the stuff below, we can't have NAs; set these to "same"
  for (var in setdiff(colnames(updown), c("gwcode", "year"))) {
    updown[[var]][is.na(updown[[var]])] <- "same"
  }

  changes <- updown %>%
    dplyr::filter(year >= min(dvs$year)) %>%
    tidyr::pivot_longer(ends_with("change"), names_to = "space", values_to = "direction") %>%
    dplyr::filter(!direction %in% c("same", "first year of independence"))
  # For the line plots, this only gives us the ending x-coordinate. To deal with
  # that I will add the preceding year (the starting x coordinate) in a second.
  # But there is one edge case that needs to be dealth with first, to distinguish
  # consecutive up/down changes from up/down changes separated by exactly 1 year.
  # Add a group id for that, so that the line plot can tell those two cases apart
  changes <- changes %>%
    group_by(gwcode, space, direction) %>%
    arrange(year) %>%
    mutate(group = states::id_date_sequence(year, "year")) %>%
    ungroup()

  # This now has the year of any up/down changes; i need the preceding year too,
  # which we can easily get via rbind
  temp <- changes
  temp$year <- temp$year - 1
  changes <- bind_rows(changes, temp) %>%
    arrange(gwcode, year, space)

  # This now has duplicates for consecutive events, take those out
  changes <- changes |>
    group_by(gwcode, year, space, direction, group) |>
    summarize(.groups = "drop")

  # extract just the indicator name from the current "space" column
  changes$space <- gsub("dv_", "", changes$space)
  changes$space <- gsub("_change", "", changes$space)

  # to get y-values, we need a long version of dvs we can merge into this
  dvs_long <- dvs %>%
    select(gwcode, year, starts_with("v2x")) %>%
    pivot_longer(-c(gwcode, year), names_to = "space", values_to = "y")
  changes <- left_join(changes, dvs_long, by = c("gwcode", "year", "space"))

  # now we need to turn this into a wide version that we can drop into
  # time_series_dat down the road
  changes <- tidyr::unite(changes, "change", c(space, direction))
  changes <- changes %>%
    arrange(change) %>%
    pivot_wider(names_from = "change", values_from = c(group, y)) %>%
    arrange(gwcode, year)

  time_series_dat <- dvs %>%
    dplyr::select(gwcode, year, country_name,
                  v2x_veracc_osp, v2xcs_ccsi, v2xcl_rol, v2x_freexp_altinf,
                  v2x_horacc_osp, v2x_pubcorr)

  time_series_dat <- left_join(time_series_dat, changes, by = c("gwcode", "year"))
  # Change
  cn <- colnames(time_series_dat)
  cn <- cn[grepl("^group_", cn)]
  for (cc in cn) {
    time_series_dat[[cc]] <- as.integer(time_series_dat[[cc]])
  }

  time_series_dat
}



# Original version --------------------------------------------------------

spaces_for_app_orig <- construct_app_data("orig")
save(spaces_for_app_orig,
     file = here::here("demspaces/data/spaces_for_app_orig.rda"))

# record some data summary stats
cn <- colnames(spaces_for_app_orig)
cn <- cn[grepl("^y_", cn)]
s <- lapply(spaces_for_app_orig[, cn], \(x) sum(!is.na(x)))
stats <- list(
  data = "spaces_for_app_orig",
  year_start = min(spaces_for_app_orig$year),
  year_end = max(spaces_for_app_orig$year),
  # this is not the same as positive cases, since each case has two data points
  points = s
)
write_yaml(stats, "data-raw/trackers/spaces_for_app_orig.yml")

# 2-year version ----------------------------------------------------------

spaces_for_app_2year <- construct_app_data("2year")
save(spaces_for_app_2year,
     file = here::here("demspaces/data/spaces_for_app_2year.rda"))

# record some data summary stats
cn <- colnames(spaces_for_app_2year)
cn <- cn[grepl("^y_", cn)]
s <- lapply(spaces_for_app_2year[, cn], \(x) sum(!is.na(x)))
stats <- list(
  data = "spaces_for_app_2year",
  year_start = min(spaces_for_app_2year$year),
  year_end = max(spaces_for_app_2year$year),
  # this is not the same as positive cases, since each case has two data points
  points = s
)
write_yaml(stats, "data-raw/trackers/spaces_for_app_2year.yml")


# ERT-lite version --------------------------------------------------------


spaces_for_app_mod <- construct_app_data("mod")
save(spaces_for_app_mod,
     file = here::here("demspaces/data/spaces_for_app_mod.rda"))

# record some data summary stats
cn <- colnames(spaces_for_app_mod)
cn <- cn[grepl("^y_", cn)]
s <- lapply(spaces_for_app_mod[, cn], \(x) sum(!is.na(x)))
stats <- list(
  data = "spaces_for_app_mod",
  year_start = min(spaces_for_app_mod$year),
  year_end = max(spaces_for_app_mod$year),
  # this is not the same as positive cases, since each case has two data points
  points = s
)
write_yaml(stats, "data-raw/trackers/spaces_for_app_mod.yml")


# END
# reset old working directory
setwd(oldwd)
