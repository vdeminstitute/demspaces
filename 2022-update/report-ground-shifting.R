#
#   Compare overlap in positive cases between different V-Dem data versions
#

library(here)
library(demspacesR)
library(kableExtra)
library(dplyr)
library(tidyr)
library(ggrepel)
library(stringr)
library(tibble)

setwd(here::here("2022-update"))

states9 <- readRDS(here::here("archive/data/states-v9.rds"))
states10 <- readRDS(here::here("archive/data/states-v10.rds"))
states11 <- readRDS(here::here("archive/data/states-v11.rds"))
states12 <- readRDS(here::here("archive/data/states-v12.rds"))
states12.1 <- readRDS(here::here("archive/data/states-v12.1.rds"))

states9 <- states9 %>%
  select(gwcode, year, ends_with("change")) %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change") %>%
  mutate(version = 9) %>%
  filter(complete.cases(.))

states10 <- states10 %>%
  select(gwcode, year, ends_with("change")) %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change") %>%
  mutate(version = 10)

states11 <- states11 %>%
  select(gwcode, year, ends_with("change"))  %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change") %>%
  mutate(version = 11)

states12 <- states12 %>%
  select(gwcode, year, ends_with("change"))  %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change") %>%
  mutate(version = 12)

states12.1 <- states12.1 %>%
  select(gwcode, year, ends_with("change"))  %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "change") %>%
  mutate(version = 12.1)

all <- bind_rows(states9, states10, states11, states12, states12.1) %>%
  mutate(space = str_remove(space, "_change")) %>%
  mutate(space = str_remove(space, "dv_")) %>%
  mutate(version = paste0("v", version)) %>%
  # reduce to common, non-missing subset
  filter(year <= max(states9$year))

wide_all <- all %>%
  arrange(space, gwcode, year, version) %>%
  pivot_wider(names_from = "version", values_from = "change")

# Wide table of positive cases (OR, i.e. in any of the data versions) only
pos <- all %>%
  group_by(gwcode, year, space) %>%
  filter(any(change %in% c("up", "down"))) %>%
  arrange(space, gwcode, year, version) %>%
  pivot_wider(names_from = "version", values_from = "change")


# Agreement tables --------------------------------------------------------

# v9 and v11
pos %>%
  filter(!(v9=="same" & v11=="same")) %>%
  # v9 seems to have used 1993 rather than 1991 for North Macedonia indy,
  # which is COW, not G&W coding
  filter(v9!="first year of independence") %>%
  with(., table(v9 = v9, v11 = v11))

pos %>%
  filter(!(v9=="same" & v11=="same")) %>%
  with(., mean(v9==v11))

# v9 and v10
pos %>%
  filter(!(v9=="same" & v10=="same")) %>%
  # v9 seems to have used 1993 rather than 1991 for North Macedonia indy,
  # which is COW, not G&W coding
  filter(v9!="first year of independence") %>%
  with(., table(v9 = v9, v10 = v10))

pos %>%
  filter(!(v9=="same" & v10=="same")) %>%
  with(., mean(v9==v10))

# v10 and v11
pos %>%
  filter(!(v10=="same" & v11=="same")) %>%
  with(., table(v10 = v10, v11 = v11))

pos %>%
  filter(!(v10=="same" & v11=="same")) %>%
  with(., mean(v10==v11))

# v11 and v12
pos %>%
  filter(!(v11=="same" & v12=="same")) %>%
  with(., table(v11 = v11, v12 = v12))

pos %>%
  filter(!(v11=="same" & v12=="same")) %>%
  with(., mean(v11==v12))

#
#   Outcome crosstab for v11 - v12 ----
#   __________________

tbl <- bind_rows(states11, states12) %>%
  mutate(space = str_remove(space, "_change")) %>%
  mutate(space = str_remove(space, "dv_")) %>%
  mutate(version = paste0("v", version)) %>%
  filter(version %in% c("v11", "v12")) %>%
  filter(year > 2009, year < 2021) %>%
  filter(change!="first year of independence") %>%
  pivot_wider(names_from = "version", values_from = "change") %>%
  count(v11, v12) %>%
  pivot_wider(names_from = "v12", values_from = "n") %>%
  mutate(down = ifelse(is.na(down), 0, down),
         up = ifelse(is.na(up), 0, up))

write_csv(tbl, "report-data/tbl-v11-v12.csv")


#
#   Outcome crosstab for v10 - v12 ----
#   __________________

