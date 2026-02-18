# 2026 MPSA Paper

Stuff related to the paper for the 2026 conference.

The forecasts prior to v12.1 used the original DV calculation method, 




- `dv-data_v11.1_ert-lite.rds`
- `dv-data_v11.1_original.rds`


- The v12 data versions and ERT lite versions for v13 and v14 come from the archive:

```r
library(readr)
library(dplyr)

read_rds("archive/data/states-v12.rds") |>
  select(gwcode:dv_v2x_pubcorr_down_next2) |>
  write_rds("2026-mpsa/input/dv-data_v12_original.rds")

read_rds("archive/data/states-v12.1.rds") |>
  select(gwcode:dv_v2x_pubcorr_down_next2) |>
  write_rds("2026-mpsa/input/dv-data_v12_ert-lite.rds")
  
read_rds("archive/data/states-v13.rds") |>
  select(gwcode:dv_v2x_pubcorr_down_next2) |>
  write_rds("2026-mpsa/input/dv-data_v13_ert-lite.rds")
  
read_rds("archive/data/states-v14.rds") |>
  select(gwcode:dv_v2x_pubcorr_down_next2) |>
  write_rds("2026-mpsa/input/dv-data_v14_ert-lite.rds")
```


I checked `dv-data_v11.1_original.rds` against `archive/data/states-v11.rds`, and aside from 1968 and 1679 data (which is taken out), it has these cases:

```
> v11_new |> anti_join(v11_archive, by = c("gwcode", "year")) |> dplyr::filter(year > 1969) |> select(gwcode, year)
# A tibble: 3 × 2
  gwcode  year
   <dbl> <dbl>
1    265  1990
2    680  1990
3    817  1975
```
