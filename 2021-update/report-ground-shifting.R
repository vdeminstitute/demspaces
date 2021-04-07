
library(here)
library(demspacesR)

setwd(here::here())

states10 <- readRDS(here::here("archive/states-v10.rds"))
states11 <- readRDS(here::here("archive/states-v11b.rds"))

states10 <- states10 %>%
  select(gwcode, year, ends_with("change")) %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change") %>%
  mutate(version = 10)

states11 <- states11 %>%
  select(gwcode, year, ends_with("change"))  %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change") %>%
  mutate(version = 11) %>%
  filter(year %in% unique(states10$year))

both <- bind_rows(states10, states11) %>%
  mutate(space = str_remove(space, "_change")) %>%
  mutate(space = str_remove(space, "dv_"))

pos <- both %>%
  group_by(gwcode, year, space) %>%
  filter(any(change %in% c("up", "down"))) %>%
  arrange(space, gwcode, year, version) %>%
  mutate(version = paste0("v", version)) %>%
  pivot_wider(names_from = "version", values_from = "change")

table(v10 = pos$v10, v11 = pos$v11)

mean(pos$v10==pos$v11)

# Crosstabs by space. Which space has the most changes?
xtabs <- both %>%
  mutate(version = paste0("v", version)) %>%
  pivot_wider(names_from = "version", values_from = "change") %>%
  count(space, v10, v11)

xtabs %>%
  mutate(
    # match negative case
    v10 = ifelse(v10==v11 & v10 %in% c("same", "first year of independence"),
                 "match negative", v10),
    v11 = ifelse(v10=="match negative", "match negative", v11),
    # match positive case
    v10 = ifelse(v10==v11 & v10 %in% c("up", "down"),
                 "match positive", v10),
    v11 = ifelse(v10=="match positive", "match positive", v11)) %>%
  group_by(space, v10, v11) %>%
  summarize(n = sum(n)) %>%
  arrange(space, desc(n))

# Does agreement change by year?
by_year <- pos %>%
  group_by(year) %>%
  dplyr::summarize(
    v10change = sum(v10 %in% c("down", "up")),
    v11change = sum(v11 %in% c("down", "up")),
    agree = sum(v10==v11),
    agree_rate = mean(v10==v11),
    .groups = "drop")

with(by_year, plot(year, agree_rate, type = "l", ylim = c(0, 1)))




# Compare the raw changes for up/down cases
states10 <- readRDS(here::here("archive/states-v10.rds"))
diffs10 <- states10 %>%
  select(gwcode:dv_v2x_pubcorr_down_next2) %>%
  select(gwcode, year, ends_with("y2y")) %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "diff") %>%
  mutate(version = 10,
         space = str_remove(space, "_diff_y2y")) %>%
  mutate(space = str_remove(space, "dv_"))

states11 <- readRDS(here::here("archive/states-v11b.rds"))
diff2 <- function(x) c(NA, diff(x))
diffs11 <- states11 %>%
  # need to manually add diffs; i took those out in v11
  select(gwcode, year, one_of(spaces$Indicator), ends_with("_change")) %>%
  group_by(gwcode) %>%
  arrange(gwcode, year) %>%
  mutate_at(vars(one_of(spaces$Indicator)), list(diff2)) %>%
  ungroup() %>%
  # back to regular programming
  select(-ends_with("_change")) %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "diff") %>%
  mutate(version = 11,
         space = str_remove(space, "_diff_y2y")) %>%
  mutate(space = str_remove(space, "dv_"))

both_diffs <- bind_rows(diffs10, diffs11) %>%
  mutate(version = paste0("diff_v", version)) %>%
  pivot_wider(names_from = "version", values_from = "diff")

foo <- pos %>%
  left_join(both_diffs)

ggplot(foo, aes(x = diff_v10, y = diff_v11)) +
  facet_wrap(~space) +
  geom_point()

hist(foo$diff_v11 - foo$diff_v10)



