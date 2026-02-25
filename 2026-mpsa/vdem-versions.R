#
#   Collect all V-Dem versions we've used
#

library(dplyr)
library(readr)
library(stringr)

versions <- c(
  "v9", "v10", "v11", "v12", "v13", "v14", "v15"
)
# Construct the file paths for where the data are in create-data/input
file_paths = paste0("create-data/input/V-Dem-CY-Full+Others-", versions, ".rds")

read_and_select <- function(path) {
  version <- str_extract(basename(path), "v[0-9]+")
  data <- as_tibble(read_rds(path))
  data <- data |> select(country_name, country_text_id, year, starts_with("v2x_libdem"))
  data <- data |> mutate(vdem_version = version)
  data
}

vdem <- file_paths |>
  lapply(read_and_select)
vdem <- bind_rows(vdem)

vdem <- vdem |> filter(year >= 1990)