tbl <- bind_rows(states10, states12) %>%
  mutate(space = str_remove(space, "_change")) %>%
  mutate(space = str_remove(space, "dv_")) %>%
  mutate(version = paste0("v", version)) %>%
  filter(version %in% c("v10", "v12")) %>%
  filter(year > 2009, year < 2020) %>%
  filter(change!="first year of independence") %>%
  pivot_wider(names_from = "version", values_from = "change") %>%
  count(v10, v12) %>%
  pivot_wider(names_from = "v12", values_from = "n") %>%
  mutate(down = ifelse(is.na(down), 0, down),
         up = ifelse(is.na(up), 0, up))

write_csv(tbl, "report-data/tbl-v10-v12.csv")


#
#   v9 - v11 confusion matrix table for paper
#   _________________

recode <- function(x) {
  out <- rep(NA, length(x))
  out <- ifelse(x=="down", "Closing", out)
  out <- ifelse(x=="up", "Opening", out)
  out <- ifelse(x=="same", "No change", out)
  out
}

#
#   Agreement with previous version for v10:v12 ----
#

pos_long <- pos %>%
  pivot_longer(c(v9, v10, v11, v12, v12.1), names_to = "version", values_to = "change")
to <- pos_long %>%
  rename(version2 = version, change2 = change)
# joint the comparison groups and take out combinations of data versions that
# I don't want to compare
comp <- full_join(pos_long, to) %>%
  mutate(comparison = paste0(version, "-", version2))
# This has cases that are positive in any version; now i just need positives
# for the versions in each comparison
comp <- comp %>%
  filter(!(change=="same" & change2=="same"))

# Ok, now I can calculate the actual agreement rates
tbl <- comp %>%
  group_by(comparison) %>%
  summarize(ag_rate = mean(change==change2),
            .groups = "drop") %>%
  filter(comparison %in% c("v9-v10", "v10-v11", "v11-v12", "v9-v11", "v10-v12", "v12-v12.1")) %>%
  mutate(comparison = factor(comparison, levels = c("v9-v10", "v10-v11", "v11-v12", "v9-v11", "v10-v12", "v12-v12.1"))) %>%
  arrange(comparison)

readr::write_csv(tbl, "report-data/tbl-agreement.csv")


#
#   Table: opening/closing events by data version ----
#   _________________________

pos_long %>%
  ungroup() %>%
  count(version, space, change) %>%
  filter(change %in% c("up", "down")) %>%
  pivot_wider(names_from = "change", values_from = "n") %>%




##### old stuff
stop("Old stuff below")

# (Also by space if needed)
comp %>%
  group_by(comparison, space) %>%
  summarize(ag_rate = mean(change==change2)) %>%
  pivot_wider(names_from = "comparison", values_from = "ag_rate") -> foo
# Interesting variation

# Write table for report
comp %>%
  group_by(comparison) %>%
  summarize(ag_rate = mean(change==change2)) %>%
  mutate(comparison = factor(comparison,
                             levels = c("v9-v11", "v9-v10", "v10-v11")),
         ag_rate = round(ag_rate*100, 1)) %>%
  arrange(comparison) %>%
  rename(Comparison = comparison, `Agreement %` = ag_rate) %>%
  kbl("latex", booktabs = TRUE,
      caption = "Agreement rate for positive cases in different V-Dem data versions",
      label = "versions-comp") %>%
  writeLines(here::here("2021-update/output/table-versions-comp.tex"))

# Crosstabs by space. Which space has the most changes?
xtabs <- all %>%
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

# SIDETRACK
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


by_year <- pos %>%
  group_by(year) %>%
  dplyr::summarize(
    v9change = sum(v9 %in% c("down", "up")),
    v11change = sum(v11 %in% c("down", "up")),
    agree = sum(v9==v11),
    agree_rate = mean(v9==v11),
    .groups = "drop")

with(by_year, plot(year, agree_rate, type = "l", ylim = c(0, 1)))


by_year <- pos %>%
  group_by(year) %>%
  dplyr::summarize(
    v9change = sum(v9 %in% c("down", "up")),
    v10change = sum(v10 %in% c("down", "up")),
    agree = sum(v9==v10),
    agree_rate = mean(v9==v10),
    .groups = "drop")

with(by_year, plot(year, agree_rate, type = "l", ylim = c(0, 1)))



# Plot raw y2y diffs ------------------------------------------------------

