

library(readr)
library(dplyr)
library(glue)
library(tidyr)

data_path <- function(v) {
  glue("create-data/input/V-Dem-CY-Full+Others-{v}.rds")
}

read_vdem <- function(v) {
  data_path(v) |>
    read_rds() |>
    as_tibble() |>
    filter(year > 1990) |>
    select(country_name, country_text_id, year,
           starts_with("v2x_polyarchy"),
           starts_with("v2x_regime")) |>
    mutate(vdem_version = v)
}

vdem15 <- read_vdem("v15")
vdem14 <- read_vdem("v14")
vdem13 <- read_vdem("v13")
vdem12 <- read_vdem("v12")
vdem11.1 <- read_vdem("v11.1")
vdem10 <- read_vdem("v10")
vdem9 <- read_vdem("v9")

vdem <- bind_rows(vdem15, vdem14, vdem13, vdem12, vdem11.1, vdem10, vdem9) |>
  mutate(vdem_version = factor(vdem_version, labels = paste0("v", c(9, 10, 11.1, 12, 13, 14, 15))))

# Country name changes, ugh
vdem <- vdem |>
  mutate(country_name = case_when(
    country_name=="Czech Republic" ~ "Czechia",
    country_name=="Turkey" ~ "Türkiye",
    TRUE ~ country_name
  ))

v1 <- "v13"
v2 <- "v15"

min_year <- 2020

compare_row <- function(v1, v2, min_year = 2022) {
  counts <- vdem |>
    filter(year < (min_year + 1)) |>
    filter(vdem_version %in% c(v2, v1)) |>
    select(country_text_id, year, vdem_version, v2x_regime) |>
    tidyr::pivot_wider(names_from = vdem_version,
                       values_from = v2x_regime) |>
    count(.data[[v1]], .data[[v2]])

  off_diagonal <- counts |>
    filter(.data[[v1]]!=.data[[v2]]) |>
    pull(n) |>
    sum()

  od_perc <- off_diagonal / sum(counts$n) * 100
  print(glue("Off diagonal: {off_diagonal} cases, {round(od_perc, 1)}%"))

  tbl <- counts |>
    pivot_wider(names_from = all_of(v2), values_from = "n", names_prefix = paste0(v2, "_"),
                values_fill = 0)
  list(
    od = off_diagonal,
    odp = od_perc,
    tbl = tbl
  )
}

v11_v12 = compare_row("v11.1", "v12")
v11_v13 = compare_row("v11.1", "v13")
v11_v14 = compare_row("v11.1", "v14")
v11_v15 = compare_row("v11.1", "v15")

v12_v13 = compare_row("v12", "v13")
v12_v14 = compare_row("v12", "v14")
v12_v15 = compare_row("v12", "v15")

v13_v14 = compare_row("v13", "v14")
v13_v15 = compare_row("v13", "v15")


edi_diff <- vdem |>
  group_by(country_name, vdem_version) |>
  mutate(edi_diff = c(diff(v2x_polyarchy, lag = 2), NA, NA),
         decrease = as.integer(edi_diff < -0.05)) |>
  ungroup()

row_diff <- vdem |>
  group_by(country_name, vdem_version) |>
  mutate(row_diff = c(diff(v2x_regime, lag = 2), NA, NA),
         decrease = as.integer(row_diff < 0)) |>
  ungroup()


compare_edi_diff <- function(v1, v2, min_year = 1991, max_year = 2018) {
  counts <- edi_diff |>
    filter(year > (min_year - 1), year < (max_year + 1)) |>
    filter(vdem_version %in% c(v2, v1)) |>
    select(country_text_id, year, vdem_version, decrease) |>
    tidyr::pivot_wider(names_from = vdem_version,
                       values_from = decrease) |>
    count(.data[[v1]], .data[[v2]])

  off_diagonal <- counts |>
    filter(.data[[v1]]!=.data[[v2]]) |>
    pull(n) |>
    sum()

  od_perc <- off_diagonal / sum(counts$n) * 100
  print(glue("Off diagonal: {off_diagonal} cases, {round(od_perc, 1)}%"))

  c1pos <- (counts[[1]] %in% 1)
  c2pos <- (counts[[2]] %in% 1)
  all_pos <- sum(counts$n[(c1pos | c2pos ) & (!is.na(counts[[1]]) & !is.na(counts[[2]]))])
  both_pos <- sum(counts$n[c1pos & c2pos])
  pos_agree <- both_pos / all_pos

  tbl <- counts |>
    pivot_wider(names_from = all_of(v2), values_from = "n", names_prefix = paste0(v2, "_"),
                values_fill = 0)
  list(
    od = off_diagonal,
    odp = od_perc,
    pap = pos_agree * 100,
    tbl = tbl
  )
}


