Multi-source population data
================

*Last updated on: 2021-03-02*

Complete G\&W coverage population data for 1816 to 2020. Preferentially
from UN data for post-1949 data, with drop-ins from WDI and KSG; for
pre-1950 KSG data.

## Usage

``` r
library("dplyr")
library("ggplot2")
library("states")

pop <- read_csv("output/population.csv")
```

    ## 
    ## ── Column specification ────────────────────────────────────────────────────────
    ## cols(
    ##   gwcode = col_double(),
    ##   year = col_double(),
    ##   pop = col_double()
    ## )

``` r
str(pop)
```

    ## spec_tbl_df [19,864 × 3] (S3: spec_tbl_df/tbl_df/tbl/data.frame)
    ##  $ gwcode: num [1:19864] 2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year  : num [1:19864] 1816 1817 1818 1819 1820 ...
    ##  $ pop   : num [1:19864] 8659 8899 9139 9379 9618 ...
    ##  - attr(*, "spec")=
    ##   .. cols(
    ##   ..   gwcode = col_double(),
    ##   ..   year = col_double(),
    ##   ..   pop = col_double()
    ##   .. )

``` r
head(pop)
```

    ## # A tibble: 6 x 3
    ##   gwcode  year   pop
    ##    <dbl> <dbl> <dbl>
    ## 1      2  1816  8659
    ## 2      2  1817  8899
    ## 3      2  1818  9139
    ## 4      2  1819  9379
    ## 5      2  1820  9618
    ## 6      2  1821  9939

``` r
plot_missing(pop, x = "pop", ccode = "gwcode", time = "year", statelist = "GW")
```

![](README_files/figure-gfm/unnamed-chunk-1-1.png)<!-- -->

``` r
pop %>%
  ggplot(aes(x = year, y = pop, group = gwcode)) +
  geom_line(alpha = .5) +
  scale_y_log10() + 
  theme_minimal()
```

    ## Warning: Removed 28 row(s) containing missing values (geom_path).

![](README_files/figure-gfm/unnamed-chunk-1-2.png)<!-- -->

``` r
data("gwstates")
still_missing <- pop %>%
  filter(is.na(pop)) %>%
  group_by(gwcode) %>%
  summarize(year = paste0(range(year), collapse = " - "),
            n = n()) %>%
  left_join(gwstates, by = "gwcode") %>%
  select(gwcode, country_name, year, n)
still_missing
```

    ## # A tibble: 3 x 4
    ##   gwcode country_name  year            n
    ##    <dbl> <chr>         <chr>       <int>
    ## 1    396 Abkhazia      2008 - 2020    13
    ## 2    397 South Ossetia 2008 - 2020    13
    ## 3    511 Zanzibar      1963 - 1964     2
