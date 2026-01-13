Create DV data
================

This script applies the cutpoints to the raw DV indicators to create the
actual targets that we will use for the models, i.e. indicators for an
up or down movement over the 2 years following the year in a
row/observation. These targets are denoted with a “\_next2” suffix, as
well as the direction (“up”, “down”) in which they go.

Inputs:

- `output/dv_data_1968_on.csv`
- `output/cutpoints.csv`

Outputs:

The main output is:

- `output/dv-data.rds`

The script also writes CSV files for the target outcome variables, so
that changes are easier to identify on git.

- `output/dv-lists/[vdem indicator].csv`

``` r
dv <- read_csv("../output/dv_data_1968_on.csv") %>%
  select(-country_name, -country_id, -country_text_id) %>%
  dplyr::filter(complete.cases(.)) %>%
  arrange(gwcode, year)
```

    ## Rows: 8627 Columns: 11
    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr (2): country_name, country_text_id
    ## dbl (9): gwcode, year, country_id, v2x_veracc_osp, v2xcs_ccsi, v2xcl_rol, v2...
    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
range(dv$year)
```

    ## [1] 1968 2022

``` r
cutpoints <- read_csv("../output/cutpoints.csv")
```

    ## Rows: 6 Columns: 4
    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr (1): indicator
    ## dbl (3): all, up, down
    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
cp <- cutpoints[["up"]]
names(cp) <- cutpoints[["indicator"]]

dv_vars <- setdiff(names(dv), c("gwcode", "year"))

dv_piece <- list()
for (var_i in dv_vars) {
  dv_i <- dv
  dv_i <- dv %>%
    select(gwcode, year, !!var_i) %>%
    group_by(gwcode) %>%
    arrange(gwcode, year) %>%
    dplyr::mutate(
      # witches' magic that creates a 'dv_i' column that contains values as if in 
      # base R we did dv[, dv_i]; from now on i'll use dv_i for the remaining
      # computations
      var = !!rlang::sym(var_i),
      lag1_var = lag(var, 1L),
      y2y_diff_var = (var - lag1_var),
      # set y2y_diff to 0 if missing (first year of independence)
      y2y_diff_var = ifelse(is.na(y2y_diff_var), 0, y2y_diff_var)
    ) 
  
  # Bypass the normal flow to produce modified data
  # This produces the ERT-lite version of the outcome that was added in the 
  # spring 2022 update. 
  if (getOption("demspaces.version") >= "v12.1") {
    dv_i <- dv_i %>%
      mutate(var_change = changes_one_country(var, cp[[var_i]], type = "mod", 
                                              min_f = MIN_F),
             # actually the first 2 years of indy are missing with this algo,
             # but let's keep the same name
             var_change = ifelse(year < (min(year) + 2), 
                                 "first year of independence",
                                 var_change),
             # there is also an additional NA at the tail, set these to "same"
             # as with previous version of outcome coding
             var_change = ifelse(year==max(year) & is.na(var_change),
                                 "same",
                                 var_change)
             )
  } else {
    dv_i <- dv_i %>%
    mutate(var_change = case_when(
      y2y_diff_var > cp[[var_i]]  ~ "up",
      y2y_diff_var < -cp[[var_i]] ~ "down",
      year==min(year)      ~ "first year of independence",
      is.na(y2y_diff_var) & year!=min(year) ~ NA_character_,
      TRUE ~ "same"
    ))
  }
  # END of bypass
  
  dv_i <- dv_i %>%
    mutate(up = as.integer(var_change=="up"),
           lead1_up = lead(up, 1L),
           lead2_up = lead(up, 2L),
           next2_up = pmax(lead1_up, lead2_up),
           down = as.integer(var_change=="down"),
           lead1_down = lead(down, 1L),
           lead2_down = lead(down, 2L),
           next2_down = pmax(lead1_down, lead2_down)
    ) 
  # some states end during the data period; in these cases we can safely code
  # DV=0 since they are not really censored. 
  dv_i <- dv_i %>%
    ungroup() %>%
    mutate(
      next2_up = case_when(
        is.na(next2_up)   & (year < (max(year) - 1)) ~ 0L,
        TRUE ~ next2_up),
      next2_down = case_when(
        is.na(next2_down) & (year < (max(year) -1)) ~ 0L,
        TRUE ~ next2_down
      ))
  # rename variables
  dv_i <- dv_i %>%
    select(gwcode, year, var, lag1_var, y2y_diff_var, var_change, up, next2_up,
           down, next2_down) %>%
    setNames(c("gwcode", "year", paste0(var_i, c("", "_lag1", "_diff_y2y", 
                                                 "_change", "_up", "_up_next2", 
                                                 "_down", "_down_next2"))))
  
  dv_to_join <- select(dv_i, gwcode, year, !!var_i, 
                       ends_with("change"), ends_with("next2"), 
                       ends_with("up"), ends_with("down")) %>%
    # sub in the actual variable name, not the placeholders
    setNames(c("gwcode", "year", paste0("", names(.)[3:ncol(.)]))) %>%
    # prepend "dv" to vars we should use as IVs
    rename_at(vars(ends_with("change"), ends_with("next2")), ~ paste0("dv_", .))
  
  dv_piece[[var_i]] <- dv_to_join
}
```