compare_row_diff <- function(v1, v2, min_year = 1991, max_year = 2018) {
  counts <- row_diff |>
    filter(year > (min_year - 1), year < (max_year + 1)) |>
    filter(vdem_version %in% c(v2, v1)) |>
    select(country_text_id, year, vdem_version, decrease) |>
    tidyr::pivot_wider(names_from = vdem_version,
                       values_from = decrease) |>
    count(.data[[v1]], .data[[v2]])

  off_diagonal <- counts |>
    filter(.data[[v1]]!=.data[[v2]]) |>
    pull(n) |>
    sum()

  od_perc <- off_diagonal / sum(counts$n) * 100
  print(glue("Off diagonal: {off_diagonal} cases, {round(od_perc, 1)}%"))

  c1pos <- (counts[[1]] %in% 1)
  c2pos <- (counts[[2]] %in% 1)
  all_pos <- sum(counts$n[(c1pos | c2pos ) & (!is.na(counts[[1]]) & !is.na(counts[[2]]))])
  both_pos <- sum(counts$n[c1pos & c2pos])
  pos_agree <- both_pos / all_pos

  tbl <- counts |>
    pivot_wider(names_from = all_of(v2), values_from = "n", names_prefix = paste0(v2, "_"),
                values_fill = 0)
  list(
    od = off_diagonal,
    odp = od_perc,
    pap = pos_agree * 100,
    tbl = tbl
  )
}

MAX_YEAR = 2025

edi_comparisons <- list(
compare_edi_diff("v11.1", "v12", max_year = MAX_YEAR),
compare_edi_diff("v11.1", "v13", max_year = MAX_YEAR),
compare_edi_diff("v11.1", "v14", max_year = MAX_YEAR),
compare_edi_diff("v11.1", "v15", max_year = MAX_YEAR),

compare_edi_diff("v12", "v13", max_year = MAX_YEAR),
compare_edi_diff("v12", "v14", max_year = MAX_YEAR),
compare_edi_diff("v12", "v15", max_year = MAX_YEAR),

compare_edi_diff("v13", "v14", max_year = MAX_YEAR),
compare_edi_diff("v13", "v15", max_year = MAX_YEAR),

compare_edi_diff("v14", "v15", max_year = MAX_YEAR)
)


edi_diff |> filter(is.na(decrease)) |>
  arrange(country_name, year, vdem_version) |> select(country_name, year, vdem_version) |>
  count(country_name, year) |> filter(n!=5)




row_comparisons <- list(
  compare_row_diff("v11.1", "v12", max_year = MAX_YEAR),
  compare_row_diff("v11.1", "v13", max_year = MAX_YEAR),
  compare_row_diff("v11.1", "v14", max_year = MAX_YEAR),
  compare_row_diff("v11.1", "v15", max_year = MAX_YEAR),

  compare_row_diff("v12", "v13", max_year = MAX_YEAR),
  compare_row_diff("v12", "v14", max_year = MAX_YEAR),
  compare_row_diff("v12", "v15", max_year = MAX_YEAR),

  compare_row_diff("v13", "v14", max_year = MAX_YEAR),
  compare_row_diff("v13", "v15", max_year = MAX_YEAR),

  compare_row_diff("v14", "v15", max_year = MAX_YEAR)
)

row_df <- tibble(
  dv_version = c(rep("v11.1", 4), rep("v12", 3), rep("v13", 2), rep("v14", 1)),
  assess = c(paste0("v", 12:15), paste0("v", 13:15), paste0("v", 14:15), paste0("v", 15)),
  pap = sapply(row_comparisons, \(x) x$pap)
)

ggplot(row_df, aes(x = assess, y = pap, group = dv_version)) +
  geom_point(aes(color = dv_version)) +
  geom_line(aes(color = dv_version))


edi_df <- tibble(
  dv_version = c(rep("v11.1", 4), rep("v12", 3), rep("v13", 2), rep("v14", 1)),
  assess = c(paste0("v", 12:15), paste0("v", 13:15), paste0("v", 14:15), paste0("v", 15)),
  pap = sapply(edi_comparisons, \(x) x$pap)
)

