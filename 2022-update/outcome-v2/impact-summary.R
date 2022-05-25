#
#   Basic stats on mod outcome
#

library(dplyr)
library(tidyr)
library(demspacesR)

data(spaces)

states <- readRDS(here::here("archive/data/states-v12.rds"))
states_mod <- readRDS(here::here("archive/data/states-v12.1.rds"))

# Construct outcome column names
next2 <- sort(
  paste0("dv_", spaces$Indicator, sort(rep(c("_up", "_down"), times = 6)),
         "_next2")
)
change <- sort(
  paste0("dv_", spaces$Indicator, "_change")
)

tbl_orig <- states |>
  select(all_of(change)) %>%
  tidyr::pivot_longer(everything(), names_to = "space") %>%
  count(space, value) %>%
  mutate(value = factor(value, levels = c("first year of independence", "same",
                                          "up", "down"))) %>%
  arrange(value) %>%
  tidyr::pivot_wider(names_from = "value", values_from = "n") %>%
  mutate(version = "orig")

tbl_orig$same <- tbl_orig$`first year of independence` + tbl_orig$same
tbl_orig$`first year of independence` <- NULL

tbl_mod <- states_mod |>
  select(all_of(change)) %>%
  tidyr::pivot_longer(everything(), names_to = "space") %>%
  count(space, value) %>%
  mutate(value = factor(value, levels = c("first year of independence", "same",
                                          "up", "down"))) %>%
  arrange(value) %>%
  tidyr::pivot_wider(names_from = "value", values_from = "n") %>%
  mutate(version = "mod")

tbl_mod$same <- tbl_mod$`first year of independence` + tbl_mod$same
tbl_mod$`first year of independence` <- NULL

tbl <- bind_rows(tbl_orig, tbl_mod)
tbl <- tbl %>%
  pivot_longer(c(same, up, down)) %>%
  filter(name!="same") %>%
  tidyr::unite("name2", name, version) %>%
  mutate(value = value/nrow(states)*100,
         name2 = factor(name2, levels = c("up_orig", "up_mod", "down_orig", "down_mod"))) %>%
  arrange(name2) %>%
  pivot_wider(names_from = "name2", values_from = "value")
tbl <- tbl %>%
  mutate(up_change = (up_mod - up_orig)/up_orig * 100,
         down_change = (down_mod - down_orig)/down_orig * 100) %>%
  select(space, up_orig, up_mod, up_change, down_orig, down_mod, down_change)
tbl <- tbl %>%
  mutate(space = gsub("dv_", "", space),
         space = gsub("_change", "", space)
         ) %>%
  left_join(spaces[, c("Indicator", "Space")], by = c("space" = "Indicator")) %>%
  select(Space, everything(), - space)

library(knitr)
library(kableExtra)

tbl %>%
  setNames(c("Space", "Orig", "Mod", "Increase", "Orig", "Mod", "Increase")) %>%
  kbl(format = "latex", booktabs = TRUE, digits = c(0, 1, 1, 0, 1, 1, 0)) %>%
  add_header_above(c("", "Opening" = 3, "Closing" = 3)) %>%
  kable_styling()

