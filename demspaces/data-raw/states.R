## create dummy states data for testing

library("dplyr")

states <- readRDS("../closing-spaces/2-models/input/states.rds")
states <- states %>%
  select(gwcode, year, ends_with("next2"), starts_with("v2")) %>%
  mutate(binary_x = rbinom(n(), size = 1, prob = 0.2))

usethis::use_data(states, overwrite = TRUE)
