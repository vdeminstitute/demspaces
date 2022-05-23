#
#   Basic outcome states for the orig and mod data
#

library(here)
library(dplyr)
library(stringr)

states <- readRDS(here::here("archive/data/states-v12.rds"))
states_mod <- readRDS(here::here("outcome-v2/data/states-v12-mod.rds"))

tbl1 <- states %>%
  select(ends_with("next2")) %>%
  pivot_longer(everything()) %>%
  group_by(name) %>%
  summarize(value = sum(value, na.rm = TRUE))

tbl2 <- states_mod %>%
  select(ends_with("next2")) %>%
  pivot_longer(everything()) %>%
  group_by(name) %>%
  summarize(value = sum(value, na.rm = TRUE))

tbl1 <- tbl1 %>%
  mutate(name = str_remove(name, "dv_"),
         name = str_remove(name, "_next2")) %>%
  mutate(direction = ifelse(str_detect(name, "down"), "down_orig", "up_orig"),
         name = str_remove(name, "_(down|up)")) %>%
  pivot_wider(names_from = "direction", values_from = "value")

tbl2 <- tbl2 %>%
  mutate(name = str_remove(name, "dv_"),
         name = str_remove(name, "_next2")) %>%
  mutate(direction = ifelse(str_detect(name, "down"), "down_mod", "up_mod"),
         name = str_remove(name, "_(down|up)")) %>%
  pivot_wider(names_from = "direction", values_from = "value")

tbl <- full_join(tbl1, tbl2) %>%
  select(name, down_orig, down_mod, up_orig, up_mod)

# counts
tbl

# positive rates
n <- sum(!is.na(states$dv_v2x_freexp_altinf_up_next2))
tbl[, 2:5] <- tbl[, 2:5]/n





