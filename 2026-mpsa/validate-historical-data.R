#
#   Basic validation of historical data: ERT-lite should have more events than
#   original outcome version; years should be correct coverage.
#

library(stringr)
library(readr)
library(dplyr)

files <- dir("2026-mpsa/input", pattern = "dv-data")

for (i in 1:length(files)) {
  df <- read_rds(paste0("2026-mpsa/input/", files[i]))
  cat("File:", files[i], "\n")
  up <- df |> dplyr::filter(year > 1969) |> pull(dv_v2x_veracc_osp_up_next2) |> sum(na.rm = TRUE)
  cat("Up:", up, "\n")
  cat("Max year:", max(df$year), "\n")
}
