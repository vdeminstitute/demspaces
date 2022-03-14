Combine data
================

-   [NOTES FOR DATA UPDATES](#notes-for-data-updates)
-   [Pieces](#pieces)
    -   [Master statelist](#master-statelist)
    -   [V-Dem DVs](#v-dem-dvs)
    -   [V-Dem IVs](#v-dem-ivs)
    -   [State age](#state-age)
    -   [Population](#population)
    -   [Infant mortality](#infant-mortality)
    -   [GDP](#gdp)
    -   [P&T Coups](#pt-coups)
-   [Summarize and write final
    output](#summarize-and-write-final-output)
    -   [Record missing cases](#record-missing-cases)
    -   [Missing values by column](#missing-values-by-column)
-   [Done, save](#done-save)

## NOTES FOR DATA UPDATES

END_YEAR denotes the last year data have been observed. I.e. usually it
should be the year prior to the current year.

Data after this year will be discarded. E.g. to forecast 2020-2021 we
don’t want to use data after 2019 since it likely won’t be
available/incomplete at the time we are making the 2020-2021 forecasts.
Conversely, if the data end early, e.g. in 2017, they will be lagged
additionally so that they reach and cover the target year.

Note also that the DV data are in a 2-year lead. So the data point for
“dv_v2x_veracc_osp_down_next2” in 2019 refers to vertical accountability
decreases in 2020-2021.

Several of the data sources below are imputed in some fashion after
merging. E.g. if a data set has to be lagged 1 year to obtain values for
the desired data end year, values for the first of independence for
several states will become missing. When data are updated, these
source-specific lags may change. Thus what cases are missing will
change, and what does or does not get imputed will change. Check the
output of all chunks below for new changes in missing case sets!

``` r
END_YEAR <- 2021
# UPDATE: this should be the V-Dem data version, but for development I've also
# use sub-versions like 'v11a', ...
VERSION  <- "v12"
```

## Pieces

### Master statelist

``` r
cy <- read_csv("../output/country_year_set_1968_on.csv") %>%
  filter(year > 1969, year <= END_YEAR)
```

    ## Rows: 8458 Columns: 5

    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr (2): country_name, country_text_id
    ## dbl (3): gwcode, year, country_id

    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
cy_names <- cy
cy <- cy[, c("gwcode", "year")]
```

For spatial lagging, we cannot have overlapping geometries. For example
in 1990 we cannot have both re-unified Germany from the end of the year,
and then also separate West Germany and East Germany at the beginning of
the year. Check against state panel to remove cases like this if needed.

``` r
master <- state_panel(1970, END_YEAR, partial = "last", by = "year")
overlap <- compare(master, cy)
report(overlap)
```

    ## 9393 total rows
    ## 9390 rows in df1
    ## 8190 rows in df2
    ## 
    ## 8187 rows match and have no missing values
    ## 2-1970, 2-1971, 2-1972, 2-1973, 2-1974, 2-1975, 2-1976, 2-1977, 2-1978, 2-1979, and 8177 more
    ## 
    ## 1203 rows in df1 (no missing values) but not df2
    ## 31-1973, 31-1974, 31-1975, 31-1976, 31-1977, 31-1978, 31-1979, 31-1980, 31-1981, 31-1982, and 1193 more
    ## 
    ## 3 rows not in df1 but in df2 (no missing values)
    ## 265-1990, 680-1990, 817-1975

``` r
drop <- anti_join(cy, master)
```

    ## Joining, by = c("gwcode", "year")

``` r
drop$drop <- TRUE
cy <- left_join(cy, drop) %>%
  mutate(drop = ifelse(is.na(drop), FALSE, drop))
```

    ## Joining, by = c("gwcode", "year")

``` r
cy <- cy[!cy$drop, ]
cy$drop <- NULL
```

``` r
plotmiss(cy)
```

![](3-combine-data_files/figure-gfm/cy-missplot-1.png)<!-- -->

### V-Dem DVs

These are the indicators from which the outcome variables are derived.

``` r
dv <- read_csv("../output/dv_data_1968_on.csv") %>%
  select(-country_name, -country_id, -country_text_id) %>%
  filter(complete.cases(.)) %>%
  arrange(gwcode, year)
```

    ## Rows: 8458 Columns: 11

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

    ## [1] 1968 2021

``` r
dv_data <- read_rds("../output/dv-data.rds")
cy <- left_join(cy, dv_data, by = c("gwcode", "year"))
```

For outcome variable *x*, this code creates the following additional
columns:

-   `[x]`: the raw outcome variable
-   `[x]_diff_y2y`: the year to year change
-   `dv_[x]_...`: versions starting with “dv\_” should not be used as
    IVs
    -   `dv_[x]_change`: character vector of the current year change
        (up, same, down)
    -   `dv_[x]_[up, down]_next2`: 0/1 indicator, is there a up/down
        change in the next 2 years?

``` r
plotmiss(cy)
```

![](3-combine-data_files/figure-gfm/unnamed-chunk-5-1.png)<!-- -->

The missing are because the “next2” variables are missing for the last 2
years of available data since we don’t have the 2 years of future
outcomes yet.

### V-Dem IVs

``` r
vdem_dat <- read_csv("../output/vdem_data_1968_on.csv") %>%
  select(-country_name, -country_id, -country_text_id) %>%
  filter(complete.cases(.)) %>%
  arrange(gwcode, year)
```

    ## Rows: 8458 Columns: 196

    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr   (2): country_name, country_text_id
    ## dbl (194): gwcode, year, country_id, is_jud, is_leg, is_elec, is_election_ye...

    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
# take out zero-variance vars
sds <- sapply(vdem_dat, sd)
zv_vars <- names(sds[sds==0])
vdem_dat <- vdem_dat %>% select(-one_of(zv_vars))

names(vdem_dat) <- stringr::str_replace(names(vdem_dat), "^lagged\\_", "")

# check no DVs are here
if (any(setdiff(names(vdem_dat), c("gwcode", "year")) %in% names(dv))) {
  stop("Some DV variables are in V-Dem IV set, staaap")
}

vdem_dat <- vdem_dat %>%
  filter(year <= END_YEAR)
vdem_lag <- END_YEAR - max(vdem_dat$year)
vdem_dat <- vdem_dat %>%
  mutate(year = year + vdem_lag) %>%
  setNames(c(names(.)[1:2], paste0("lag", vdem_lag, "_", names(.)[-c(1:2)])))

vdem_lag
```

    ## [1] 0

``` r
str(vdem_dat)
```

    ## tibble [8,445 × 192] (S3: tbl_df/tbl/data.frame)
    ##  $ gwcode                     : num [1:8445] 2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year                       : num [1:8445] 1968 1969 1970 1971 1972 ...
    ##  $ lag0_is_leg                : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_is_elec               : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_is_election_year      : num [1:8445] 1 0 1 0 1 0 1 0 1 0 ...
    ##  $ lag0_v2x_polyarchy         : num [1:8445] 0.711 0.696 0.709 0.731 0.741 0.758 0.764 0.789 0.799 0.837 ...
    ##  $ lag0_v2x_liberal           : num [1:8445] 0.874 0.894 0.912 0.916 0.917 0.933 0.935 0.937 0.939 0.938 ...
    ##  $ lag0_v2xdl_delib           : num [1:8445] 0.904 0.908 0.906 0.906 0.906 0.908 0.908 0.937 0.956 0.961 ...
    ##  $ lag0_v2x_jucon             : num [1:8445] 0.899 0.929 0.942 0.942 0.942 0.942 0.947 0.947 0.947 0.947 ...
    ##  $ lag0_v2x_frassoc_thick     : num [1:8445] 0.858 0.857 0.859 0.872 0.871 0.883 0.884 0.888 0.887 0.93 ...
    ##  $ lag0_v2xel_frefair         : num [1:8445] 0.757 0.719 0.73 0.785 0.784 0.779 0.781 0.824 0.83 0.859 ...
    ##  $ lag0_v2x_elecoff           : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2xlg_legcon          : num [1:8445] 0.888 0.888 0.896 0.896 0.896 0.944 0.944 0.944 0.944 0.934 ...
    ##  $ lag0_v2x_partip            : num [1:8445] 0.634 0.634 0.646 0.646 0.646 0.65 0.65 0.65 0.655 0.655 ...
    ##  $ lag0_v2x_cspart            : num [1:8445] 0.908 0.908 0.942 0.942 0.942 0.951 0.951 0.954 0.969 0.969 ...
    ##  $ lag0_v2x_egal              : num [1:8445] 0.606 0.668 0.75 0.744 0.744 0.752 0.752 0.747 0.743 0.741 ...
    ##  $ lag0_v2xeg_eqprotec        : num [1:8445] 0.674 0.825 0.853 0.853 0.853 0.853 0.853 0.853 0.853 0.852 ...
    ##  $ lag0_v2xeg_eqaccess        : num [1:8445] 0.601 0.621 0.762 0.762 0.762 0.774 0.774 0.769 0.769 0.769 ...
    ##  $ lag0_v2xeg_eqdr            : num [1:8445] 0.564 0.596 0.672 0.659 0.659 0.677 0.677 0.677 0.674 0.674 ...
    ##  $ lag0_v2x_diagacc           : num [1:8445] 1.28 1.34 1.46 1.42 1.47 ...
    ##  $ lag0_v2xex_elecleg         : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2x_civlib            : num [1:8445] 0.857 0.88 0.901 0.896 0.904 0.91 0.912 0.919 0.925 0.927 ...
    ##  $ lag0_v2x_clphy             : num [1:8445] 0.877 0.894 0.901 0.901 0.912 0.912 0.912 0.912 0.912 0.912 ...
    ##  $ lag0_v2x_clpol             : num [1:8445] 0.907 0.915 0.931 0.912 0.925 0.94 0.949 0.951 0.959 0.964 ...
    ##  $ lag0_v2x_clpriv            : num [1:8445] 0.805 0.847 0.885 0.893 0.893 0.893 0.893 0.91 0.916 0.923 ...
    ##  $ lag0_v2x_corr              : num [1:8445] 0.055 0.065 0.073 0.076 0.076 0.076 0.076 0.059 0.059 0.059 ...
    ##  $ lag0_v2x_EDcomp_thick      : num [1:8445] 0.77 0.75 0.757 0.793 0.792 0.792 0.795 0.823 0.827 0.868 ...
    ##  $ lag0_v2x_elecreg           : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2x_freexp            : num [1:8445] 0.904 0.919 0.925 0.888 0.92 0.941 0.955 0.957 0.97 0.962 ...
    ##  $ lag0_v2x_gencl             : num [1:8445] 0.736 0.805 0.828 0.841 0.841 0.841 0.841 0.862 0.898 0.898 ...
    ##  $ lag0_v2x_gencs             : num [1:8445] 0.474 0.481 0.588 0.615 0.616 0.618 0.659 0.72 0.72 0.72 ...
    ##  $ lag0_v2x_hosabort          : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_hosinter          : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_rule              : num [1:8445] 0.943 0.952 0.953 0.955 0.956 0.955 0.957 0.97 0.971 0.971 ...
    ##  $ lag0_v2xcl_acjst           : num [1:8445] 0.829 0.921 0.947 0.947 0.955 0.955 0.955 0.955 0.955 0.955 ...
    ##  $ lag0_v2xcl_disc            : num [1:8445] 0.833 0.904 0.904 0.913 0.913 0.913 0.954 0.96 0.96 0.96 ...
    ##  $ lag0_v2xcl_dmove           : num [1:8445] 0.698 0.807 0.863 0.863 0.863 0.863 0.863 0.899 0.899 0.899 ...
    ##  $ lag0_v2xcl_prpty           : num [1:8445] 0.611 0.701 0.728 0.778 0.778 0.778 0.778 0.778 0.85 0.85 ...
    ##  $ lag0_v2xcl_slave           : num [1:8445] 0.785 0.785 0.785 0.794 0.794 0.794 0.794 0.794 0.794 0.794 ...
    ##  $ lag0_v2xel_elecparl        : num [1:8445] 1 0 1 0 1 0 1 0 1 0 ...
    ##  $ lag0_v2xel_elecpres        : num [1:8445] 1 0 0 0 1 0 0 0 1 0 ...
    ##  $ lag0_v2xex_elecreg         : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2xlg_elecreg         : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2ex_legconhog        : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2ex_legconhos        : num [1:8445] 0 0 0 0 0 0 1 1 1 0 ...
    ##  $ lag0_v2x_ex_confidence     : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_ex_direlect       : num [1:8445] 1 1 1 1 1 1 0 0 0 1 ...
    ##  $ lag0_v2x_ex_hereditary     : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_ex_military       : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_ex_party          : num [1:8445] 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 ...
    ##  $ lag0_v2x_execorr           : num [1:8445] 0.032 0.05 0.092 0.092 0.092 0.092 0.092 0.028 0.028 0.028 ...
    ##  $ lag0_v2x_legabort          : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2xlg_leginter        : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_neopat            : num [1:8445] 0.097 0.094 0.093 0.089 0.088 0.079 0.078 0.053 0.053 0.055 ...
    ##  $ lag0_v2xnp_client          : num [1:8445] 0.26 0.261 0.252 0.218 0.218 0.215 0.215 0.217 0.212 0.187 ...
    ##  $ lag0_v2xnp_pres            : num [1:8445] 0.11 0.09 0.07 0.07 0.07 0.058 0.058 0.048 0.048 0.051 ...
    ##  $ lag0_v2xnp_regcorr         : num [1:8445] 0.037 0.06 0.086 0.086 0.086 0.086 0.086 0.036 0.036 0.036 ...
    ##  $ lag0_v2elvotbuy            : num [1:8445] 0.24 0.24 1.03 1.03 1.02 ...
    ##  $ lag0_v2elfrcamp            : num [1:8445] 0.601 0.601 0.597 0.597 0.584 0.584 0.679 0.679 0.651 0.651 ...
    ##  $ lag0_v2elpdcamp            : num [1:8445] 1.8 1.8 1.82 1.82 1.8 ...
    ##  $ lag0_v2elpaidig            : num [1:8445] 2.21 2.21 2.21 2.21 2.21 ...
    ##  $ lag0_v2elmonref            : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2elmonden            : num [1:8445] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2elrgstry            : num [1:8445] 0.155 0.155 0.39 0.39 0.367 0.367 0.395 0.395 0.396 0.396 ...
    ##  $ lag0_v2elirreg             : num [1:8445] 0.855 0.855 0.863 0.863 0.858 ...
    ##  $ lag0_v2elintim             : num [1:8445] 1.09 1.09 1.26 1.26 1.38 ...
    ##  $ lag0_v2elpeace             : num [1:8445] 0.441 0.441 1.15 1.15 1.211 ...
    ##  $ lag0_v2elfrfair            : num [1:8445] 0.946 0.946 0.964 0.964 0.781 ...
    ##  $ lag0_v2elmulpar            : num [1:8445] 1.57 1.57 1.55 1.55 1.55 ...
    ##  $ lag0_v2elboycot            : num [1:8445] 1.3 1.3 1.3 1.3 1.3 ...
    ##  $ lag0_v2elaccept            : num [1:8445] 1.45 1.45 1.45 1.45 1.45 ...
    ##  $ lag0_v2elasmoff            : num [1:8445] 0.532 0.532 0.538 0.538 0.522 0.522 0.523 0.523 0.518 0.518 ...
    ##  $ lag0_v2eldonate            : num [1:8445] 2.19 2.19 2.45 2.49 2.49 ...
    ##  $ lag0_v2elpubfin            : num [1:8445] -1.94 -1.94 -1.94 -1.01 -1.01 ...
    ##  $ lag0_v2ellocumul           : num [1:8445] 35 35 36 36 37 37 38 38 39 39 ...
    ##  $ lag0_v2elprescons          : num [1:8445] 18 18 18 18 19 19 19 19 20 20 ...
    ##  $ lag0_v2elprescumul         : num [1:8445] 18 18 18 18 19 19 19 19 20 20 ...
    ##  $ lag0_v2elembaut            : num [1:8445] 1.18 1.18 1.71 1.71 1.71 ...
    ##  $ lag0_v2elembcap            : num [1:8445] 0.605 0.605 0.605 0.605 0.605 0.605 0.605 0.824 0.824 0.824 ...
    ##  $ lag0_v2elreggov            : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2ellocgov            : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2ellocons            : num [1:8445] 35 35 36 36 37 37 38 38 39 39 ...
    ##  $ lag0_v2elrsthos            : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2elrstrct            : num [1:8445] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2psparban            : num [1:8445] 0.911 0.911 0.911 0.911 0.911 ...
    ##  $ lag0_v2psbars              : num [1:8445] 1.9 1.9 1.9 1.9 1.9 ...
    ##  $ lag0_v2psoppaut            : num [1:8445] 2.97 2.97 2.97 2.97 2.97 ...
    ##  $ lag0_v2psorgs              : num [1:8445] 1.96 1.96 1.96 1.96 1.96 1.96 1.96 1.96 1.96 1.96 ...
    ##  $ lag0_v2psprbrch            : num [1:8445] 2.04 2.04 2.04 2.04 2.04 ...
    ##  $ lag0_v2psprlnks            : num [1:8445] 1.28 1.28 1.28 1.28 1.28 ...
    ##  $ lag0_v2psplats             : num [1:8445] 3.28 3.28 3.28 3.28 3.28 ...
    ##  $ lag0_v2pscnslnl            : num [1:8445] 3.25 3.25 3.78 3.78 3.78 ...
    ##  $ lag0_v2pscohesv            : num [1:8445] -0.249 -0.249 -0.249 -0.249 -0.249 -0.249 -0.249 -0.249 -0.249 -0.249 ...
    ##  $ lag0_v2pscomprg            : num [1:8445] 1.19 1.19 1.19 1.19 1.19 ...
    ##  $ lag0_v2psnatpar            : num [1:8445] 2.524 0.097 0.006 0.006 0.006 ...
    ##  $ lag0_v2pssunpar            : num [1:8445] 1.27 1.27 1.27 1.27 1.27 ...
    ##  $ lag0_v2exremhsp            : num [1:8445] -0.572 -0.572 -0.572 -0.572 -0.572 -0.572 -0.572 -0.572 -0.572 -0.572 ...
    ##  $ lag0_v2exdfdshs            : num [1:8445] -3.17 -3.17 -3.17 -3.17 -3.17 ...
    ##  $ lag0_v2exdfcbhs            : num [1:8445] 0.159 0.159 0.159 0.159 0.159 0.159 0.159 0.159 0.159 0.159 ...
    ##   [list output truncated]

``` r
plotmiss(vdem_dat)
```

![](3-combine-data_files/figure-gfm/vdem-missplot-1.png)<!-- -->

There are a couple of new missing country-years from tails (GDR, South
Vietnam); fill those in with carry forward.

``` r
cy <- left_join(cy, vdem_dat, by = c("gwcode", "year")) %>%
  arrange(gwcode, year) %>%
  tidyr::fill(one_of(names(vdem_dat)), .direction = "down")
```

### State age

``` r
age_dat <- read_csv("../input/gwstate-age.csv") %>%
  filter(year <= END_YEAR) 
```

    ## Rows: 20061 Columns: 3

    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## dbl (3): gwcode, year, state_age

    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
age_lag <- END_YEAR - max(age_dat$year)
age_dat <- age_dat %>%
  mutate(year = year + age_lag) %>%
  setNames(c(names(.)[1:2], paste0("lag", age_lag, "_", names(.)[-c(1:2)])))

age_lag
```

    ## [1] 0

``` r
str(age_dat)
```

    ## spec_tbl_df [20,061 × 3] (S3: spec_tbl_df/tbl_df/tbl/data.frame)
    ##  $ gwcode        : num [1:20061] 2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year          : num [1:20061] 1816 1817 1818 1819 1820 ...
    ##  $ lag0_state_age: num [1:20061] 1 2 3 4 5 6 7 8 9 10 ...
    ##  - attr(*, "spec")=
    ##   .. cols(
    ##   ..   gwcode = col_double(),
    ##   ..   year = col_double(),
    ##   ..   state_age = col_double()
    ##   .. )
    ##  - attr(*, "problems")=<externalptr>

``` r
plotmiss(age_dat)
```

![](3-combine-data_files/figure-gfm/age-missplot-1.png)<!-- -->

All states in their last year of existence. Add 1 to previous state age.

``` r
cy <- left_join(cy, age_dat, by = c("gwcode", "year")) %>%
  arrange(gwcode, year) %>%
  group_by(gwcode) %>%
  mutate(lag0_state_age = case_when(
    is.na(lag0_state_age) ~ tail(lag(lag0_state_age, 1), 1) + 1L,
    TRUE ~ lag0_state_age
  )) %>%
  ungroup()
```

### Population

``` r
pop_dat <- read_csv("../input/population.csv") %>%
  filter(year <= END_YEAR) %>%
  mutate(log_pop = log(pop),
         pop = NULL)
```

    ## Rows: 20061 Columns: 3

    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## dbl (3): gwcode, year, pop

    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
pop_lag <- END_YEAR - max(pop_dat$year)
pop_dat$year <- pop_dat$year + pop_lag
colnames(pop_dat) <- prefix_lag(colnames(pop_dat), pop_lag)

pop_lag
```

    ## [1] 0

``` r
str(pop_dat)
```

    ## spec_tbl_df [20,061 × 3] (S3: spec_tbl_df/tbl_df/tbl/data.frame)
    ##  $ gwcode      : num [1:20061] 2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year        : num [1:20061] 1816 1817 1818 1819 1820 ...
    ##  $ lag0_log_pop: num [1:20061] 9.07 9.09 9.12 9.15 9.17 ...
    ##  - attr(*, "spec")=
    ##   .. cols(
    ##   ..   gwcode = col_double(),
    ##   ..   year = col_double(),
    ##   ..   pop = col_double()
    ##   .. )
    ##  - attr(*, "problems")=<externalptr>

``` r
plotmiss(pop_dat)
```

![](3-combine-data_files/figure-gfm/pop-missplot-1.png)<!-- -->

Check missing cases.

``` r
cy_temp <- left_join(cy, pop_dat, by = c("gwcode", "year"))
tbl <- filter(cy_temp, is.na(lag0_log_pop)) %>% 
  select(gwcode, year, lag0_log_pop)
tbl
```

    ## # A tibble: 0 × 3
    ## # … with 3 variables: gwcode <dbl>, year <dbl>, lag0_log_pop <dbl>

No missing cases.

``` r
if (nrow(tbl) > 0) {
  stop("Something has changed")
}

cy <- left_join(cy, pop_dat, by = c("gwcode", "year")) %>%
  arrange(gwcode, year) %>%
  tidyr::fill(contains("_pop"), .direction = "down")
```

``` r
plotmiss(pop_dat)
```

![](3-combine-data_files/figure-gfm/pop-missplot-2-1.png)<!-- -->

### Infant mortality

``` r
infmort <- read_csv("../input/wdi-infmort.csv") %>%
  filter(year <= END_YEAR) %>%
  select(gwcode, year, infmort, infmort_yearadj)
```

    ## Rows: 9481 Columns: 5

    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## dbl (4): gwcode, year, infmort, infmort_yearadj
    ## lgl (1): infmort_imputed

    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
infmort_lag <- END_YEAR - max(infmort$year)
infmort$year <- infmort$year + infmort_lag
colnames(infmort) <- prefix_lag(colnames(infmort), infmort_lag)

infmort_lag
```

    ## [1] 1

``` r
str(infmort)
```

    ## tibble [9,481 × 4] (S3: tbl_df/tbl/data.frame)
    ##  $ gwcode              : num [1:9481] 2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year                : num [1:9481] 1961 1962 1963 1964 1965 ...
    ##  $ lag1_infmort        : num [1:9481] 25.9 25.4 24.9 24.4 23.8 23.3 22.7 22 21.3 20.6 ...
    ##  $ lag1_infmort_yearadj: num [1:9481] -1.21 -1.21 -1.23 -1.22 -1.21 ...

Check missing cases.

``` r
cy_temp <- left_join(cy, infmort, by = c("gwcode", "year"))
cy_temp %>%
  select(gwcode, year, contains("infmort")) %>%
  summarize_missing()
```

    ## # A tibble: 43 × 3
    ##    gwcode years           n
    ##     <dbl> <chr>       <int>
    ##  1    115 1975 - 1975     1
    ##  2    315 1970 - 1992    23
    ##  3    316 1993 - 1993     1
    ##  4    317 1993 - 1993     1
    ##  5    340 2006 - 2006     1
    ##  6    341 2006 - 2006     1
    ##  7    343 1991 - 1991     1
    ##  8    344 1992 - 1992     1
    ##  9    346 1992 - 1992     1
    ## 10    347 2008 - 2008     1
    ## # … with 33 more rows

``` r
plotmiss(infmort)
```

![](3-combine-data_files/figure-gfm/infmort-missplot-1.png)<!-- -->

``` r
cy <- left_join(cy, infmort, by = c("gwcode", "year")) %>%
  arrange(gwcode, year) %>%
  tidyr::fill(contains("_infmort"), .direction = "up")
```

### GDP

``` r
gdp_dat <- read_csv("../input/gdp.csv") %>%
  filter(year <= END_YEAR) %>%
  dplyr::rename(gdp = NY.GDP.MKTP.KD,
                gdp_growth = NY.GDP.MKTP.KD.ZG,
                gdp_pc = NY.GDP.PCAP.KD,
                gdp_pc_growth = NY.GDP.PCAP.KD.ZG) %>%
  mutate(log_gdp = log(gdp),
         gdp = NULL,
         log_gdp_pc = log(gdp_pc),
         gdp_pc = NULL)
```

    ## Rows: 11400 Columns: 6

    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## dbl (6): gwcode, year, NY.GDP.MKTP.KD, NY.GDP.MKTP.KD.ZG, NY.GDP.PCAP.KD, NY...

    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
gdp_lag <- END_YEAR - max(gdp_dat$year)
gdp_dat$year <- gdp_dat$year + gdp_lag
colnames(gdp_dat) <- prefix_lag(colnames(gdp_dat), gdp_lag)

gdp_lag
```

    ## [1] 1

``` r
str(gdp_dat)
```

    ## spec_tbl_df [11,400 × 6] (S3: spec_tbl_df/tbl_df/tbl/data.frame)
    ##  $ gwcode            : num [1:11400] 2 20 40 41 42 70 90 91 92 93 ...
    ##  $ year              : num [1:11400] 1951 1951 1951 1951 1951 ...
    ##  $ lag1_gdp_growth   : num [1:11400] 3.942 5.669 0.933 3.071 0 ...
    ##  $ lag1_gdp_pc_growth: num [1:11400] 2.451 3.261 0.241 2.116 0 ...
    ##  $ lag1_log_gdp      : num [1:11400] 28.5 25.7 23.5 22.3 21.5 ...
    ##  $ lag1_log_gdp_pc   : num [1:11400] 9.61 9.28 7.94 7.36 6.81 ...
    ##  - attr(*, "spec")=
    ##   .. cols(
    ##   ..   gwcode = col_double(),
    ##   ..   year = col_double(),
    ##   ..   NY.GDP.MKTP.KD = col_double(),
    ##   ..   NY.GDP.MKTP.KD.ZG = col_double(),
    ##   ..   NY.GDP.PCAP.KD = col_double(),
    ##   ..   NY.GDP.PCAP.KD.ZG = col_double()
    ##   .. )
    ##  - attr(*, "problems")=<externalptr>

``` r
plotmiss(gdp_dat)
```

![](3-combine-data_files/figure-gfm/gdp-missplot-1.png)<!-- -->

Missing some first years due to lagging; fill them with first observed
value.

``` r
cy <- left_join(cy, gdp_dat, by = c("gwcode", "year")) %>%
  arrange(gwcode, year) %>%
  tidyr::fill(contains("_gdp"), .direction = "up")
```

### P&T Coups

``` r
coup_dat <- read_csv("../input/ptcoups.csv") %>%
  filter(year <= END_YEAR) %>%
  select(gwcode, year, years_since_last_pt_attempt)
```

    ## Rows: 11793 Columns: 20

    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## dbl (20): gwcode, year, pt_attempt, pt_attempt_num, pt_coup_num, pt_coup, pt...

    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
coup_lag <- END_YEAR - max(coup_dat$year)
coup_dat <- coup_dat %>%
  mutate(year = year + coup_lag) %>%
  setNames(c(names(.)[1:2], paste0("lag", coup_lag, "_", names(.)[-c(1:2)])))

coup_lag
```

    ## [1] 0

``` r
str(coup_dat)
```

    ## tibble [11,596 × 3] (S3: tbl_df/tbl/data.frame)
    ##  $ gwcode                          : num [1:11596] 2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year                            : num [1:11596] 1950 1951 1952 1953 1954 ...
    ##  $ lag0_years_since_last_pt_attempt: num [1:11596] 1 2 3 4 5 6 7 8 9 10 ...

``` r
plotmiss(coup_dat)
```

![](3-combine-data_files/figure-gfm/coup-missplot-1.png)<!-- -->

Missing some first years due to lagging; fill them with first observed
value.

``` r
cy_temp <- left_join(cy, coup_dat, by = c("gwcode", "year")) 
tbl <- filter(cy_temp, is.na(lag0_years_since_last_pt_attempt)) %>% select(gwcode, year)
tbl
```

    ## # A tibble: 0 × 2
    ## # … with 2 variables: gwcode <dbl>, year <dbl>

No missing cases.

``` r
if (nrow(tbl) > 0) {
  stop("Something has changed")
}

cy <- left_join(cy, coup_dat, by = c("gwcode", "year")) %>%
  arrange(gwcode, year) 
```

## Summarize and write final output

``` r
str(cy)
```

    ## tibble [8,187 × 225] (S3: tbl_df/tbl/data.frame)
    ##  $ gwcode                          : num [1:8187] 2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year                            : num [1:8187] 1970 1971 1972 1973 1974 ...
    ##  $ v2x_veracc_osp                  : num [1:8187] 0.865 0.866 0.862 0.863 0.872 0.888 0.903 0.906 0.906 0.906 ...
    ##  $ dv_v2x_veracc_osp_change        : chr [1:8187] "same" "same" "same" "same" ...
    ##  $ dv_v2x_veracc_osp_up_next2      : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ dv_v2x_veracc_osp_down_next2    : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ v2xcs_ccsi                      : num [1:8187] 0.921 0.921 0.921 0.921 0.921 0.921 0.921 0.921 0.921 0.921 ...
    ##  $ dv_v2xcs_ccsi_change            : chr [1:8187] "same" "same" "same" "same" ...
    ##  $ dv_v2xcs_ccsi_up_next2          : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ dv_v2xcs_ccsi_down_next2        : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ v2xcl_rol                       : num [1:8187] 0.919 0.929 0.934 0.934 0.935 0.941 0.946 0.947 0.946 0.95 ...
    ##  $ dv_v2xcl_rol_change             : chr [1:8187] "same" "same" "same" "same" ...
    ##  $ dv_v2xcl_rol_up_next2           : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ dv_v2xcl_rol_down_next2         : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ v2x_freexp_altinf               : num [1:8187] 0.902 0.878 0.902 0.928 0.936 0.937 0.951 0.944 0.953 0.953 ...
    ##  $ dv_v2x_freexp_altinf_change     : chr [1:8187] "same" "same" "same" "same" ...
    ##  $ dv_v2x_freexp_altinf_up_next2   : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ dv_v2x_freexp_altinf_down_next2 : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ v2x_horacc_osp                  : num [1:8187] 0.918 0.918 0.919 0.959 0.96 0.96 0.96 0.954 0.953 0.954 ...
    ##  $ dv_v2x_horacc_osp_change        : chr [1:8187] "same" "same" "same" "same" ...
    ##  $ dv_v2x_horacc_osp_up_next2      : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ dv_v2x_horacc_osp_down_next2    : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ v2x_pubcorr                     : num [1:8187] 0.96 0.948 0.948 0.948 0.948 0.948 0.948 0.948 0.948 0.948 ...
    ##  $ dv_v2x_pubcorr_change           : chr [1:8187] "same" "same" "same" "same" ...
    ##  $ dv_v2x_pubcorr_up_next2         : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ dv_v2x_pubcorr_down_next2       : int [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_is_leg                     : num [1:8187] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_is_elec                    : num [1:8187] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_is_election_year           : num [1:8187] 1 0 1 0 1 0 1 0 1 0 ...
    ##  $ lag0_v2x_polyarchy              : num [1:8187] 0.709 0.731 0.741 0.758 0.764 0.789 0.799 0.837 0.841 0.838 ...
    ##  $ lag0_v2x_liberal                : num [1:8187] 0.912 0.916 0.917 0.933 0.935 0.937 0.939 0.938 0.936 0.937 ...
    ##  $ lag0_v2xdl_delib                : num [1:8187] 0.906 0.906 0.906 0.908 0.908 0.937 0.956 0.961 0.964 0.964 ...
    ##  $ lag0_v2x_jucon                  : num [1:8187] 0.942 0.942 0.942 0.942 0.947 0.947 0.947 0.947 0.947 0.947 ...
    ##  $ lag0_v2x_frassoc_thick          : num [1:8187] 0.859 0.872 0.871 0.883 0.884 0.888 0.887 0.93 0.93 0.931 ...
    ##  $ lag0_v2xel_frefair              : num [1:8187] 0.73 0.785 0.784 0.779 0.781 0.824 0.83 0.859 0.859 0.858 ...
    ##  $ lag0_v2x_elecoff                : num [1:8187] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2xlg_legcon               : num [1:8187] 0.896 0.896 0.896 0.944 0.944 0.944 0.944 0.934 0.934 0.934 ...
    ##  $ lag0_v2x_partip                 : num [1:8187] 0.646 0.646 0.646 0.65 0.65 0.65 0.655 0.655 0.655 0.655 ...
    ##  $ lag0_v2x_cspart                 : num [1:8187] 0.942 0.942 0.942 0.951 0.951 0.954 0.969 0.969 0.969 0.969 ...
    ##  $ lag0_v2x_egal                   : num [1:8187] 0.75 0.744 0.744 0.752 0.752 0.747 0.743 0.741 0.741 0.741 ...
    ##  $ lag0_v2xeg_eqprotec             : num [1:8187] 0.853 0.853 0.853 0.853 0.853 0.853 0.853 0.852 0.852 0.852 ...
    ##  $ lag0_v2xeg_eqaccess             : num [1:8187] 0.762 0.762 0.762 0.774 0.774 0.769 0.769 0.769 0.769 0.769 ...
    ##  $ lag0_v2xeg_eqdr                 : num [1:8187] 0.672 0.659 0.659 0.677 0.677 0.677 0.674 0.674 0.674 0.674 ...
    ##  $ lag0_v2x_diagacc                : num [1:8187] 1.46 1.42 1.47 1.53 1.58 ...
    ##  $ lag0_v2xex_elecleg              : num [1:8187] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2x_civlib                 : num [1:8187] 0.901 0.896 0.904 0.91 0.912 0.919 0.925 0.927 0.929 0.931 ...
    ##  $ lag0_v2x_clphy                  : num [1:8187] 0.901 0.901 0.912 0.912 0.912 0.912 0.912 0.912 0.912 0.912 ...
    ##  $ lag0_v2x_clpol                  : num [1:8187] 0.931 0.912 0.925 0.94 0.949 0.951 0.959 0.964 0.969 0.969 ...
    ##  $ lag0_v2x_clpriv                 : num [1:8187] 0.885 0.893 0.893 0.893 0.893 0.91 0.916 0.923 0.92 0.927 ...
    ##  $ lag0_v2x_corr                   : num [1:8187] 0.073 0.076 0.076 0.076 0.076 0.059 0.059 0.059 0.059 0.059 ...
    ##  $ lag0_v2x_EDcomp_thick           : num [1:8187] 0.757 0.793 0.792 0.792 0.795 0.823 0.827 0.868 0.868 0.865 ...
    ##  $ lag0_v2x_elecreg                : num [1:8187] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2x_freexp                 : num [1:8187] 0.925 0.888 0.92 0.941 0.955 0.957 0.97 0.962 0.972 0.972 ...
    ##  $ lag0_v2x_gencl                  : num [1:8187] 0.828 0.841 0.841 0.841 0.841 0.862 0.898 0.898 0.898 0.909 ...
    ##  $ lag0_v2x_gencs                  : num [1:8187] 0.588 0.615 0.616 0.618 0.659 0.72 0.72 0.72 0.72 0.72 ...
    ##  $ lag0_v2x_hosabort               : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_hosinter               : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_rule                   : num [1:8187] 0.953 0.955 0.956 0.955 0.957 0.97 0.971 0.971 0.971 0.971 ...
    ##  $ lag0_v2xcl_acjst                : num [1:8187] 0.947 0.947 0.955 0.955 0.955 0.955 0.955 0.955 0.955 0.955 ...
    ##  $ lag0_v2xcl_disc                 : num [1:8187] 0.904 0.913 0.913 0.913 0.954 0.96 0.96 0.96 0.96 0.96 ...
    ##  $ lag0_v2xcl_dmove                : num [1:8187] 0.863 0.863 0.863 0.863 0.863 0.899 0.899 0.899 0.899 0.899 ...
    ##  $ lag0_v2xcl_prpty                : num [1:8187] 0.728 0.778 0.778 0.778 0.778 0.778 0.85 0.85 0.84 0.877 ...
    ##  $ lag0_v2xcl_slave                : num [1:8187] 0.785 0.794 0.794 0.794 0.794 0.794 0.794 0.794 0.794 0.794 ...
    ##  $ lag0_v2xel_elecparl             : num [1:8187] 1 0 1 0 1 0 1 0 1 0 ...
    ##  $ lag0_v2xel_elecpres             : num [1:8187] 0 0 1 0 0 0 1 0 0 0 ...
    ##  $ lag0_v2xex_elecreg              : num [1:8187] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2xlg_elecreg              : num [1:8187] 1 1 1 1 1 1 1 1 1 1 ...
    ##  $ lag0_v2ex_legconhog             : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2ex_legconhos             : num [1:8187] 0 0 0 0 1 1 1 0 0 0 ...
    ##  $ lag0_v2x_ex_confidence          : num [1:8187] 0 0 0 0 0 0 0 0 0 0.333 ...
    ##  $ lag0_v2x_ex_direlect            : num [1:8187] 1 1 1 1 0 0 0 1 1 1 ...
    ##  $ lag0_v2x_ex_hereditary          : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_ex_military            : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_ex_party               : num [1:8187] 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 ...
    ##  $ lag0_v2x_execorr                : num [1:8187] 0.092 0.092 0.092 0.092 0.092 0.028 0.028 0.028 0.028 0.028 ...
    ##  $ lag0_v2x_legabort               : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2xlg_leginter             : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2x_neopat                 : num [1:8187] 0.093 0.089 0.088 0.079 0.078 0.053 0.053 0.055 0.055 0.054 ...
    ##  $ lag0_v2xnp_client               : num [1:8187] 0.252 0.218 0.218 0.215 0.215 0.217 0.212 0.187 0.187 0.188 ...
    ##  $ lag0_v2xnp_pres                 : num [1:8187] 0.07 0.07 0.07 0.058 0.058 0.048 0.048 0.051 0.051 0.051 ...
    ##  $ lag0_v2xnp_regcorr              : num [1:8187] 0.086 0.086 0.086 0.086 0.086 0.036 0.036 0.036 0.036 0.036 ...
    ##  $ lag0_v2elvotbuy                 : num [1:8187] 1.03 1.03 1.02 1.02 1.02 ...
    ##  $ lag0_v2elfrcamp                 : num [1:8187] 0.597 0.597 0.584 0.584 0.679 0.679 0.651 0.651 0.674 0.674 ...
    ##  $ lag0_v2elpdcamp                 : num [1:8187] 1.82 1.82 1.8 1.8 1.8 ...
    ##  $ lag0_v2elpaidig                 : num [1:8187] 2.21 2.21 2.21 2.21 3.16 ...
    ##  $ lag0_v2elmonref                 : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2elmonden                 : num [1:8187] 0 0 0 0 0 0 0 0 0 0 ...
    ##  $ lag0_v2elrgstry                 : num [1:8187] 0.39 0.39 0.367 0.367 0.395 0.395 0.396 0.396 0.395 0.395 ...
    ##  $ lag0_v2elirreg                  : num [1:8187] 0.863 0.863 0.858 0.858 0.877 ...
    ##  $ lag0_v2elintim                  : num [1:8187] 1.26 1.26 1.38 1.38 1.39 ...
    ##  $ lag0_v2elpeace                  : num [1:8187] 1.15 1.15 1.21 1.21 1.22 ...
    ##  $ lag0_v2elfrfair                 : num [1:8187] 0.964 0.964 0.781 0.781 1.05 ...
    ##  $ lag0_v2elmulpar                 : num [1:8187] 1.55 1.55 1.55 1.55 1.55 ...
    ##  $ lag0_v2elboycot                 : num [1:8187] 1.3 1.3 1.3 1.3 1.33 ...
    ##  $ lag0_v2elaccept                 : num [1:8187] 1.45 1.45 1.45 1.45 1.44 ...
    ##  $ lag0_v2elasmoff                 : num [1:8187] 0.538 0.538 0.522 0.522 0.523 0.523 0.518 0.518 0.512 0.512 ...
    ##  $ lag0_v2eldonate                 : num [1:8187] 2.45 2.49 2.49 2.49 2.49 ...
    ##  $ lag0_v2elpubfin                 : num [1:8187] -1.94 -1.007 -1.007 -0.704 -0.502 ...
    ##  $ lag0_v2ellocumul                : num [1:8187] 36 36 37 37 38 38 39 39 40 40 ...
    ##   [list output truncated]

``` r
range(cy$year)
```

    ## [1] 1970 2021

``` r
length(unique(cy$gwcode))
```

    ## [1] 174

``` r
length(unique(cy$gwcode[cy$year==max(cy$year)]))
```

    ## [1] 169

Countries covered

``` r
coverage <- cy %>%
  pull(gwcode) %>%
  country_names(., shorten = TRUE) %>%
  unique() %>%
  sort() 

# write to file so changes are easier to see
write_csv(data.frame(country = coverage), "../output/country-coverage.csv")

coverage %>%
  paste0(collapse = "; ") %>%
  strwrap()
```

    ##  [1] "Afghanistan; Albania; Algeria; Angola; Argentina; Armenia; Australia;"  
    ##  [2] "Austria; Azerbaijan; Bangladesh; Barbados; Belarus; Belgium; Benin;"    
    ##  [3] "Bhutan; Bolivia; Bosnia-Herzegovina; Botswana; Brazil; Bulgaria;"       
    ##  [4] "Burkina Faso; Burundi; Cambodia; Cameroon; Canada; Cape Verde; CAR;"    
    ##  [5] "Chad; Chile; China; Colombia; Comoros; Congo; Costa Rica; Cote"         
    ##  [6] "D'Ivoire; Croatia; Cuba; Cyprus; Czech Republic; Czechoslovakia;"       
    ##  [7] "Denmark; Djibouti; Dominican Republic; DR Congo; East Timor; Ecuador;"  
    ##  [8] "Egypt; El Salvador; Equatorial Guinea; Eritrea; Estonia; Ethiopia;"     
    ##  [9] "Fiji; Finland; France; Gabon; Gambia; Georgia; German Democratic"       
    ## [10] "Republic; Germany; Ghana; Greece; Guatemala; Guinea; Guinea-Bissau;"    
    ## [11] "Guyana; Haiti; Honduras; Hungary; Iceland; India; Indonesia; Iran;"     
    ## [12] "Iraq; Ireland; Israel; Italy; Jamaica; Japan; Jordan; Kazakhstan;"      
    ## [13] "Kenya; Kosovo; Kuwait; Kyrgyzstan; Laos; Latvia; Lebanon; Lesotho;"     
    ## [14] "Liberia; Libya; Lithuania; Luxembourg; Madagascar; Malawi; Malaysia;"   
    ## [15] "Maldives; Mali; Mauritania; Mauritius; Mexico; Moldova; Mongolia;"      
    ## [16] "Montenegro; Morocco; Mozambique; Myanmar; Namibia; Nepal; Netherlands;" 
    ## [17] "New Zealand; Nicaragua; Niger; Nigeria; North Korea; North Macedonia;"  
    ## [18] "Norway; Oman; Pakistan; Panama; Papua New Guinea; Paraguay; Peru;"      
    ## [19] "Philippines; Poland; Portugal; Qatar; Romania; Russia; Rwanda; Saudi"   
    ## [20] "Arabia; Senegal; Serbia; Sierra Leone; Singapore; Slovakia; Slovenia;"  
    ## [21] "Solomon Islands; Somalia; South Africa; South Korea; South Sudan; South"
    ## [22] "Vietnam; South Yemen; Spain; Sri Lanka; Sudan; Surinam; Swaziland;"     
    ## [23] "Sweden; Switzerland; Syria; Taiwan; Tajikistan; Tanzania; Thailand;"    
    ## [24] "Togo; Trinidad and Tobago; Tunisia; Turkey; Turkmenistan; Uganda; UK;"  
    ## [25] "Ukraine; United Arab Emirates; Uruguay; USA; Uzbekistan; Venezuela;"    
    ## [26] "Vietnam; Yemen; Yugoslavia; Zambia; Zimbabwe"

Countries not covered

``` r
data("gwstates")
gwstates %>% 
  filter(start < "1970-01-01", end > "2019-01-01") %>%
  mutate(country_name = country_names(gwcode, shorten = TRUE)) %>%
  select(gwcode, country_name) %>%
  anti_join(cy, by = c("gwcode")) %>%
  pull(country_name) %>%
  unique() %>%
  sort() %>%
  paste0(collapse = "; ")
```

    ## [1] "Andorra; Liechtenstein; Malta; Monaco; Nauru; Samoa/Western Samoa; San Marino"

Keep track of variables as well (for git).

``` r
vars <- data.frame(Variables = names(cy))

# write to file so changes are easier to see
write_csv(vars, "../output/variables-in-dataset.csv")
```

General summary stats

``` r
library(yaml)
data_signature <- function(df) {
  out <- list()
  out$Class <- paste(class(df), collapse = ", ")
  out$Size_in_mem <- format(utils::object.size(df), "Mb")
  out$N_countries <- length(unique(df$gwcode))
  out$Years <- paste0(range(df$year, na.rm = TRUE), collapse = " - ")
  out$N_columns <- ncol(df)
  out$N_rows <- nrow(df)
  out$N_complete_rows <- sum(stats::complete.cases(df))
  out$Countries <- length(unique(df$gwcode))
  out$Missing <- lapply(df, function(x) sum(is.na(x)))
  out$Col_types <- lapply(df, function(x) typeof(x))
  out
}
sig <- data_signature(cy)

# Write both versioned and clean file name so that:
# - easy to see changes on git with clean file name
# - concise historical record with versioned file name
write_yaml(sig, sprintf("../output/states-%s-signature.yml",
                        VERSION))
write_yaml(sig, "../output/states-signature.yml")
```

### Record missing cases

``` r
plotmiss(cy)
```

![](3-combine-data_files/figure-gfm/final-missplot-1.png)<!-- -->

Write all incomplete cases to a CSV so changes introduced by something
in one of the input datasets is easier to notice:

``` r
format_years <- function(x) {
  if (length(x) > 1) {
    return(paste(range(x), collapse = " - "))
  }
  as.character(x)
}

incomplete_cases <- cy %>%
  gather(var, value, -gwcode, -year) %>%
  filter(is.na(value)) %>%
  # disregard missing DV values for last 2 years
  filter(!(substr(var, 1, 3)=="dv_" & year %in% (max(year) + c(-1, 0)))) %>%
  group_by(gwcode, year, var) %>%
  summarize() %>%
  # summarize which vars are missing
  group_by(gwcode, year) %>%
  summarize(missing_values_in = paste0(var, collapse = ", ")) 
```

    ## `summarise()` has grouped output by 'gwcode', 'year'. You can override using the `.groups` argument.

    ## `summarise()` has grouped output by 'gwcode'. You can override using the `.groups` argument.

``` r
# if there are no missing cases, stop; otherwise 
# add in year sequences ID so we can collapse adjacent years with same 
# missing var
if (nrow(incomplete_cases) > 0) {
  incomplete_cases <- incomplete_cases %>%
    group_by(gwcode) %>%
    arrange(year) %>%
    mutate(yr_id = id_date_sequence(year)) %>%
    group_by(gwcode, yr_id, missing_values_in) %>%
    summarize(year = format_years(year)) %>%
    # clean up
    ungroup() %>%
    select(gwcode, year, missing_values_in) %>%
    arrange(year, gwcode)
}

write_csv(incomplete_cases, "../output/incomplete-cases.csv")
```

### Missing values by column

``` r
sapply(cy, function(x) sum(is.na(x))) %>%
  as.list() %>%
  tibble::enframe(name = "Variable", value = "Missing") %>%
  unnest(Missing) %>%
  filter(Missing > 0) %>%
  knitr::kable()
```

| Variable                        | Missing |
|:--------------------------------|--------:|
| dv_v2x_veracc_osp_up_next2      |     338 |
| dv_v2x_veracc_osp_down_next2    |     338 |
| dv_v2xcs_ccsi_up_next2          |     338 |
| dv_v2xcs_ccsi_down_next2        |     338 |
| dv_v2xcl_rol_up_next2           |     338 |
| dv_v2xcl_rol_down_next2         |     338 |
| dv_v2x_freexp_altinf_up_next2   |     338 |
| dv_v2x_freexp_altinf_down_next2 |     338 |
| dv_v2x_horacc_osp_up_next2      |     338 |
| dv_v2x_horacc_osp_down_next2    |     338 |
| dv_v2x_pubcorr_up_next2         |     338 |
| dv_v2x_pubcorr_down_next2       |     338 |

## Done, save

``` r
fn <- sprintf("../output/states-%s.rds", VERSION)
cat("Saving data as %s", basename(fn))
```

    ## Saving data as %s states-v12.rds

``` r
write_rds(cy, fn)
```
