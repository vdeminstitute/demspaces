Combined GDP data
================

GDP data from 1950 on, mostly based on WDI, with some gaps filled with KSG's extended GDP data and data from the UN.

Four step imputation procedure:

1.  Acquire the WDI data
2.  Where WDI is missing, drop in UN GDP figures, scaled by a linear model.
3.  Where WDI is missing, drop in KSG figures, scaled by a log-linear country-varying scaling model.
4.  Model-based extrapolation: use Kalman-smoothing to forward extrapolate missing GDP values (most notably Taiwan and several countries missing current year GDP values) and backward extrapolate GDP growth in first year of existences of a country.

Usage
-----

``` r
suppressPackageStartupMessages({
  library("dplyr")
  library("readr")
  library("WDI")
  library("states")
  library("lubridate")
  library("countrycode")
  library("lme4")
  library("imputeTS")
  library("forecast")
  
  # for plot examples below
  library("ggplot2")
  library("tidyr")
})

source("gdp.R")

example <- gdp_api(impute = TRUE)
```

    ## Parsed with column specification:
    ## cols(
    ##   gwcode = col_double(),
    ##   year = col_double(),
    ##   pop = col_double()
    ## )

    ## Warning in checkConv(attr(opt, "derivs"), opt$par, ctrl =
    ## control$checkConv, : Model failed to converge with max|grad| = 0.0178806
    ## (tol = 0.002, component 1)

    ## Warning in StructTS(data, ...): possible convergence problem: 'optim' gave
    ## code = 52 and message 'ERROR: ABNORMAL_TERMINATION_IN_LNSRCH'

``` r
str(example)
```

    ## Classes 'tbl_df', 'tbl' and 'data.frame':    10809 obs. of  6 variables:
    ##  $ gwcode           : num  2 20 40 41 42 70 90 91 92 93 ...
    ##  $ year             : int  1950 1950 1950 1950 1950 1950 1950 1950 1950 1950 ...
    ##  $ NY.GDP.MKTP.KD   : num  2.19e+12 1.95e+11 1.40e+10 3.02e+09 2.08e+09 ...
    ##  $ NY.GDP.MKTP.KD.ZG: num  3.894 3.789 0.897 2.313 0 ...
    ##  $ NY.GDP.PCAP.KD   : num  13779 14209 2361 938 878 ...
    ##  $ NY.GDP.PCAP.KD.ZG: num  0 1.7 0.208 1.962 0 ...

``` r
head(example)
```

    ## # A tibble: 6 x 6
    ##   gwcode  year NY.GDP.MKTP.KD NY.GDP.MKTP.KD.… NY.GDP.PCAP.KD
    ##    <dbl> <int>          <dbl>            <dbl>          <dbl>
    ## 1      2  1950 2188230979924.            3.89          13779.
    ## 2     20  1950  195140153622.            3.79          14209.
    ## 3     40  1950   13977169927.            0.897          2361.
    ## 4     41  1950    3020120716.            2.31            938.
    ## 5     42  1950    2075659328.            0               878.
    ## 6     70  1950   78527830674.            6.53           2803.
    ## # … with 1 more variable: NY.GDP.PCAP.KD.ZG <dbl>

``` r
example %>%
  gather(var, value, -gwcode, -year) %>%
  ggplot(., aes(x = year, y = value, group = gwcode)) +
  facet_wrap(~ var, ncol = 1, scales = "free_y") +
  geom_line(alpha = .2) +
  theme_minimal()
```

    ## Warning: Removed 47 rows containing missing values (geom_path).

![](README_files/figure-markdown_github/unnamed-chunk-1-1.png)

``` r
example$date <- as.Date(sprintf("%s-12-31", example$year))
plot_missing(example, "NY.GDP.MKTP.KD", "gwcode", "date", "year", "GW")
```

![](README_files/figure-markdown_github/unnamed-chunk-1-2.png)

``` r
plot_missing(example, "NY.GDP.MKTP.KD.ZG", "gwcode", "date", "year", "GW")
```

![](README_files/figure-markdown_github/unnamed-chunk-1-3.png)

``` r
fn <- sprintf("gdp_%s_%s.csv", min(example$year), max(example$year))
write_csv(example, file.path("output", fn))
```
