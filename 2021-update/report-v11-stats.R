#
#   How many positive outcomes are there in each space? (table)
#

library(kableExtra)

states11 <- readRDS(here::here("archive/states-v11.rds"))
states11 <- states11 %>%
  select(gwcode, year, ends_with("change"))  %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change")

states11 <- states11 %>%
  mutate(space = str_remove(space, "_change")) %>%
  mutate(space = str_remove(space, "dv_"))

data("spaces")
spaces$Description <- NULL

states <- left_join(states11, spaces, by = c("space" = "Indicator"))

tbl <- states %>%
  group_by(Space) %>%
  summarize(Open = sum(change=="up"),
            Close = sum(change=="down"),
            Total = Open + Close,
            # man this is hacky (spaces in name to have duplicate columns)
            `Open ` = mean(change=="up")*1000,
            `Close ` = mean(change=="down")*1000,
            `Total ` = Total / n()*1000)

avg <- tbl %>%
  summarize_all(mean) %>%
  mutate(Space = "")

tbl %>%
  bind_rows(avg) %>%
  kbl(format = "latex", digits = c(0, 0, 0, 0, 1, 1, 1),
               caption = "Opening and closing events and event rates per thousand, 1970--2020, using v11 data",
               label = "v11-stats", booktabs = TRUE) %>%
  pack_rows("Average", 7, 7) %>%
  add_header_above(c(" ", "Number" = 3, "Rater per 1,000" = 3)) %>%
  writeLines(here::here("2021-update/output/table-v11-stats.tex"))
