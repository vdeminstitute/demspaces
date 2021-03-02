GDP imputation
================
Andreas Beger, Predictive Heuristics
2018-12-18

-   [WDI GDP data](#wdi-gdp-data)
-   [KSG expanded GDP](#ksg-expanded-gdp)
-   [UN GDP data](#un-gdp-data)
-   [Combine data](#combine-data)
-   [Overlap between UN and WDI](#overlap-between-un-and-wdi)
-   [Overlap between KSG expanded and WDI](#overlap-between-ksg-expanded-and-wdi)
-   [Joint model of UN and KSG predicting WDI](#joint-model-of-un-and-ksg-predicting-wdi)
-   [Conclusion](#conclusion)
-   [Check GDP per capita](#check-gdp-per-capita)

WDI GDP data
------------

Relevant WDI indicators:

    "NY.GDP.PCAP.PP.KD.ZG"
    "NY.GDP.PCAP.PP.KD"
    "NY.GDP.PCAP.KD.ZG"
    "NY.GDP.PCAP.KD"
    "NY.GDP.MKTP.PP.KD"
    "NY.GDP.MKTP.KD"
    "NY.GDP.MKTP.KD.ZG"
    "SP.POP.TOTL"

``` r
wdigdp <- WDI(country = "all", start = 1960, end = 2018,
              indicator = c("NY.GDP.MKTP.PP.KD", "NY.GDP.MKTP.PP.CD", "NY.GDP.MKTP.KD"))

wdi <- gdp_wdi_add_gwcode(wdigdp)

wdi$date <- as.Date(sprintf("%s-06-30", wdi$year))
plot_missing(wdi, "NY.GDP.MKTP.KD", "gwcode", "date", "year", "GW") +
  ggtitle("NY.GDP.MKTP.KD")
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-1-1.png)

``` r
plot_missing(wdi, "NY.GDP.MKTP.PP.KD", "gwcode", "date", "year", "GW") +
  ggtitle("NY.GDP.MKTP.PP.KD")
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-1-2.png)

``` r
plot_missing(wdi, "NY.GDP.MKTP.PP.CD", "gwcode", "date", "year", "GW") +
  ggtitle("NY.GDP.MKTP.PP.CD")
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-1-3.png)

``` r
wdi$date <- NULL
```

KSG expanded GDP
----------------

``` r
ksggdp <- read_delim("input/expgdpv6.0/gdpv6.txt", delim = "\t") %>%
  rename(gwcode = statenum) %>%
  select(-stateid)
```

    ## Parsed with column specification:
    ## cols(
    ##   statenum = col_integer(),
    ##   stateid = col_character(),
    ##   year = col_integer(),
    ##   pop = col_double(),
    ##   realgdp = col_double(),
    ##   rgdppc = col_double(),
    ##   cgdppc = col_double(),
    ##   origin = col_integer()
    ## )

``` r
ksggdp$date <- as.Date(sprintf("%s-12-31", ksggdp$year))
plot_missing(ksggdp, "realgdp", "gwcode", "date", "year", "GW")
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-2-1.png)

``` r
ksggdp$date <- NULL
```

UN GDP data
-----------

``` r
ungdp <- read_csv("input/UNgdpData.csv") %>%
  select(country_name, country_id, year, gdp_2010USD) 
```

    ## Parsed with column specification:
    ## cols(
    ##   country_name = col_character(),
    ##   country_id = col_integer(),
    ##   year = col_integer(),
    ##   gdp_2010USD = col_double(),
    ##   gdp_2010USD_log = col_double(),
    ##   gdp_2010USD_lagged = col_double(),
    ##   gdp_2010USD_log_lagged = col_double()
    ## )

``` r
ungdp <- gdp_un_add_gwcode(ungdp)  
ungdp$date <- as.Date(sprintf("%s-12-31", ungdp$year))
plot_missing(ungdp, "gdp_2010USD", "gwcode", "date", "year", "GW")
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-3-1.png)

``` r
ungdp$date <- NULL
```

Combine data
------------

``` r
joint <- wdi %>%
  full_join(., ksggdp, by = c("gwcode", "year")) %>%
  select(-pop, -rgdppc, -cgdppc) %>%
  mutate(realgdp = realgdp*1e6) %>%
  full_join(., ungdp, by = c("gwcode", "year")) 
  

# Example countries to look at below
countries <- unique(c(
  c(2, 200, 220, 260, 290, 315, 740, 710),
  sample(unique(joint$gwcode), 4)))
```

Overlap between UN and WDI
--------------------------

The UN GDP data is almost completely correlated with WDI GDP.

``` r
# the UN GDP is almost completely correlated with WDI GDP
sum(complete.cases(joint[, c("gdp_2010USD", "NY.GDP.MKTP.KD")]))
```

    ## [1] 6599

``` r
cor(joint$gdp_2010USD, joint$NY.GDP.MKTP.KD, use = "complete.obs")
```

    ## [1] 0.9999338

``` r
plot(log10(joint$gdp_2010USD), log10(joint$NY.GDP.MKTP.KD))
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-5-1.png)

Does it add any non-missing values? Yes, about 800 or so.

``` r
# does it add any non-missing values?
joint %>%
  mutate(un_gdp_missing = is.na(gdp_2010USD),
         wdi_gdp_missing = is.na(NY.GDP.MKTP.KD)) %>%
  group_by(un_gdp_missing, wdi_gdp_missing) %>%
  summarize(n = n())
```

    ## # A tibble: 4 x 3
    ## # Groups:   un_gdp_missing [?]
    ##   un_gdp_missing wdi_gdp_missing     n
    ##   <lgl>          <lgl>           <int>
    ## 1 FALSE          FALSE            6599
    ## 2 FALSE          TRUE              866
    ## 3 TRUE           FALSE            1525
    ## 4 TRUE           TRUE             1819

For which countries? Somalia, Syria, ...

``` r
# which countries?
adds <- joint %>% 
  filter(is.na(NY.GDP.MKTP.KD) & !is.na(gdp_2010USD)) %>%
  group_by(gwcode) %>%
  summarize(adds = n())
head(arrange(adds, desc(adds)))
```

    ## # A tibble: 6 x 2
    ##   gwcode  adds
    ##    <int> <int>
    ## 1    520    47
    ## 2    652    47
    ## 3    731    47
    ## 4    816    42
    ## 5    522    38
    ## 6    345    37

``` r
# look at some examples of those
set.seed(1343)
countries2 <- unique(c(c(290, 345), 
                       sample(adds$gwcode, 8)))

mdl <- lm(NY.GDP.MKTP.KD ~ -1 + gdp_2010USD, data = joint)
joint <- joint %>%
  mutate(gdp_2010USD.rescaled = predict(mdl, newdata = joint))
joint %>%
  gather(var, value, -gwcode, -year, -origin, -realgdp, -NY.GDP.MKTP.PP.KD, -gdp_2010USD) %>%
  filter(gwcode %in% countries2) %>%
  ggplot(aes(x = year, y = value, colour = var, group = interaction(gwcode, var))) +
  geom_line(alpha = .5) +
  facet_wrap(~ gwcode, scales = "free_y")
```

    ## Warning: attributes are not identical across measure variables;
    ## they will be dropped

    ## Warning: Removed 837 rows containing missing values (geom_path).

![](coding-notes_files/figure-markdown_github/unnamed-chunk-8-1.png)

``` r
joint %>%
  gather(var, value, -gwcode, -year, -origin, -NY.GDP.MKTP.PP.KD, -gdp_2010USD) %>%
  filter(gwcode %in% countries) %>%
  ggplot(aes(x = year, y = value, colour = var, group = interaction(gwcode, var))) +
  geom_line(alpha = .5) +
  facet_wrap(~ gwcode, scales = "free_y")
```

    ## Warning: attributes are not identical across measure variables;
    ## they will be dropped

    ## Warning: Removed 937 rows containing missing values (geom_path).

![](coding-notes_files/figure-markdown_github/unnamed-chunk-8-2.png)

Rescaled UN GDP matches WDI very well, it seems. Adjusted R^2 is basically 1 and so is the coefficient.

Overlap between KSG expanded and WDI
------------------------------------

``` r
sum(complete.cases(joint[, c("realgdp", "NY.GDP.MKTP.PP.KD")]))
```

    ## [1] 3817

``` r
cor(joint$realgdp, joint$NY.GDP.MKTP.PP.KD, use = "complete.obs")
```

    ## [1] 0.9950465

``` r
sum(complete.cases(joint[, c("realgdp", "NY.GDP.MKTP.KD")]))
```

    ## [1] 7020

``` r
cor(joint$realgdp, joint$NY.GDP.MKTP.KD, use = "complete.obs")
```

    ## [1] 0.9595833

Plain linear rescaling doesn't work well.

``` r
# Plain linear rescaling; doesn't work well
mdl <- lm(NY.GDP.MKTP.KD ~ -1 + realgdp, data = joint)
summary(mdl)
```

    ## 
    ## Call:
    ## lm(formula = NY.GDP.MKTP.KD ~ -1 + realgdp, data = joint)
    ## 
    ## Residuals:
    ##        Min         1Q     Median         3Q        Max 
    ## -4.677e+12 -1.101e+10 -2.119e+09  6.301e+08  1.676e+12 
    ## 
    ## Coefficients:
    ##         Estimate Std. Error t value Pr(>|t|)    
    ## realgdp 1.047350   0.003545   295.5   <2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## Residual standard error: 2.657e+11 on 7019 degrees of freedom
    ##   (3789 observations deleted due to missingness)
    ## Multiple R-squared:  0.9256, Adjusted R-squared:  0.9256 
    ## F-statistic: 8.731e+04 on 1 and 7019 DF,  p-value: < 2.2e-16

``` r
joint <- joint %>%
  mutate(realgdp.rescaled = predict(mdl, newdata = joint))
joint %>%
  gather(var, value, -gwcode, -year, -origin, -NY.GDP.MKTP.PP.KD, -starts_with("gdp_2010")) %>%
  filter(gwcode %in% countries) %>%
  ggplot(aes(x = year, y = value, colour = var, group = interaction(gwcode, var))) +
  geom_line(alpha = .5) +
  facet_wrap(~ gwcode, scales = "free_y")
```

    ## Warning: attributes are not identical across measure variables;
    ## they will be dropped

    ## Warning: Removed 761 rows containing missing values (geom_path).

![](coding-notes_files/figure-markdown_github/unnamed-chunk-10-1.png)

``` r
plot(log10(joint$realgdp), log10(joint$NY.GDP.MKTP.KD))
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-10-2.png)

``` r
plot(log10(joint$realgdp.rescaled), log10(joint$NY.GDP.MKTP.KD))
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-10-3.png)

Try log model, also doesn't work super well.

``` r
# Try log log model; also doesn't work well
mdl <- lm(log(NY.GDP.MKTP.KD) ~ -1 + log(realgdp), data = joint)
summary(mdl)
```

    ## 
    ## Call:
    ## lm(formula = log(NY.GDP.MKTP.KD) ~ -1 + log(realgdp), data = joint)
    ## 
    ## Residuals:
    ##      Min       1Q   Median       3Q      Max 
    ## -2.49936 -0.34655 -0.03484  0.37953  3.08639 
    ## 
    ## Coefficients:
    ##               Estimate Std. Error t value Pr(>|t|)    
    ## log(realgdp) 0.9909991  0.0002669    3712   <2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## Residual standard error: 0.5369 on 7019 degrees of freedom
    ##   (3789 observations deleted due to missingness)
    ## Multiple R-squared:  0.9995, Adjusted R-squared:  0.9995 
    ## F-statistic: 1.378e+07 on 1 and 7019 DF,  p-value: < 2.2e-16

``` r
joint <- joint %>%
  mutate(realgdp.rescaled2 = exp(predict(mdl, newdata = joint)))
joint %>%
  gather(var, value, -gwcode, -year, -origin, -NY.GDP.MKTP.PP.KD, -starts_with("gdp_2010")) %>%
  filter(gwcode %in% countries) %>%
  ggplot(aes(x = year, y = value, colour = var, group = interaction(gwcode, var))) +
  geom_line() +
  facet_wrap(~ gwcode, scales = "free_y")
```

    ## Warning: attributes are not identical across measure variables;
    ## they will be dropped

    ## Warning: Removed 827 rows containing missing values (geom_path).

![](coding-notes_files/figure-markdown_github/unnamed-chunk-11-1.png)

``` r
plot(log10(joint$realgdp), log10(joint$NY.GDP.MKTP.KD))
abline(a = 0, b = 1)
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-11-2.png)

``` r
plot(log10(joint$realgdp.rescaled2), log10(joint$NY.GDP.MKTP.KD))
abline(a = 0, b = 1)
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-11-3.png)

Try scaling by country:

``` r
# try country-varying scaling factors; this works fairly well
library("lme4")
mdl <- lmer(log(NY.GDP.MKTP.KD) ~ -1 + log(realgdp) + (log(realgdp)|gwcode), data = joint)
joint <- joint %>%
  mutate(realgdp.rescaled3 = exp(predict(mdl, newdata = joint, allow.new.levels = TRUE)))
joint %>%
  gather(var, value, -gwcode, -year, -origin, -realgdp.rescaled, -realgdp.rescaled2,
         -starts_with("gdp_2010"), -NY.GDP.MKTP.PP.KD) %>%
  filter(gwcode %in% countries) %>%
  ggplot(aes(x = year, y = value, colour = var, group = interaction(gwcode, var))) +
  geom_line() +
  facet_wrap(~ gwcode, scales = "free_y")
```

    ## Warning: attributes are not identical across measure variables;
    ## they will be dropped

    ## Warning: Removed 761 rows containing missing values (geom_path).

![](coding-notes_files/figure-markdown_github/unnamed-chunk-12-1.png)

``` r
plot(log10(joint$realgdp), log10(joint$NY.GDP.MKTP.KD))
abline(a = 0, b = 1)
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-12-2.png)

``` r
plot(log10(joint$realgdp.rescaled3), log10(joint$NY.GDP.MKTP.KD))
abline(a = 0, b = 1)
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-12-3.png)

Joint model of UN and KSG predicting WDI
----------------------------------------

``` r
mdl_combo <- lmer(log(NY.GDP.MKTP.KD) ~ -1 + log(gdp_2010USD) + log(realgdp) + (log(realgdp)|gwcode), data = joint)
joint <- joint %>%
  mutate(NY.GDP.MKTP.KD.hat = exp(predict(mdl_combo, newdata = joint, allow.new.levels = TRUE)))
joint %>%
  gather(var, value, -gwcode, -year, -origin, -realgdp, -realgdp.rescaled, -realgdp.rescaled2, -realgdp.rescaled3,
         -starts_with("gdp_2010"), -NY.GDP.MKTP.PP.KD) %>%
  filter(gwcode %in% countries) %>%
  ggplot(aes(x = year, y = value, colour = var, group = interaction(gwcode, var))) +
  geom_line() +
  facet_wrap(~ gwcode, scales = "free_y")
```

    ## Warning: attributes are not identical across measure variables;
    ## they will be dropped

    ## Warning: Removed 926 rows containing missing values (geom_path).

![](coding-notes_files/figure-markdown_github/unnamed-chunk-13-1.png)

``` r
joint %>%
  gather(var, value, -gwcode, -year, -origin, -realgdp, -realgdp.rescaled, -realgdp.rescaled2, -realgdp.rescaled3,
         -starts_with("gdp_2010"), -NY.GDP.MKTP.PP.KD) %>%
  filter(gwcode %in% countries2) %>%
  ggplot(aes(x = year, y = value, colour = var, group = interaction(gwcode, var))) +
  geom_line() +
  facet_wrap(~ gwcode, scales = "free_y")
```

    ## Warning: attributes are not identical across measure variables;
    ## they will be dropped

    ## Warning: Removed 877 rows containing missing values (geom_path).

![](coding-notes_files/figure-markdown_github/unnamed-chunk-13-2.png)

This works well, but cannot predict when either KSG or UN is missing, so not useful in practice for filling in WDI gaps.

Conclusion
----------

Four step imputation procedure:

1.  Acquire the WDI data
2.  Where WDI is missing, drop in UN GDP figures, scaled by a linear model.
3.  Where WDI is missing, drop in KSG figures, scaled by a log-linear country-varying scaling model.
4.  Model-based extrapolation: use Kalman-smoothing to forward extrapolate missing GDP values (most notably Taiwan and several countries missing current year GDP values) and backward extrapolate GDP growth in first year of existences of a country.

Check leftover missing values before impute:

``` r
source("gdp.R")
joint <- gdp_api(impute = FALSE)
```

    ## Parsed with column specification:
    ## cols(
    ##   gwcode = col_integer(),
    ##   year = col_double(),
    ##   pop = col_double()
    ## )

``` r
joint$date <- as.Date(sprintf("%s-12-31", joint$year))
p <- plot_missing(joint, "NY.GDP.MKTP.KD", "gwcode", "date", "year", "GW")
joint$date <- NULL
p
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-14-1.png)

``` r
still_missing <- joint %>% 
  filter(is.na(NY.GDP.MKTP.KD)) %>% 
  group_by(gwcode) %>%
  summarize(n = n(),
            years = paste0(range(year), collapse = " - ")) %>%
  arrange(desc(n))
still_missing
```

    ## # A tibble: 15 x 3
    ##    gwcode     n years      
    ##     <int> <int> <chr>      
    ##  1    221     6 2012 - 2017
    ##  2    223     6 2012 - 2017
    ##  3    396     6 2012 - 2017
    ##  4    397     6 2012 - 2017
    ##  5    713     6 2012 - 2017
    ##  6     40     1 2017 - 2017
    ##  7    101     1 2017 - 2017
    ##  8    520     1 2017 - 2017
    ##  9    522     1 2017 - 2017
    ## 10    531     1 2017 - 2017
    ## 11    626     1 2017 - 2017
    ## 12    652     1 2017 - 2017
    ## 13    678     1 2017 - 2017
    ## 14    731     1 2017 - 2017
    ## 15    816     1 2017 - 2017

Use Kalman smoothing to extrapolate the leftover trailing missing values, and backwards extrapolate first year missing GDP growth.

``` r
source("gdp.R")
joint <- gdp_api(impute = TRUE)
```

    ## Parsed with column specification:
    ## cols(
    ##   gwcode = col_integer(),
    ##   year = col_double(),
    ##   pop = col_double()
    ## )

    ## Warning in StructTS(data, ...): possible convergence problem: 'optim' gave
    ## code = 52 and message 'ERROR: ABNORMAL_TERMINATION_IN_LNSRCH'

``` r
joint$date <- as.Date(sprintf("%s-12-31", joint$year))
p <- plot_missing(joint, "NY.GDP.MKTP.KD", "gwcode", "date", "year", "GW")
joint$date <- NULL
p
```

![](coding-notes_files/figure-markdown_github/unnamed-chunk-15-1.png)

Check GDP per capita
--------------------

This uses "population.csv" from the population module.

At least one of the combined GDP values--Qatar in 1971--is clunky in that there is a big discrepancy. This gives Qatar 1971 an inordinarily high GDP per capita value. Solved by backward imputing GDP instead of taking KSG value.
