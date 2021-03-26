Create DV data
================

This script applies the cutpoints to the raw DV indicators to create the
actual targets that we will use for the models, i.e. indicators for an
up or down movement over the 2 years following the year in a
row/observation. These targets are denoted with a "\_next2" suffix, as
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

<!-- end list -->

``` r
dv <- read_csv("../output/dv_data_1968_on.csv") %>%
  select(-country_name, -country_id, -country_text_id) %>%
  filter(complete.cases(.)) %>%
  arrange(gwcode, year)
```

    ## 
    ## ── Column specification ───────────────────────────────────────────────────────────────────
    ## cols(
    ##   gwcode = col_double(),
    ##   year = col_double(),
    ##   country_name = col_character(),
    ##   country_id = col_double(),
    ##   country_text_id = col_character(),
    ##   v2x_veracc_osp = col_double(),
    ##   v2xcs_ccsi = col_double(),
    ##   v2xcl_rol = col_double(),
    ##   v2x_freexp_altinf = col_double(),
    ##   v2x_horacc_osp = col_double(),
    ##   v2x_pubcorr = col_double()
    ## )

``` r
range(dv$year)
```

    ## [1] 1968 2020

``` r
cutpoints <- read_csv("../output/cutpoints.csv")
```

    ## 
    ## ── Column specification ───────────────────────────────────────────────────────────────────
    ## cols(
    ##   indicator = col_character(),
    ##   all = col_double(),
    ##   up = col_double(),
    ##   down = col_double()
    ## )

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
  dv_i <- dv_i %>%
    mutate(var_change = case_when(
      y2y_diff_var > cp[[var_i]]  ~ "up",
      y2y_diff_var < -cp[[var_i]] ~ "down",
      year==min(year)      ~ "first year of independence",
      is.na(y2y_diff_var) & year!=min(year) ~ NA_character_,
      TRUE ~ "same"
    ))
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

    ## Joining, by = c("gwcode", "year")
    ## Joining, by = c("gwcode", "year")
    ## Joining, by = c("gwcode", "year")
    ## Joining, by = c("gwcode", "year")
    ## Joining, by = c("gwcode", "year")

Add squared transformations for space indicators. Changes seem to be
more common at middle values and less common in high and low (partly
because beyond some range a change is impossible).

``` r
data("spaces")
stopifnot(all(spaces$Indicator %in% names(dv_data)))
dv_data = dv_data %>%
  mutate_at(vars(one_of(spaces$Indicator)), list(squared = ~`^`(., 2)))
```

Take out the plain up and down dv versions.

``` r
dv_data <- dv_data %>%
  select(-ends_with("up"), -ends_with("down"))

range(dv_data$year)
```

    ## [1] 1968 2020

``` r
write_rds(dv_data, "../output/dv-data.rds")
```

Check the values for one outcome/country to make sure they make sense:

``` r
dv_data %>%
  filter(gwcode==310) %>%
  select(gwcode, year, contains("veracc")) %>%
  filter(year > 2010)
```

    ## # A tibble: 10 x 7
    ##    gwcode  year v2x_veracc_osp dv_v2x_veracc_o… dv_v2x_veracc_o…
    ##     <dbl> <dbl>          <dbl> <chr>                       <int>
    ##  1    310  2011          0.919 same                            0
    ##  2    310  2012          0.918 same                            0
    ##  3    310  2013          0.913 same                            0
    ##  4    310  2014          0.832 down                            0
    ##  5    310  2015          0.832 same                            0
    ##  6    310  2016          0.83  same                            0
    ##  7    310  2017          0.824 same                            0
    ##  8    310  2018          0.759 same                            0
    ##  9    310  2019          0.761 same                           NA
    ## 10    310  2020          0.764 same                           NA
    ## # … with 2 more variables: dv_v2x_veracc_osp_down_next2 <int>,
    ## #   v2x_veracc_osp_squared <dbl>

``` r
skim(dv_data)
```

|                                                  |          |
| :----------------------------------------------- | :------- |
| Name                                             | dv\_data |
| Number of rows                                   | 8289     |
| Number of columns                                | 32       |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_   |          |
| Column type frequency:                           |          |
| character                                        | 6        |
| numeric                                          | 26       |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |          |
| Group variables                                  | None     |

Data summary

**Variable type: character**

| skim\_variable                  | n\_missing | complete\_rate | min | max | empty | n\_unique | whitespace |
| :------------------------------ | ---------: | -------------: | --: | --: | ----: | --------: | ---------: |
| dv\_v2x\_veracc\_osp\_change    |          0 |              1 |   2 |  26 |     0 |         4 |          0 |
| dv\_v2xcs\_ccsi\_change         |          0 |              1 |   2 |  26 |     0 |         4 |          0 |
| dv\_v2xcl\_rol\_change          |          0 |              1 |   2 |  26 |     0 |         4 |          0 |
| dv\_v2x\_freexp\_altinf\_change |          0 |              1 |   2 |  26 |     0 |         4 |          0 |
| dv\_v2x\_horacc\_osp\_change    |          0 |              1 |   2 |  26 |     0 |         4 |          0 |
| dv\_v2x\_pubcorr\_change        |          0 |              1 |   2 |  26 |     0 |         4 |          0 |

