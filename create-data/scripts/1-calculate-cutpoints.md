Calculate cutpoints
================

*Last ran with v14 data on 2026/01 for MPSA panel*

*Note (AB, 2020-03-24): the cutpoint calculations were originally done
in a file called “1-dv_notes.Rmd”, written by Rick. That file also
created a memo/report. I split the cutpoint calculation part out because
there was a circular dependency with “2-create-dv-data.Rmd”, and
adjusted the code accordingly to remove this problem. See issue \#26 on
GitHub (andybega) to see the commit that created this file.*

``` r
dv <- read_csv("../output/dv_data_1968_on.csv") %>%
  select(-country_name, -country_id, -country_text_id) %>%
  dplyr::filter(complete.cases(.)) %>%
  arrange(gwcode, year)
```

    ## Rows: 8796 Columns: 11
    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr (2): country_name, country_text_id
    ## dbl (9): gwcode, year, country_id, v2x_veracc_osp, v2xcs_ccsi, v2xcl_rol, v2...
    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
dv_vars <- setdiff(names(dv), c("gwcode", "year"))
dv_vars
```

    ## [1] "v2x_veracc_osp"    "v2xcs_ccsi"        "v2xcl_rol"        
    ## [4] "v2x_freexp_altinf" "v2x_horacc_osp"    "v2x_pubcorr"

``` r
# Create variables for DV year to year changes
dv_semi_long <- dv %>%
  # pivot to long data frame so we can do all 6 variables at the same time
  pivot_longer(-c(gwcode, year), names_to = "variable") %>%
  group_by(gwcode, variable) %>%
  arrange(gwcode, variable, year) %>%
  dplyr::mutate(
    # setting to 0 is missing, i.e. first year of independence
    diff_y2y = c(0, diff(value)),
  )  

# now there are 2 value columns (for original var, and y2y_diff version); 
# we can make it wide as is, but then have to fix some columns names ("value_")
dv_semi_long
```

    ## # A tibble: 52,776 × 5
    ## # Groups:   gwcode, variable [1,044]
    ##    gwcode  year variable          value diff_y2y
    ##     <dbl> <dbl> <chr>             <dbl>    <dbl>
    ##  1      2  1968 v2x_freexp_altinf 0.874  0      
    ##  2      2  1969 v2x_freexp_altinf 0.881  0.00700
    ##  3      2  1970 v2x_freexp_altinf 0.899  0.0180 
    ##  4      2  1971 v2x_freexp_altinf 0.869 -0.0300 
    ##  5      2  1972 v2x_freexp_altinf 0.896  0.0270 
    ##  6      2  1973 v2x_freexp_altinf 0.925  0.0290 
    ##  7      2  1974 v2x_freexp_altinf 0.935  0.0100 
    ##  8      2  1975 v2x_freexp_altinf 0.938  0.00300
    ##  9      2  1976 v2x_freexp_altinf 0.951  0.0130 
    ## 10      2  1977 v2x_freexp_altinf 0.943 -0.00800
    ## # ℹ 52,766 more rows

``` r
# make wide again
dv_with_diffs <- dv_semi_long %>%
  pivot_wider(names_from = variable, values_from = c(value, diff_y2y)) %>%
  arrange(gwcode, year) %>%
  # take out "value_" prefix
  setNames(names(.) %>% str_replace("value_", "")) %>%
  # move "diff_y2y_" prefix to "_diff_y2y" suffix
  setNames(names(.) %>% str_replace("diff_y2y_([a-z0-9\\_]+)", "\\1_diff_y2y"))
  