# Compare the raw changes for up/down cases
states9 <- readRDS(here::here("archive/states-v9.rds"))
diffs9 <- states9 %>%
  select(gwcode:dv_v2x_pubcorr_down_next2) %>%
  select(gwcode, year, ends_with("y2y")) %>%
  pivot_longer(-c(gwcode, year), names_to = "space", values_to = "diff") %>%
  mutate(version = 9,
         space = str_remove(space, "_diff_y2y")) %>%
  mutate(space = str_remove(space, "dv_"))

states11 <- readRDS(here::here("archive/states-v11.rds"))
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

both_diffs <- bind_rows(diffs9, diffs11) %>%
  ungroup() %>%
  mutate(version = paste0("diff_v", version)) %>%
  pivot_wider(names_from = "version", values_from = "diff")

# I only want to do this for positive cases in either dataset, so
# use the positives sets I already have
diffs <- pos %>%
  select(gwcode, year, space, v9, v11) %>%
  filter(!(v9=="same" & v11=="same")) %>%
  left_join(both_diffs) %>%
  mutate(change = as.factor(as.integer(v9!=v11))) %>%
  # because I'm hacking v11 diffs, loosing 1970 data...
  filter(year > 1970)

# back-engineer thresholds
v9 <- diffs %>%
  filter(v9=="up") %>%
  group_by(space) %>%
  summarize(x2 = min(diff_v9))
v9$x1 <- v9$x2*-1

v11 <- diffs %>%
  filter(v11=="up") %>%
  group_by(space) %>%
  summarize(y2 = min(diff_v11))
v11$y1 <- v11$y2*-1

# points to highlight for paper discussion
# to find:
diffs %>% filter(v9=="down", v11 == "same", diff_v11 < 0, space =="v2x_horacc_osp") %>% arrange(diff_v9)
hl <- tibble(space = "v2x_horacc_osp",
             gwcode = c(420, 490, 770),
             year = c(1995, 1992, 2002),
             label = c("1: Gambia 1995", "2: DRC 1992", "3: Pakistan 2002")) %>%
  left_join(diffs)

# change space labels; need a name character vector
data("spaces")
panels <- spaces %>% select(Indicator, Space) %>% deframe()

ggplot(diffs) +
  facet_wrap(~space, labeller = labeller(space = panels)) +
  # v9 thresholds
  geom_rect(data = v9, aes(xmin = x1, xmax = x2), ymin = -1, ymax = 1,
            alpha = .1) +
  # v11 thresholds
  geom_rect(data = v11, aes(ymin = y1, ymax = y2), xmin = -1, xmax = 1,
            alpha = .1) +
  geom_point(aes(x = diff_v9, y = diff_v11, color = change),
             alpha = 0.7) +
  scale_color_discrete("Case codings", labels = c("Disagree", "Agree")) +
  scale_x_continuous(limits = c(-.9, .9)) +
  scale_y_continuous(limits = c(-.9, .9)) +
  theme_minimal() +
  theme(panel.grid.minor = element_blank(),
        panel.background = element_rect(),
        legend.position = "top",
        strip.text.x = element_text(size = 12, face = "bold")) +
  geom_hline(yintercept = 0, color = "gray50") +
  geom_vline(xintercept = 0, color = "gray50") +
  geom_point(data = hl, aes(x = diff_v9, y = diff_v11)) +
  geom_label_repel(data = hl, aes(x = diff_v9, y = diff_v11, label = label),
                   box.padding = .5, size = 3) +
  labs(x = "Year-to-year change in space, v9 data",
       y = "Year-to-year change in space, v11 data")

ggsave(filename = here::here("2021-update/output/diffs-v9-v11.png"),
       height = 6, width = 8)



# How often same direction? -----------------------------------------------
#
#   When the opening/closing event coding disagrees, how often is the direction
#   of change at least still the same?
#

disagreement <- diffs %>%
  filter(v9!=v11) %>%
  mutate(same_direction = (diff_v9 > 0 & diff_v11 > 0) |
           (diff_v9 < 0 & diff_v11 < 0))

# Direction agreement by space
disagreement %>%
  group_by(space) %>%
  summarize(n = n(),
            agree_n = sum(same_direction),
            agree_p = mean(same_direction))

# Overall direction agreement
disagreement %>%
  group_by(space) %>%
  summarize(n = n(),
            agree_n = sum(same_direction),
            agree_p = mean(same_direction)) %>%
  ungroup() %>%
  summarize(n = sum(n),
            agree_n = sum(agree_n),
            agree_p = mean(agree_p))

# Pooled overall direction agreement
table(disagreement$same_direction)
mean(disagreement$same_direction)


