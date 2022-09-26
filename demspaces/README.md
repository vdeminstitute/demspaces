
<!-- README.md is generated from README.Rmd. Please edit that file -->

# demspaces

<!-- badges: start -->

[![R-CMD-check](https://github.com/vdeminstitute/demspaces/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/vdeminstitute/demspaces/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/vdeminstitute/demspaces/branch/main/graph/badge.svg)](https://app.codecov.io/gh/vdeminstitute/demspaces?branch=main)
<!-- badges: end -->

demspaces contains helper functions for the Democratic Spaces Barometer
project; see
[vdeminstitute/demspaces](https://github.com/vdeminstitute/demspaces).

## Installation

Since this package is specific to the democratic spaces project, it will
not end up on CRAN. Install from [GitHub](https://github.com/) instead,
with:

``` r
# install.packages("remotes")
remotes::install_github("vdeminstitute/demspaces")
```

## Example

``` r
library("demspaces")
#> ---- demspaces
#> WARNING: could not find 'config.yml', manually set options with 'set_options("path/to/config.yml")'
#> ----
#> 
#> Attaching package: 'demspaces'
#> The following object is masked from 'package:stats':
#> 
#>     rf

data("states")

mdl   <- ds_logistic_reg("v2x_veracc_osp", states)
#> Warning in ds_logistic_reg("v2x_veracc_osp", states): Discarding 40 incomplete
#> feature set cases
#> Warning in ds_logistic_reg("v2x_veracc_osp", states): Discarding 40 incomplete
#> outcome set cases
preds <- predict(mdl, new_data = states)
head(preds)
#>          outcome from_year   for_years gwcode       p_up    p_same     p_down
#> 1 v2x_veracc_osp      1970 1971 - 1972      2 0.02847696 0.9612083 0.01061705
#> 2 v2x_veracc_osp      1971 1972 - 1973      2 0.02074426 0.9689705 0.01050317
#> 3 v2x_veracc_osp      1972 1973 - 1974      2 0.02582880 0.9619841 0.01251021
#> 4 v2x_veracc_osp      1973 1974 - 1975      2 0.02612461 0.9631745 0.01098790
#> 5 v2x_veracc_osp      1974 1975 - 1976      2 0.02514729 0.9650580 0.01004742
#> 6 v2x_veracc_osp      1975 1976 - 1977      2 0.02246814 0.9629301 0.01493733
```

## Meta

There is a Makefile at the root level of this repo to help with stuff.
E.g. to open that static docs:

``` bash
make opendocs
```

To add new models, see the `add_new_model.R` script. It will use a
template to setup the R and test files.
