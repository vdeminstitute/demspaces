

library(demspacesR)
library(dplyr)
library(readr)

setwd(here::here("2021-update"))

fcasts11 <- read_csv(here::here("archive/fcasts-rf-v11.csv"))

fcasts2021 <- fcasts11 %>%
  filter(from_year==max(from_year)) %>%
  arrange(desc(p_up)) %>% group_by(outcome) %>%
  mutate(rank_up = n() - rank(p_up, ties.method = "max") + 1,
         rank_down = n() - rank(p_down, ties.method = "max") + 1)  %>%
  ungroup()

top10 <- fcasts2021 %>%
  filter(rank_up < 11 | rank_down < 11)

top10$Country <- states::country_names(top10$gwcode, "GW", TRUE)

data("spaces")
spaces$Description <- NULL

top10 <- left_join(top10, spaces, by = c("outcome" = "Indicator"))
top10 <- top10 %>%
  select(Space, rank_down, rank_up, Country, p_down, p_same, p_up)

ss <- sort(unique(spaces$Space))

for (i in seq_along(ss)) {
  si <- ss[i]
  fn <- sprintf("output/top10-%s.md", tolower(si))
  table_i <- top10 %>%
    filter(Space==!!si) %>%
    mutate(order = ifelse(rank_down < 11, rank_down, rank_up + 10)) %>%
    arrange(order) %>%
    select(-order)
  knitr::kable(table_i, format = "markdown", digits = 2) %>%
    writeLines(., fn)
}



