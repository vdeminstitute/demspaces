#
#   Write a table that counts up, down, same for 2021, by v12 and v12.1
#

library(dplyr)
library(demspacesR)

v12 <- readRDS(here::here("archive/data/states-v12.rds"))
v12.1 <- readRDS(here::here("archive/data/states-v12.1.rds"))

data(spaces)

v12 <- v12 %>%
  filter(year==max(year)) %>%
  select(gwcode, year, ends_with("change"))

v12.1 <- v12.1 %>%
  filter(year==max(year)) %>%
  select(gwcode, year, ends_with("change"))

v12$version <- "v12"
v12.1$version <- "v12.1"

outcomes <- rbind(v12, v12.1)

outcomes_long <- outcomes %>%
  pivot_longer(-c(gwcode, year, version), names_to = "space") %>%
  mutate(space = gsub("dv_", "", space),
         space = gsub("_change", "", space))

tbl <- outcomes_long %>%
  count(space, version, value) %>%
  mutate(value = paste0(value, "_", version),
         version = NULL) %>%
  arrange(value) %>%
  pivot_wider(names_from = "value", values_from = "n") %>%
  mutate(space = spaces$Space[match(space, spaces$Indicator)]) %>%
  arrange(space)

write_csv(tbl, here::here("2022-update/report-data/outcome-comparison.csv"))