dv_with_diffs
```

    ## # A tibble: 8,796 × 14
    ## # Groups:   gwcode [174]
    ##    gwcode  year v2x_freexp_altinf v2x_horacc_osp v2x_pubcorr v2x_veracc_osp
    ##     <dbl> <dbl>             <dbl>          <dbl>       <dbl>          <dbl>
    ##  1      2  1968             0.874          0.91        0.945          0.846
    ##  2      2  1969             0.881          0.916       0.945          0.845
    ##  3      2  1970             0.899          0.921       0.961          0.861
    ##  4      2  1971             0.869          0.923       0.948          0.862
    ##  5      2  1972             0.896          0.922       0.948          0.859
    ##  6      2  1973             0.925          0.958       0.948          0.86 
    ##  7      2  1974             0.935          0.959       0.948          0.867
    ##  8      2  1975             0.938          0.961       0.948          0.886
    ##  9      2  1976             0.951          0.96        0.948          0.901
    ## 10      2  1977             0.943          0.954       0.948          0.902
    ## # ℹ 8,786 more rows
    ## # ℹ 8 more variables: v2xcl_rol <dbl>, v2xcs_ccsi <dbl>,
    ## #   v2x_freexp_altinf_diff_y2y <dbl>, v2x_horacc_osp_diff_y2y <dbl>,
    ## #   v2x_pubcorr_diff_y2y <dbl>, v2x_veracc_osp_diff_y2y <dbl>,
    ## #   v2xcl_rol_diff_y2y <dbl>, v2xcs_ccsi_diff_y2y <dbl>

``` r
# make sure we did not mess up the original data values
stopifnot(
  all.equal(cor(dv_with_diffs$v2x_freexp_altinf, dv$v2x_freexp_altinf), 1)
)

cp <- list()
for (dv_name in dv_vars) {
  cat("\n\n", dv_name, "\n\n")
  cp[[dv_name]] <- as_tibble(c(
    indicator = dv_name, 
    dv_cutpointFun(dv_base_dat(dv_name, dv_with_diffs))
  ))
  print(cp[[dv_name]])
}
```

    ## 
    ## 
    ##  v2x_veracc_osp 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator         all    up  down
    ##   <chr>           <dbl> <dbl> <dbl>
    ## 1 v2x_veracc_osp 0.0796  0.07  0.07
    ## 
    ## 
    ##  v2xcs_ccsi 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator     all    up  down
    ##   <chr>       <dbl> <dbl> <dbl>
    ## 1 v2xcs_ccsi 0.0547  0.05  0.05
    ## 
    ## 
    ##  v2xcl_rol 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator    all    up  down
    ##   <chr>      <dbl> <dbl> <dbl>
    ## 1 v2xcl_rol 0.0421  0.04  0.04
    ## 
    ## 
    ##  v2x_freexp_altinf 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator            all    up  down
    ##   <chr>              <dbl> <dbl> <dbl>
    ## 1 v2x_freexp_altinf 0.0543  0.05  0.05
    ## 
    ## 
    ##  v2x_horacc_osp 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator         all    up  down
    ##   <chr>           <dbl> <dbl> <dbl>
    ## 1 v2x_horacc_osp 0.0564  0.05  0.05
    ## 
    ## 
    ##  v2x_pubcorr 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator      all    up  down
    ##   <chr>        <dbl> <dbl> <dbl>
    ## 1 v2x_pubcorr 0.0414  0.04  0.04

``` r
cp <- bind_rows(cp)
write_csv(cp, "../output/cutpoints.csv")
```

## 2023 spring update

I’m going to override the cutpoint re-calculations and keep the values
from the past 2 years for consistency.

``` r
cp_vals <- c(0.08, 0.05, 0.04, 0.05, 0.06, 0.03)
frozen_cp <- data.frame(
  indicator = c("v2x_veracc_osp", "v2xcs_ccsi", "v2xcl_rol", 
                "v2x_freexp_altinf", "v2x_horacc_osp", "v2x_pubcorr"),
  up = cp_vals,
  down = cp_vals
)

new_cp <- merge(cp[, c("indicator", "all")], frozen_cp)
# fix order of rows after merge
new_cp <- new_cp[match(frozen_cp$indicator, new_cp$indicator), ]
write_csv(new_cp, "../output/cutpoints.csv")

# keep track of the re-calculated cutpoints for monitoring
tracker <- cp
names(tracker) <- c("indicator", "diff_sd", "cp_up_this_year", "cp_down_this_year")

tracker <- merge(tracker, frozen_cp)
colnames(tracker)[5:6] <- c("frozen_up", "frozen_down")

str <- knitr::kable(tracker)
writeLines(str, here::here("create-data/output/tracker-cutpoints.md"))
```
