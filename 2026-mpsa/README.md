# 2026 MPSA Paper

Stuff related to the paper for the 2026 conference.

The forecasts prior to v12.1 used the original DV calculation method, 



## Historical data

The project switched from original to ERT-lite style outcomes with the v12.1 version. 

To obtain historical data, I re-ran the DV data recreation code on a separate branch, `historical-DV-data`, and copied the results over to the main branch (manually).

The process for creating historical DV data is like this:

1. Go to the `historical-DV-data` branch (manually copy over or cherry pick commits with needed input data).
2. Set `config.yml` to the correct values.
3. Run `0-split-raw-vdem.R`. 
4. In `2-create-dv-data.Rmd`, set the flag for whether to use ERT-lite outcome method.
5. Run `2-create-dv-data.Rmd`.
6. Copy `output/dv-data.rds` to `2026-mpsa/input` and rename.


For he v12 data versions (both) and ERT lite versions for v13 and v14 we already have needed data in the archive, so I simply copied it over using this code:

```r
library(readr)
library(dplyr)

read_rds("archive/data/states-v9.rds") |>
  select(gwcode:dv_v2x_pubcorr_down_next2) |>
  write_rds("2026-mpsa/input/dv-data_v9_original.rds")
  
read_rds("archive/data/states-v10.rds") |>
  select(gwcode:dv_v2x_pubcorr_down_next2) |>
  write_rds("2026-mpsa/input/dv-data_v10_original.rds")

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


I checked `dv-data_v11.1_original.rds` against `archive/data/states-v11.rds`, and aside from 1968 and 1679 data (which is taken out), it has these cases difference:

```
> v11_new |> anti_join(v11_archive, by = c("gwcode", "year")) |> dplyr::filter(year > 1969) |> select(gwcode, year)
# A tibble: 3 × 2
  gwcode  year
   <dbl> <dbl>
1    265  1990
2    680  1990
3    817  1975
```

(No cases in v11_archive that are not in v11_new.)


