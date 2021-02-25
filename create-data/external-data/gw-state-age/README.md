GW state age
================

State age, i.e. time since independence or 1816.

``` r
gwstates <- read.csv("output/gwstate-age.csv")

head(gwstates)
```

    ##   gwcode year state_age
    ## 1      2 1816         1
    ## 2      2 1817         2
    ## 3      2 1818         3
    ## 4      2 1819         4
    ## 5      2 1820         5
    ## 6      2 1821         6

``` r
str(gwstates)
```

    ## 'data.frame':    19864 obs. of  3 variables:
    ##  $ gwcode   : int  2 2 2 2 2 2 2 2 2 2 ...
    ##  $ year     : int  1816 1817 1818 1819 1820 1821 1822 1823 1824 1825 ...
    ##  $ state_age: int  1 2 3 4 5 6 7 8 9 10 ...

``` r
range(gwstates$year)
```

    ## [1] 1816 2020