**Variable type: numeric**

| skim\_variable                       | n\_missing | complete\_rate |    mean |     sd |      p0 |     p25 |     p50 |     p75 |    p100 | hist  |
| :----------------------------------- | ---------: | -------------: | ------: | -----: | ------: | ------: | ------: | ------: | ------: | :---- |
| gwcode                               |          0 |           1.00 |  462.59 | 240.31 |    2.00 |  305.00 |  461.00 |  663.00 |  950.00 | ▅▆▇▇▃ |
| year                                 |          0 |           1.00 | 1995.12 |  15.15 | 1968.00 | 1982.00 | 1996.00 | 2008.00 | 2020.00 | ▆▆▇▇▇ |
| v2x\_veracc\_osp                     |          0 |           1.00 |    0.63 |   0.27 |    0.06 |    0.41 |    0.70 |    0.89 |    0.96 | ▃▂▃▃▇ |
| dv\_v2x\_veracc\_osp\_up\_next2      |        338 |           0.96 |    0.06 |   0.24 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| dv\_v2x\_veracc\_osp\_down\_next2    |        338 |           0.96 |    0.04 |   0.20 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| v2xcs\_ccsi                          |          0 |           1.00 |    0.57 |   0.32 |    0.01 |    0.28 |    0.65 |    0.89 |    0.98 | ▃▃▂▃▇ |
| dv\_v2xcs\_ccsi\_up\_next2           |        338 |           0.96 |    0.10 |   0.30 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| dv\_v2xcs\_ccsi\_down\_next2         |        338 |           0.96 |    0.06 |   0.24 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| v2xcl\_rol                           |          0 |           1.00 |    0.60 |   0.30 |    0.00 |    0.36 |    0.65 |    0.89 |    0.99 | ▃▃▃▅▇ |
| dv\_v2xcl\_rol\_up\_next2            |        338 |           0.96 |    0.08 |   0.27 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| dv\_v2xcl\_rol\_down\_next2          |        338 |           0.96 |    0.05 |   0.23 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| v2x\_freexp\_altinf                  |          0 |           1.00 |    0.56 |   0.34 |    0.01 |    0.21 |    0.67 |    0.88 |    0.99 | ▆▂▂▅▇ |
| dv\_v2x\_freexp\_altinf\_up\_next2   |        338 |           0.96 |    0.08 |   0.27 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| dv\_v2x\_freexp\_altinf\_down\_next2 |        338 |           0.96 |    0.05 |   0.23 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| v2x\_horacc\_osp                     |          0 |           1.00 |    0.55 |   0.31 |    0.01 |    0.25 |    0.58 |    0.85 |    0.99 | ▅▅▃▅▇ |
| dv\_v2x\_horacc\_osp\_up\_next2      |        338 |           0.96 |    0.08 |   0.28 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| dv\_v2x\_horacc\_osp\_down\_next2    |        338 |           0.96 |    0.05 |   0.22 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| v2x\_pubcorr                         |          0 |           1.00 |    0.53 |   0.30 |    0.01 |    0.26 |    0.52 |    0.82 |    1.00 | ▆▇▅▅▇ |
| dv\_v2x\_pubcorr\_up\_next2          |        338 |           0.96 |    0.08 |   0.28 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| dv\_v2x\_pubcorr\_down\_next2        |        338 |           0.96 |    0.10 |   0.30 |    0.00 |    0.00 |    0.00 |    0.00 |    1.00 | ▇▁▁▁▁ |
| v2x\_veracc\_osp\_squared            |          0 |           1.00 |    0.47 |   0.31 |    0.00 |    0.17 |    0.50 |    0.79 |    0.93 | ▇▅▃▅▇ |
| v2xcs\_ccsi\_squared                 |          0 |           1.00 |    0.43 |   0.35 |    0.00 |    0.08 |    0.42 |    0.79 |    0.96 | ▇▂▂▃▆ |
| v2xcl\_rol\_squared                  |          0 |           1.00 |    0.45 |   0.34 |    0.00 |    0.13 |    0.42 |    0.79 |    0.99 | ▇▃▃▃▆ |
| v2x\_freexp\_altinf\_squared         |          0 |           1.00 |    0.43 |   0.35 |    0.00 |    0.04 |    0.44 |    0.77 |    0.98 | ▇▂▃▃▅ |
| v2x\_horacc\_osp\_squared            |          0 |           1.00 |    0.40 |   0.34 |    0.00 |    0.06 |    0.34 |    0.73 |    0.98 | ▇▂▂▃▃ |
| v2x\_pubcorr\_squared                |          0 |           1.00 |    0.37 |   0.33 |    0.00 |    0.07 |    0.27 |    0.67 |    1.00 | ▇▃▂▂▃ |