Write the pieces to CSV files so we can quickly see on git when anything
changes.

``` r
for (i in seq_along(dv_piece)) {
  var_i <- names(dv_piece)[i]
  dv_to_join <- dv_piece[[var_i]]
  dv_to_join <- dv_to_join %>% select(-ends_with("_up"), -ends_with("_down"),
                                      -starts_with("v2"))
  fn <- paste0(var_i, ".csv")
  write_csv(dv_to_join, file.path("../output/dv-lists", fn))
}
```

Combine into one large DV set.

``` r
dv_data <- Reduce(left_join, x = dv_piece)
```

    ## Joining with `by = join_by(gwcode, year)`
    ## Joining with `by = join_by(gwcode, year)`
    ## Joining with `by = join_by(gwcode, year)`
    ## Joining with `by = join_by(gwcode, year)`
    ## Joining with `by = join_by(gwcode, year)`

Add squared transformations for space indicators. Changes seem to be
more common at middle values and less common in high and low (partly
because beyond some range a change is impossible).

``` r
data("spaces")
stopifnot(all(spaces$Indicator %in% names(dv_data)))
dv_data = dv_data %>%
  mutate_at(vars(one_of(spaces$Indicator)), list(squared = ~`^`(., 2)))
```

Add markers for when up/down changes are impossible given the current
indicator value and cutpoints (see
[\#15](https://github.com/vdeminstitute/demspaces/issues/15)).

``` r
data("spaces")

for (ind in spaces$Indicator) {
  for (dir in c("up", "down")) {
    marker <- paste0("no_", dir, "_", ind)
    cp <- cutpoints[cutpoints$indicator==ind, ][[dir]]
    if (dir=="up") {
      dv_data[[marker]] <- as.integer((dv_data[[ind]]) > (1 - cp))
    } else {
      dv_data[[marker]] <- as.integer((dv_data[[ind]]) < cp)
    }
    # for debug/check, print these crosstabs
    # almost all column 1's should be in the 0 row, see #15
    #cat(paste0(ind, " ", dir), "\n")
    #print(table(dv_data[[marker]], dv_data[[paste0("dv_", ind, "_", dir, "_next2")]]))
  }
}
```

Take out the plain up and down dv versions.

``` r
dv_data <- dv_data %>%
  select(-ends_with("up"), -ends_with("down"))

range(dv_data$year)
```

    ## [1] 1968 2022

``` r
write_rds(dv_data, "../output/dv-data.rds")

# Record some stats on the DV data so that during updates it is easier to
# quickly tell whether the new data make sense
dv_data %>%
  ungroup() %>%
  select(ends_with("_change")) %>%
  tidyr::pivot_longer(everything(), names_to = "space") %>%
  count(space, value) %>%
  mutate(value = factor(value, levels = c("first year of independence", "same",
                                          "up", "down"))) %>%
  arrange(value) %>%
  tidyr::pivot_wider(names_from = "value", values_from = "n") %>%
  write_csv("../output/dv-summary.csv")
```

Check the values for one outcome/country to make sure they make sense:

``` r
dv_data %>%
  dplyr::filter(gwcode==310) %>%
  select(gwcode, year, contains("veracc")) %>%
  dplyr::filter(year > 2010)
```

    ## # A tibble: 12 × 6
    ##    gwcode  year v2x_veracc_osp dv_v2x_veracc_osp_change dv_v2x_veracc_osp_up_n…¹
    ##     <dbl> <dbl>          <dbl> <chr>                                       <int>
    ##  1    310  2011          0.915 same                                            0
    ##  2    310  2012          0.914 same                                            0
    ##  3    310  2013          0.909 same                                            0
    ##  4    310  2014          0.816 down                                            0
    ##  5    310  2015          0.816 same                                            0
    ##  6    310  2016          0.816 same                                            0
    ##  7    310  2017          0.81  same                                            0
    ##  8    310  2018          0.754 same                                            0
    ##  9    310  2019          0.755 same                                            0
    ## 10    310  2020          0.755 same                                            0
    ## 11    310  2021          0.748 same                                           NA
    ## 12    310  2022          0.754 same                                           NA
    ## # ℹ abbreviated name: ¹​dv_v2x_veracc_osp_up_next2
    ## # ℹ 1 more variable: dv_v2x_veracc_osp_down_next2 <int>

``` r
skim(dv_data)
```

|                                                  |         |
|:-------------------------------------------------|:--------|
| Name                                             | dv_data |
| Number of rows                                   | 8627    |
| Number of columns                                | 26      |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_   |         |
| Column type frequency:                           |         |
| character                                        | 6       |
| numeric                                          | 20      |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |         |
| Group variables                                  | None    |

Data summary

**Variable type: character**

| skim_variable | n_missing | complete_rate | min | max | empty | n_unique | whitespace |
|:---|---:|---:|---:|---:|---:|---:|---:|
| dv_v2x_veracc_osp_change | 0 | 1 | 2 | 26 | 0 | 4 | 0 |
| dv_v2xcs_ccsi_change | 0 | 1 | 2 | 26 | 0 | 4 | 0 |
| dv_v2xcl_rol_change | 0 | 1 | 2 | 26 | 0 | 4 | 0 |
| dv_v2x_freexp_altinf_change | 0 | 1 | 2 | 26 | 0 | 4 | 0 |
| dv_v2x_horacc_osp_change | 0 | 1 | 2 | 26 | 0 | 4 | 0 |
| dv_v2x_pubcorr_change | 0 | 1 | 2 | 26 | 0 | 4 | 0 |

**Variable type: numeric**

| skim_variable | n_missing | complete_rate | mean | sd | p0 | p25 | p50 | p75 | p100 | hist |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---|
| gwcode | 0 | 1.00 | 462.66 | 240.15 | 2.00 | 305.00 | 461.00 | 663.00 | 950.00 | ▅▆▇▇▃ |
| year | 0 | 1.00 | 1996.15 | 15.71 | 1968.00 | 1983.00 | 1997.00 | 2010.00 | 2022.00 | ▆▇▇▇▇ |
| v2x_veracc_osp | 0 | 1.00 | 0.63 | 0.27 | 0.05 | 0.41 | 0.70 | 0.89 | 0.96 | ▃▂▃▃▇ |
| dv_v2x_veracc_osp_up_next2 | 338 | 0.96 | 0.08 | 0.27 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| dv_v2x_veracc_osp_down_next2 | 338 | 0.96 | 0.05 | 0.23 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| v2xcs_ccsi | 0 | 1.00 | 0.57 | 0.32 | 0.01 | 0.27 | 0.65 | 0.89 | 0.98 | ▅▃▂▃▇ |
| dv_v2xcs_ccsi_up_next2 | 338 | 0.96 | 0.13 | 0.34 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| dv_v2xcs_ccsi_down_next2 | 338 | 0.96 | 0.10 | 0.30 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| v2xcl_rol | 0 | 1.00 | 0.60 | 0.30 | 0.00 | 0.35 | 0.65 | 0.88 | 0.99 | ▃▃▃▅▇ |
| dv_v2xcl_rol_up_next2 | 338 | 0.96 | 0.13 | 0.33 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| dv_v2xcl_rol_down_next2 | 338 | 0.96 | 0.09 | 0.29 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| v2x_freexp_altinf | 0 | 1.00 | 0.56 | 0.33 | 0.01 | 0.22 | 0.66 | 0.87 | 0.99 | ▆▃▂▅▇ |
| dv_v2x_freexp_altinf_up_next2 | 338 | 0.96 | 0.13 | 0.33 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| dv_v2x_freexp_altinf_down_next2 | 338 | 0.96 | 0.09 | 0.29 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| v2x_horacc_osp | 0 | 1.00 | 0.55 | 0.31 | 0.02 | 0.25 | 0.58 | 0.85 | 0.99 | ▆▅▃▅▇ |
| dv_v2x_horacc_osp_up_next2 | 338 | 0.96 | 0.11 | 0.31 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| dv_v2x_horacc_osp_down_next2 | 338 | 0.96 | 0.08 | 0.27 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| v2x_pubcorr | 0 | 1.00 | 0.53 | 0.30 | 0.01 | 0.26 | 0.50 | 0.81 | 1.00 | ▆▇▅▅▇ |
| dv_v2x_pubcorr_up_next2 | 338 | 0.96 | 0.10 | 0.30 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
| dv_v2x_pubcorr_down_next2 | 338 | 0.96 | 0.12 | 0.32 | 0.00 | 0.00 | 0.00 | 0.00 | 1.00 | ▇▁▁▁▁ |
