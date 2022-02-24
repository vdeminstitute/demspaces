Calculate cutpoints
================

*Note (AB, 2020-03-24): the cutpoint calculations were originally done
in a file called “1-dv_notes.Rmd”, written by Rick. That file also
created a memo/report. I split the cutpoint calculation part out because
there was a circular dependency with “2-create-dv-data.Rmd”, and
adjusted the code accordingly to remove this problem. See issue #26 on
GitHub (andybega) to see the commit that created this file.*

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

    ## # A tibble: 50,748 × 5
    ## # Groups:   gwcode, variable [1,044]
    ##    gwcode  year variable          value diff_y2y
    ##     <dbl> <dbl> <chr>             <dbl>    <dbl>
    ##  1      2  1968 v2x_freexp_altinf 0.876  0      
    ##  2      2  1969 v2x_freexp_altinf 0.885  0.00900
    ##  3      2  1970 v2x_freexp_altinf 0.902  0.0170 
    ##  4      2  1971 v2x_freexp_altinf 0.878 -0.0240 
    ##  5      2  1972 v2x_freexp_altinf 0.902  0.0240 
    ##  6      2  1973 v2x_freexp_altinf 0.928  0.0260 
    ##  7      2  1974 v2x_freexp_altinf 0.936  0.00800
    ##  8      2  1975 v2x_freexp_altinf 0.937  0.00100
    ##  9      2  1976 v2x_freexp_altinf 0.951  0.0140 
    ## 10      2  1977 v2x_freexp_altinf 0.944 -0.00700
    ## # … with 50,738 more rows

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

    ## # A tibble: 8,458 × 14
    ## # Groups:   gwcode [174]
    ##    gwcode  year v2x_freexp_altinf v2x_horacc_osp v2x_pubcorr v2x_veracc_osp
    ##     <dbl> <dbl>             <dbl>          <dbl>       <dbl>          <dbl>
    ##  1      2  1968             0.876          0.907       0.952          0.85 
    ##  2      2  1969             0.885          0.913       0.952          0.849
    ##  3      2  1970             0.902          0.918       0.96           0.865
    ##  4      2  1971             0.878          0.918       0.948          0.866
    ##  5      2  1972             0.902          0.919       0.948          0.862
    ##  6      2  1973             0.928          0.959       0.948          0.863
    ##  7      2  1974             0.936          0.96        0.948          0.872
    ##  8      2  1975             0.937          0.96        0.948          0.888
    ##  9      2  1976             0.951          0.96        0.948          0.903
    ## 10      2  1977             0.944          0.954       0.948          0.906
    ## # … with 8,448 more rows, and 8 more variables: v2xcl_rol <dbl>,
    ## #   v2xcs_ccsi <dbl>, v2x_freexp_altinf_diff_y2y <dbl>,
    ## #   v2x_horacc_osp_diff_y2y <dbl>, v2x_pubcorr_diff_y2y <dbl>,
    ## #   v2x_veracc_osp_diff_y2y <dbl>, v2xcl_rol_diff_y2y <dbl>,
    ## #   v2xcs_ccsi_diff_y2y <dbl>

``` r
# make sure we did not mess up the original data values
stopifnot(
  all.equal(cor(dv_with_diffs$v2x_freexp_altinf, dv$v2x_freexp_altinf), 1)
)

# Mimic what dv_BaseDatFun does, but without the hidden data read
dv_base_dat <- function(dv_name, dv_data) {
  dat <- dv_data %>%
    ungroup() %>%
    select(gwcode, year, contains(dv_name)) %>%
    rename(var = all_of(dv_name),
           var_y2y = paste0(dv_name, "_diff_y2y")) %>%
    filter(complete.cases(.)) %>%
    mutate(case = case_when(var_y2y > 0 ~ "up",
                            var_y2y < 0 ~ "down",
                            TRUE ~ "no change"),
           case = as.factor(case))
  dat
}

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
    ## 1 v2x_veracc_osp 0.0819  0.08  0.08
    ## 
    ## 
    ##  v2xcs_ccsi 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator     all    up  down
    ##   <chr>       <dbl> <dbl> <dbl>
    ## 1 v2xcs_ccsi 0.0558  0.05  0.05
    ## 
    ## 
    ##  v2xcl_rol 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator    all    up  down
    ##   <chr>      <dbl> <dbl> <dbl>
    ## 1 v2xcl_rol 0.0431  0.04  0.04
    ## 
    ## 
    ##  v2x_freexp_altinf 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator            all    up  down
    ##   <chr>              <dbl> <dbl> <dbl>
    ## 1 v2x_freexp_altinf 0.0553  0.05  0.05
    ## 
    ## 
    ##  v2x_horacc_osp 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator         all    up  down
    ##   <chr>           <dbl> <dbl> <dbl>
    ## 1 v2x_horacc_osp 0.0576  0.06  0.06
    ## 
    ## 
    ##  v2x_pubcorr 
    ## 
    ## # A tibble: 1 × 4
    ##   indicator      all    up  down
    ##   <chr>        <dbl> <dbl> <dbl>
    ## 1 v2x_pubcorr 0.0412  0.03  0.03

``` r
cp <- bind_rows(cp)
write_csv(cp, "../output/cutpoints.csv")
```