ggplot(edi_df, aes(x = assess, y = pap, group = dv_version)) +
  geom_point(aes(color = dv_version)) +
  geom_line(aes(color = dv_version))

both_df <- bind_rows(
  row_df |> mutate(outcome = "RoW"),
  edi_df |> mutate(outcome = "EDI")
)

ggplot(both_df, aes(x = assess, y = pap, group = dv_version)) +
  geom_point(aes(color = dv_version)) +
  geom_line(aes(color = dv_version)) +
  facet_wrap(~outcome) +
  scale_color_discrete("Version we start with") +
  scale_y_continuous(limit = c(40, 100)) +
  labs(x = "Version compared to",
       y = "Agreement on cases we care about (decrease in Y)",
       title = "Agreement on target cases in future version of V-Dem",
       subtitle = "Targets are EDI: EID is 0.05 lower in 2 years; RoW: Row is lower in 2 years")



# How many countries in 2018 (v9 max) have the same RoW values in successive data versions?
row_by_version <- vdem |>
  filter(year==2018) |>
  select(country_text_id, v2x_regime, vdem_version) |>
  arrange(country_text_id, vdem_version) |>
  pivot_wider(names_from = "vdem_version", values_from = "v2x_regime")

for (col in paste0("v", c(10, 11.1, 12, 13, 14, 15))) {
  row_by_version[[paste0("in_", col)]] <- case_when(
    row_by_version[["v9"]]==row_by_version[[col]] ~ "same",
    row_by_version[["v9"]] < row_by_version[[col]] ~ "lower",
    row_by_version[["v9"]] > row_by_version[[col]] ~ "higher",
    TRUE ~ NA_character_
  )
}

vdem |>
  filter(year==2018) |>
  group_by(country_text_id, country_name) |>
  filter(length(unique(v2x_regime)) > 1) |>
  group_by(country_text_id, country_name) |>
  summarize(vals = length(unique(v2x_regime)))

row_by_version |>
  count(in_v10, in_v11.1, in_v12, in_v13, in_v14, in_v15) |>
  mutate(perc = round(100*n / sum(n), 1)) |>
  arrange(desc(n), in_v10, in_v11.1, in_v12, in_v13, in_v14, in_v15)


# If we look at changes in RoW, how many are consistent in successive Vdem versions?
delta_row_by_version <- vdem |>
  filter(year %in% c(2017, 2018)) |>
  arrange(country_text_id, vdem_version, year) |>
  group_by(country_text_id, country_name, vdem_version) |>
  summarize(delta_row = diff(v2x_regime), .groups = "drop")

delta_row_by_version_wide <- delta_row_by_version |>
  pivot_wider(names_from = "vdem_version", values_from = "delta_row")


delta_row_by_version |> filter(vdem_version=="v9") |> filter(delta_row!=0) |> arrange(delta_row)
#   # A tibble: 9 × 4
#   country_text_id country_name vdem_version delta_row
#   <chr>           <chr>        <fct>            <dbl>
# 1 ALB             Albania      v9                  -1
# 2 CPV             Cape Verde   v9                  -1
# 3 GRC             Greece       v9                  -1
# 4 HUN             Hungary      v9                  -1
# 5 KOR             South Korea  v9                  -1
# 6 TUN             Tunisia      v9                  -1
# 7 BWA             Botswana     v9                   1
# 8 GMB             The Gambia   v9                   1
# 9 MUS             Mauritius    v9                   1


delta_row_by_version_wide |>
  count(v9, v10, v11.1, v12, v13, v14, v15) |>
  filter(v9!=0)

#   # A tibble: 7 × 8
#   v9   v10 v11.1   v12   v13   v14   v15     n
#   <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <int>
# 1    -1    -1    -1    -1    -1    -1     0     1
# 2    -1    -1    -1    -1     0     0    -1     1
# 3    -1     0     0    -1     0     0     1     1
# 4    -1     0     0     0     0     0    -1     3
# 5     1     0     0     0     0     0     0     1
# 6     1     0     0     0     0     0     1     1
# 7     1     1     1     0     0     0     1     1

# Of the 9 RoW changes 2017--2018 in the v9 data, NONE are coded the same way
# in all the successive versions through to v15.
# In additiona, there are up to 16 RoW changes for 2017--2018 in other data
# versions that were not in v9. (There are some missing cases, maybe country_name mismatches.)


