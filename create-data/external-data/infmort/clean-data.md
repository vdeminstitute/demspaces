WDI Infant mortality
================

  - [Functions / packages](#functions-packages)
  - [Get raw data](#get-raw-data)
  - [Clean raw data](#clean-raw-data)
      - [Lag data](#lag-data)
      - [Normalize to G\&W statelist](#normalize-to-gw-statelist)
  - [Handle missing values](#handle-missing-values)
      - [Carry-back impute lag-induced missing
        data](#carry-back-impute-lag-induced-missing-data)
      - [Check remaining missing
        values](#check-remaining-missing-values)
      - [Find imputation model](#find-imputation-model)
  - [Add year-normalized version](#add-year-normalized-version)
  - [Done, save](#done-save)

*Last updated on 02 March 2021*

Note that places that require attention during data updates are marked
with *UPDATE:*

This script gets updated infant mortality data from the World Bank’s
World Development Indicators using the WDI package. It will then do some
pretty aggressive imputations for countries that are missing early parts
of a series. The goal is to impute defensively, i.e. if someone looks at
a series with imputed values, they look reasonable. The goal is *not* to
capture in some way imputation variance/uncertainty.

## Functions / packages

``` r
library(WDI)
library(tidyverse)
```

    ## ── Attaching packages ─────────────────────────────────────── tidyverse 1.3.0 ──

    ## ✓ ggplot2 3.3.3     ✓ purrr   0.3.4
    ## ✓ tibble  3.0.6     ✓ dplyr   1.0.4
    ## ✓ tidyr   1.1.2     ✓ stringr 1.4.0
    ## ✓ readr   1.4.0     ✓ forcats 0.5.1

    ## ── Conflicts ────────────────────────────────────────── tidyverse_conflicts() ──
    ## x dplyr::filter() masks stats::filter()
    ## x dplyr::lag()    masks stats::lag()

``` r
library(states)
```

    ## 
    ## Attaching package: 'states'

    ## The following object is masked from 'package:readr':
    ## 
    ##     parse_date

``` r
library(lubridate)
```

    ## 
    ## Attaching package: 'lubridate'

    ## The following objects are masked from 'package:base':
    ## 
    ##     date, intersect, setdiff, union

``` r
library(stringr)

wdi_to_gw <- function(x, iso2c = "iso2c", country = "country", year = "year") {
  
  # In case the ID columns don't match the WDI default, create them here. 
  # dplyr is easier to use when we can refer to these columns directly
  x$iso2c   <- x[[iso2c]]
  x$country <- x[[country]]
  x$year    <- x[[year]]
  
  # remove non-state entities, i.e. regions and aggregates
  notstate <- c("1A", "1W", "4E", "7E", "8S", "B8", "F1", "S1", "S2", "S3", "S4",
                "T2", "T3", "T4", "T5", "T6", "T7", "V1", "V2", "V3", "V4", "Z4",
                "Z7", "EU", "OE", "XC", "XD", "XE", "XF", "XG", "XH", "XI", "XJ",
                "XL", "XM", "XN", "XO", "XP", "XQ", "XT", "XU", "XY", "ZF", "ZG",
                "ZJ", "ZQ", "ZT")
  x <- x %>%
    dplyr::filter(!iso2c %in% notstate) 
  
  # first pass G&W country code coding
  x$gwcode <- suppressWarnings(countrycode::countrycode(x[["iso2c"]], "iso2c", "gwn"))
  x$gwcode <- as.integer(x$gwcode)

  # this misses some countries; first the fixed, non-year-varying, cases
  x <- x %>%
    mutate(
      gwcode = case_when(
        iso2c=="AD" ~ 232L,
        iso2c=="XK" ~ 347L,
        country=="Namibia" ~ 565L,
        iso2c=="VN" ~ 816L,  # countrycode uses 817, South Vietnam for this
        iso2c=="YE" ~ 678L,  # Yemen
        TRUE ~ gwcode
      )
    )

  # Fix Serbia/Yugoslavia
  # Right now all coded as 340, but in G&W 345 (Yugo) ends in 2006 and 
  # 340 (Serbia) starts
  serbia2006 <- x[x$gwcode==340 & x$year==2006 & !is.na(x$gwcode), ]
  yugo_idx <- x$gwcode==340 & x$year < 2007 & !is.na(x$gwcode)
  x$gwcode[yugo_idx]  <- 345
  x$iso2c[yugo_idx]   <- "YU"
  x$country[yugo_idx] <- "Yugoslavia/Serbia & Montenegro"
  x <- bind_rows(x, serbia2006) %>%
    arrange(gwcode, iso2c, country, year)
  
  x
}


# I'm going to use this function to impute missing values; see below for more details and the choice of a log-linear model
impute_ts_loglinear <- function(x) {
  # This is only meant to work for leading NAs; check to make sure this is 
  # the case. 
  xna <- is.na(x)
  # if all NA's are leading sequence, they are all preceded by NA as well
  stopifnot(!any(xna==TRUE & c(TRUE, head(stats::lag(xna), -1))==FALSE))
  
  if (all(is.na(x))) {
    return(x)
  }
  xx <- seq_along(x)
  mdl <- try(glm(x ~ xx, data = NULL, family = gaussian(link = "log")), silent = TRUE)
  if (inherits(mdl, "try-error")) {
    return(x)
  }
  xhat <- predict(mdl, newdata = list(xx = xx), type = "response")
  
  # Use the first overlapping point to shift xhat so the lines "connect" instead
  # of having a sudden jump
  pt <- min(which(!xna))
  shift <- x[pt] - xhat[pt]
  xhat  <- xhat + shift
  
  # drop in imputed values
  x[xna] <- xhat[xna]
  x
}

impute_ts_sqrt <- function(x) {
  # This is only meant to work for leading NAs; check to make sure this is 
  # the case. 
  xna <- is.na(x)
  # if all NA's are leading sequence, they are all preceded by NA as well
  stopifnot(!any(xna==TRUE & c(TRUE, head(stats::lag(xna), -1))==FALSE))
  
  if (all(is.na(x))) {
    return(x)
  }
  xx <- seq_along(x)
  mdl <- try(glm(sqrt(x) ~ xx, data = NULL, family = gaussian(link = "identity")), silent = TRUE)
  if (inherits(mdl, "try-error")) {
    return(x)
  }
  xhat <- predict(mdl, newdata = list(xx = xx), type = "response")^2
  
  # Use the first overlapping point to shift xhat so the lines "connect" instead
  # of having a sudden jump
  pt <- min(which(!xna))
  shift <- x[pt] - xhat[pt]
  xhat  <- xhat + shift
  
  # drop in imputed values
  x[xna] <- xhat[xna]
  x
}

# check how this works
x <- c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 
       89.3, 85.1, 81.1, 77.2, 73.5, 70.1, 66.9, 63.9, 61.1, 58.6, 56.2, 
       54.1, 52.1, 50.2, 48.5, 47, 45.8, 44.7, 44.1, 44, 44.4, 45.2, 
       45.9, 46.8, 47.8, 48.4, 49, 49.4, 50, 50.9, 50.8, 49.7, 48.1, 
       45.5, 42.9, 40.3, 38.2, 36.6, 35.3, 34.1, 32.9, 31.4, 30.7, 29.6, 
       28.5)
plot(x, type = "l", ylim = c(0, 150))
lines(impute_ts_loglinear(x)[1:16], col = "red")
```

![](clean-data_files/figure-gfm/unnamed-chunk-1-1.png)<!-- -->

## Get raw data

Download the raw source data. Since this takes a while, this will only
raw if a copy of the source data is not present in the input folder.

*UPDATE: To trigger and update, delete the raw data input file or
manually run this chunk.*

``` r
if (!file.exists("input/infmort.csv")) {
  raw <- WDI(indicator = "SP.DYN.IMRT.IN", country = "all", start = 1960, 
           end = year(today()), extra = FALSE)
  write_csv(raw, "input/infmort.csv")
}
```

## Clean raw data

``` r
raw <- read_csv("input/infmort.csv")
```

    ## 
    ## ── Column specification ────────────────────────────────────────────────────────
    ## cols(
    ##   iso2c = col_character(),
    ##   country = col_character(),
    ##   SP.DYN.IMRT.IN = col_double(),
    ##   year = col_double()
    ## )

``` r
# UPDATE: check this is still the case
# In the raw data all values for 2020 are missing; drop that year from the data
last_year <- filter(raw, year==max(year))
stopifnot(all(is.na(last_year[["SP.DYN.IMRT.IN"]])))
raw <- filter(raw, year!=max(year))

# convert to G&W system
wdi <- raw %>%
  rename(infmort = SP.DYN.IMRT.IN) %>%
  wdi_to_gw(.) %>%
  arrange(gwcode, year)

# Some minor countries don't have G&W codes
nogwcode <- wdi %>%
  filter(is.na(gwcode)) %>%
  group_by(iso2c, country) %>%
  count() 
write_csv(nogwcode, "output/missing-gwcode.csv")
knitr::kable(nogwcode)
```

| iso2c | country                        |  n |
| :---- | :----------------------------- | -: |
| AG    | Antigua and Barbuda            | 60 |
| AS    | American Samoa                 | 60 |
| AW    | Aruba                          | 60 |
| BM    | Bermuda                        | 60 |
| CW    | Curacao                        | 60 |
| DM    | Dominica                       | 60 |
| FM    | Micronesia, Fed. Sts.          | 60 |
| FO    | Faroe Islands                  | 60 |
| GD    | Grenada                        | 60 |
| GI    | Gibraltar                      | 60 |
| GL    | Greenland                      | 60 |
| GU    | Guam                           | 60 |
| HK    | Hong Kong SAR, China           | 60 |
| IM    | Isle of Man                    | 60 |
| JG    | Channel Islands                | 60 |
| KI    | Kiribati                       | 60 |
| KN    | St. Kitts and Nevis            | 60 |
| KY    | Cayman Islands                 | 60 |
| LC    | St. Lucia                      | 60 |
| LI    | Liechtenstein                  | 60 |
| MC    | Monaco                         | 60 |
| MF    | St. Martin (French part)       | 60 |
| MH    | Marshall Islands               | 60 |
| MO    | Macao SAR, China               | 60 |
| MP    | Northern Mariana Islands       | 60 |
| NC    | New Caledonia                  | 60 |
| NR    | Nauru                          | 60 |
| PF    | French Polynesia               | 60 |
| PR    | Puerto Rico                    | 60 |
| PS    | West Bank and Gaza             | 60 |
| PW    | Palau                          | 60 |
| SC    | Seychelles                     | 60 |
| SM    | San Marino                     | 60 |
| ST    | Sao Tome and Principe          | 60 |
| SX    | Sint Maarten (Dutch part)      | 60 |
| TC    | Turks and Caicos Islands       | 60 |
| TO    | Tonga                          | 60 |
| TV    | Tuvalu                         | 60 |
| VC    | St. Vincent and the Grenadines | 60 |
| VG    | British Virgin Islands         | 60 |
| VI    | Virgin Islands (U.S.)          | 60 |
| VU    | Vanuatu                        | 60 |
| WS    | Samoa                          | 60 |

``` r
# Take those out
wdi <- wdi %>%
  dplyr::filter(!is.na(gwcode))
```

### Lag data

*UPDATE: make sure the lagging is still correct*

Lag the data before we check for and if possible impute missing values
because the lagging will introduce missingness as well.

``` r
wdi$year <- wdi$year + 1
range(wdi$year)
```

    ## [1] 1961 2020

### Normalize to G\&W statelist

``` r
# Add in missing cases from G&W state list and drop excess country-years not 
# in G&W list (left join)
statelist <- state_panel(1960,  # this cannot be min(year) because we lagged above
                         max(wdi$year), partial = "any")
wdi <- left_join(statelist, wdi, by = c("gwcode", "year")) %>%
  arrange(gwcode, year)
```

\*TODO: this join will take out some excess years for situations where
WDI is missing data for a country like Czechoslovakia that later split
into several different countries, and for which it does have data. In
principle it might be possible to reconstruct mortality estimates for
Czechoslovakia, the USSR, Yugoslavia, Sudan, etc. but this is a lot of
work, so ¯\_(ツ)\_/¯\*

## Handle missing values

The rest of this script deals with identifying and potentially imputing
missing values.

``` r
# Are any years completely missing?
missing_year <- wdi %>%
  group_by(year) %>%
  summarize(n = n(), missing = sum(infmort)) %>%
  filter(n==missing) 
write_csv(missing_year, "output/missing-all-year.csv")
missing_year %>%
  knitr::kable()
```

| year | n | missing |
| ---: | -: | ------: |

``` r
# This should not be the case since we lagged the data
stopifnot(nrow(missing_year)==0)

# Are any countries completely missing?
missing_country <- wdi %>%
  group_by(gwcode) %>%
  summarize(n = n(), 
            missing = sum(is.na(infmort))) %>%
  mutate(country = country_names(gwcode, shorten = TRUE)) %>%
  filter(n==missing) %>%
  select(gwcode, country, n)
write_csv(missing_country, "output/missing-all-country.csv")
missing_country %>%
  knitr::kable()
```

| gwcode | country                    |  n |
| -----: | :------------------------- | -: |
|     54 | Dominica                   | 43 |
|     55 | Grenada                    | 47 |
|     56 | Saint Lucia                | 42 |
|     57 | Saint Vincent              | 42 |
|     58 | Antigua & Barbuda          | 40 |
|     60 | Saint Kitts and Nevis      | 38 |
|    221 | Monaco                     | 61 |
|    223 | Liechtenstein              | 61 |
|    265 | German Democratic Republic | 31 |
|    315 | Czechoslovakia             | 33 |
|    331 | San Marino                 | 61 |
|    347 | Kosovo                     | 13 |
|    396 | Abkhazia                   | 13 |
|    397 | South Ossetia              | 13 |
|    403 | Sao Tome and Principe      | 46 |
|    511 | Zanzibar                   |  2 |
|    591 | Seychelles                 | 45 |
|    680 | South Yemen                | 24 |
|    713 | Taiwan                     | 61 |
|    817 | South Vietnam              | 16 |
|    935 | Vanuatu                    | 41 |
|    970 | Kiribati                   | 42 |
|    971 | Nauru                      | 53 |
|    972 | Tonga                      | 51 |
|    973 | Tuvalu                     | 43 |
|    983 | Marshall Islands           | 35 |
|    986 | Palau                      | 27 |
|    987 | Micronesia                 | 35 |
|    990 | Samoa/Western Samoa        | 59 |

``` r
# Take out countries missing all values
wdi <- wdi %>% 
  dplyr::filter(!gwcode %in% missing_country[["gwcode"]])
```

### Carry-back impute lag-induced missing data

Because we lagged the data, countries will have missing values in 1960
or their first year of independence, if it was after 1960. Use the 1960
or independence year value to impute, i.e. carry back impute thoses
cases.

``` r
# Countries that gained indy in 1960 or later
data(gwstates)
indy <- gwstates %>% 
  # some states are present more than 1 time if they had interrupted indy; only
  # use last period
  arrange(gwcode) %>%
  group_by(gwcode) %>% 
  slice(n()) %>%
  mutate(syear = lubridate::year(start)) %>%
  select(gwcode, syear)
stopifnot(nrow(indy)==length(unique(indy$gwcode)))

wdi <- wdi %>%
  left_join(indy, by = "gwcode") %>%
  group_by(gwcode) %>%
  arrange(gwcode, year) %>%
  mutate(infmort2 = case_when(
    (is.na(infmort) & year>=syear) ~ lead(infmort, n = 1)[1],
    TRUE ~ infmort
  ))

# I add the imputed values as second column to allow comparison, if one wants
# to do that at this point. 
sum(is.na(wdi$infmort))
```

    ## [1] 515

``` r
sum(is.na(wdi$infmort2))
```

    ## [1] 438

``` r
wdi <- wdi %>%
  mutate(infmort = infmort2, infmort2 = NULL)
```

### Check remaining missing values

``` r
missing <- wdi %>%
  # Track the original N for a country before focusing only on missing cases
  group_by(gwcode) %>%
  dplyr::mutate(N = n()) %>%
  filter(is.na(infmort)) %>%
  # Right now this is country-year; turn this into a more readable form by 
  # collapsing accross consecutive year spells
  # First, code consecutive year spells
  group_by(gwcode) %>%
  arrange(year) %>%
  dplyr::mutate(year = as.integer(year),
                id = id_date_sequence(year)) %>%
  # Collapse over years
  dplyr::group_by(gwcode, id) %>%
  dplyr::summarize(N = unique(N), 
                   N_miss = n(),
                   Frac_miss = N_miss/N,
                   years = paste0(range(year), collapse = " - "),
                   .groups = "drop") %>%
  select(-id) %>%
  arrange(desc(Frac_miss), gwcode)

missing %>% 
  knitr::kable(digits = 2)
```

| gwcode |  N | N\_miss | Frac\_miss | years       |
| -----: | -: | ------: | ---------: | :---------- |
|    345 | 47 |      25 |       0.53 | 1960 - 1984 |
|    232 | 61 |      26 |       0.43 | 1960 - 1985 |
|    731 | 61 |      26 |       0.43 | 1960 - 1985 |
|    520 | 61 |      23 |       0.38 | 1960 - 1982 |
|    339 | 61 |      19 |       0.31 | 1960 - 1978 |
|    481 | 61 |      19 |       0.31 | 1960 - 1978 |
|    712 | 61 |      19 |       0.31 | 1960 - 1978 |
|    812 | 61 |      19 |       0.31 | 1960 - 1978 |
|    411 | 53 |      15 |       0.28 | 1968 - 1982 |
|    811 | 61 |      16 |       0.26 | 1960 - 1975 |
|    404 | 47 |      12 |       0.26 | 1974 - 1985 |
|    230 | 61 |      15 |       0.25 | 1960 - 1974 |
|    560 | 61 |      15 |       0.25 | 1960 - 1974 |
|    483 | 61 |      13 |       0.21 | 1960 - 1972 |
|    670 | 61 |      13 |       0.21 | 1960 - 1972 |
|    352 | 61 |      12 |       0.20 | 1960 - 1971 |
|    630 | 61 |      12 |       0.20 | 1960 - 1971 |
|    115 | 46 |       9 |       0.20 | 1975 - 1983 |
|    365 | 61 |      11 |       0.18 | 1960 - 1970 |
|    160 | 61 |      10 |       0.16 | 1960 - 1969 |
|    490 | 61 |      10 |       0.16 | 1960 - 1969 |
|    710 | 61 |      10 |       0.16 | 1960 - 1969 |
|    760 | 61 |      10 |       0.16 | 1960 - 1969 |
|    260 | 61 |       9 |       0.15 | 1960 - 1968 |
|    580 | 61 |       9 |       0.15 | 1960 - 1968 |
|    775 | 61 |       9 |       0.15 | 1960 - 1968 |
|    436 | 61 |       8 |       0.13 | 1960 - 1967 |
|    540 | 46 |       6 |       0.13 | 1975 - 1980 |
|    530 | 61 |       7 |       0.11 | 1960 - 1966 |
|    475 | 61 |       5 |       0.08 | 1960 - 1964 |
|    816 | 61 |       5 |       0.08 | 1960 - 1964 |
|    432 | 61 |       4 |       0.07 | 1960 - 1963 |
|    516 | 59 |       3 |       0.05 | 1962 - 1964 |
|    616 | 61 |       3 |       0.05 | 1960 - 1962 |
|    678 | 61 |       3 |       0.05 | 1960 - 1962 |
|    698 | 61 |       3 |       0.05 | 1960 - 1962 |
|    700 | 61 |       3 |       0.05 | 1960 - 1962 |
|    553 | 57 |       2 |       0.04 | 1964 - 1965 |

``` r
# add an indicator if series is incomplete 
wdi <- wdi %>%
  mutate(has_missing = gwcode %in% missing$gwcode)
```

These are all missing values at the front of the series.

### Find imputation model

The series overall look like the might be reasonably linear under some
scale transformation like log or square root.

``` r
ggplot(wdi, aes(x = year, y = infmort, group = gwcode, 
                color = has_missing)) +
  geom_line(alpha = 0.5) +
  theme_light()
```

    ## Warning: Removed 438 row(s) containing missing values (geom_path).

![](clean-data_files/figure-gfm/unnamed-chunk-8-1.png)<!-- -->

Compare log-linear and square root linear models.

``` r
fit <- wdi %>%
  group_by(gwcode, has_missing) %>%
  nest() %>%
  mutate(
    mdl_log = map(data, ~lm(log(infmort) ~ year, data = .)),
    mdl_sqrt = map(data, ~lm(sqrt(infmort) ~ year, data = .)),
    mdl_mix  = map(data, ~lm((infmort)^(0.42) ~ year, data = .))
  ) %>%
  gather(model, fit, starts_with("mdl")) %>%
  mutate(r2 = map_dbl(fit, ~summary(.)$r.squared))

# Bin the fit by R^2 and model
table(fit$model, cut(fit$r2, c(0, .4, .5, .6, .7, .8, .9, 1)))
```

    ##           
    ##            (0,0.4] (0.4,0.5] (0.5,0.6] (0.6,0.7] (0.7,0.8] (0.8,0.9] (0.9,1]
    ##   mdl_log        0         1         2         1         5        12     153
    ##   mdl_mix        0         2         1         1         4        20     146
    ##   mdl_sqrt       0         2         1         1         5        22     143

``` r
fit %>% 
  group_by(model, has_missing) %>%
  summarize(countries = n(),
            mean_r2 = round(mean(r2), 2),
            median_r2 = round(median(r2), 2)) %>%
  arrange(has_missing, mean_r2)
```

    ## `summarise()` has grouped output by 'model'. You can override using the `.groups` argument.

    ## # A tibble: 6 x 5
    ## # Groups:   model [3]
    ##   model    has_missing countries mean_r2 median_r2
    ##   <chr>    <lgl>           <int>   <dbl>     <dbl>
    ## 1 mdl_mix  FALSE             136    0.94      0.96
    ## 2 mdl_sqrt FALSE             136    0.94      0.96
    ## 3 mdl_log  FALSE             136    0.95      0.97
    ## 4 mdl_sqrt TRUE               38    0.93      0.96
    ## 5 mdl_log  TRUE               38    0.94      0.97
    ## 6 mdl_mix  TRUE               38    0.94      0.96

If a model is not performing well on a series where we are not looking
to impute, who cares. Look at low R2 models for series we are looking to
impute.

``` r
check_gwcodes <- fit %>% 
  filter(model!="mdl_lm", r2 < 0.9, has_missing) %>% 
  pull(gwcode) %>% 
  unique()
bad_fit <- fit %>%
  filter(gwcode %in% check_gwcodes, model!="mdl_lm") 
nn <- nrow(bad_fit)/3
wdi %>%
  filter(gwcode %in% check_gwcodes) %>%
  mutate(syear = ifelse(syear<1960, 1960, syear)) %>%
  ggplot(.) +
  facet_wrap(~ gwcode) +
  geom_line(aes(x = year, y = infmort, group = gwcode)) +
  # mark how far back we need to impute
  geom_vline(aes(xintercept = syear)) +
  geom_text(
    data = bad_fit, 
    x = 1980, 
    y = c(rep(50, nn), rep(100, nn), rep(150, nn)), 
    aes(label = paste0(
      c(rep("Log-linear: ", nn), rep("Quadratic: ", nn), 
      rep("Mixed: ", nn)),
      round(r2, 2))
    )
  ) +
  stat_smooth(aes(x = year, y = infmort, color = "red"),
              method = "glm", 
              formula = y ~ x, 
              method.args = list(family = gaussian(link = "log"))) +
  stat_smooth(aes(x = year, y = infmort, color = "blue"),
              method = "lm",
              formula = y ~ poly(x, 2)) +
  scale_color_manual("Model", values = c("red" = "red", "blue" = "blue"), 
                     labels = c("blue" = "Quadratic", "red" = "Log-linear")) +
  theme_light()
```

    ## Warning: Removed 99 rows containing non-finite values (stat_smooth).
    
    ## Warning: Removed 99 rows containing non-finite values (stat_smooth).

    ## Warning: Removed 99 row(s) containing missing values (geom_path).

![](clean-data_files/figure-gfm/unnamed-chunk-10-1.png)<!-- -->

The log-lienar and square root models both perform about equally well.
What do the imputed values look like?

``` r
wdi <- wdi %>%
  group_by(gwcode) %>%
  arrange(gwcode, year) %>%
  mutate(infmort_imputed = is.na(infmort),
         infmort_log     = impute_ts_loglinear(infmort),
         infmort_sqrt    = impute_ts_sqrt(infmort))

# Visualize results
highlight <- wdi %>% 
  filter(has_missing) %>%
  select(gwcode, year, infmort_imputed, infmort_log, infmort_sqrt) %>%
  pivot_longer(infmort_log:infmort_sqrt) %>%
  mutate(color = case_when(
    infmort_imputed==FALSE ~ "Observed",
    infmort_imputed==TRUE & name=="infmort_log" ~ "Log",
    infmort_imputed==TRUE & name=="infmort_sqrt" ~ "Sqrt",
    TRUE ~ "what?"
  ))
ggplot(wdi, aes(x = year)) +
  geom_line(aes(y = infmort, group = gwcode), alpha = 0.2) +
  geom_line(data = highlight,
            aes(y = value, group = interaction(gwcode, name), color = color)) +
  scale_color_manual(values = c("Observed" = "gray20", "Log" = "red", "Sqrt" = "blue")) +
  theme_light()
```

    ## Warning: Removed 438 row(s) containing missing values (geom_path).

![](clean-data_files/figure-gfm/unnamed-chunk-11-1.png)<!-- -->

The square root model’s imputed values are less aggressive in their
extrapolation so I will pick that.

``` r
wdi <- wdi %>%
  mutate(infmort = infmort_sqrt,
         infmort_log = NULL)
```

Now all the countries we have not dropped should have full series / no
missing values.

``` r
tbl <- wdi %>%
  group_by(gwcode) %>%
  summarize(n_miss = sum(is.na(infmort))) %>%
  ungroup() %>%
  filter(n_miss > 0)
if (nrow(tbl) > 0) stop("Still some missing values remaining", call. = FALSE)
```

## Add year-normalized version

This adjusts each countries value for a year with the mean value of
infant mortality across all countries in that year. So it is essentially
a country’s relative level of infant mortality given the standards of
the time.

``` r
wdi <- wdi %>%
  group_by(year) %>%
  mutate(infmort_yearadj = (infmort - mean(infmort))/sd(infmort)) %>%
  ungroup()
```

## Done, save

``` r
wdi <- wdi %>% 
  ungroup() %>%
  select(gwcode, year, infmort, infmort_yearadj, infmort_imputed) %>%
  # UPDATE: make sure it's clear these are lagged (if they are)
  rename(lag1_infmort = infmort, lag1_infmort_yearadj = infmort_yearadj,
         lag1_infmort_imputed = infmort_imputed)
write_csv(wdi, file = "output/wdi-infmort.csv")
```
