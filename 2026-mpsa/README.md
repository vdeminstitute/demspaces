# 2026 MPSA Paper

Stuff related to the paper for the 2026 conference.

The forecasts prior to v12.1 used the original DV calculation method, 




- `dv-data_v11.1_ert-lite.rds`
- `dv-data_v11.1_original.rds`


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
