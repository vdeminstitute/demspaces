

library(dplyr)
library(ggplot2)
library(glue)
library(states)


# Used for the plots below, if there are any new V-Dem versions, make sure to
# tack on "17" or whatever, and in the function below also change the first body
# line.
vdem_levels <- c("9", "10", "11", "12", "13", "14", "15", "16")

read_all_versions_for_index <- function(vars, start_year = 2015) {
  v <- c(as.character(9:10), "11.1", as.character(12:16))
  vdem_files <- glue("create-data/input/V-Dem-CY-Full+Others-v{v}.rds")
  index_data <- vdem_files |>
    map(\(path) {
      version <- str_extract(path, "v([0-9]{1,2})", group = 1)

      vdem <- read_rds(path) |>
        as_tibble()

      vdem <- vdem |>
        filter(year >= start_year) |>
        select(COWcode, year, all_of(vars))

      vdem <- vdem |>
        mutate(
          gwcode = COWcode,
          gwcode = case_when(gwcode == 255 ~ 260,
                             gwcode == 679 ~ 678,
                             gwcode == 345 & year >= 2006 ~ 340,
                             TRUE ~ gwcode)
        ) |>
        # Some places like Palestine and Hong Kong will drop out
        filter(!is.na(gwcode))

      vdem$vdem_version <- version

      vdem |>
        select(gwcode, year, vdem_version, all_of(vars))
    }) |>
    list_rbind() |>
    arrange(gwcode, year, vdem_version)

  index_data
}


index_data <- read_all_versions_for_index(
  vars = c("v2x_polyarchy", "v2x_polyarchy_codehigh", "v2x_polyarchy_codelow"),
  start_year = 2010)

index_data |>
  filter(gwcode==310) |>
  mutate(vdem_version = factor(vdem_version, levels = vdem_levels)) |>
  ggplot(aes(x = year, fill = vdem_version)) +
  geom_ribbon(aes(ymin = v2x_polyarchy_codelow, ymax = v2x_polyarchy_codehigh), alpha = 0.05) +
  geom_line(aes(y = v2x_polyarchy, color = vdem_version)) +
  scale_x_continuous(limits = c(2010, 2026), breaks = seq(2010, 2026, by = 2)) +
  scale_y_continuous(limits = c(0,1)) +
  scale_color_brewer(guide="none", type = "qual", palette = 3) +
  scale_fill_brewer(guide = "none", type = "qual", palette = 3) +
  theme_minimal() +
  labs(x = "", y = "")

ggsave(here::here("2026-mpsa/figures/hungary-polyarchy.png"), height = 4, width = 4)



index_data |>
  filter(gwcode==2) |>
  mutate(vdem_version = factor(vdem_version, levels = vdem_levels)) |>
  ggplot(aes(x = year, fill = vdem_version)) +
  geom_ribbon(aes(ymin = v2x_polyarchy_codelow, ymax = v2x_polyarchy_codehigh), alpha = 0.05) +
  geom_line(aes(y = v2x_polyarchy, color = vdem_version)) +
  scale_x_continuous(breaks = seq(2010, 2025, by = 2)) +
  scale_y_continuous(limits = c(0,1)) +
  scale_color_brewer(guide = "none", type = "qual", palette = 3) +
  scale_fill_brewer(guide = "none", type = "qual", palette = 3) +
  theme_minimal() +
  labs(x = "", y = "")


ggsave(here::here("2026-mpsa/figures/us-polyarchy.png"), height = 4, width = 4)

