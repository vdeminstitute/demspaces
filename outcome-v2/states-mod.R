#
#   Create a version of the states data with the alternative ERT-lite DV
#   variables
#


library(demspacesR)
library(dplyr)
library(readr)

# needed for changes_one_country()
devtools::load_all()

cutpoints <- read_csv(here::here("create-data/output/cutpoints.csv"))
cp <- cutpoints$up
names(cp) <- cutpoints$indicator

dvs <- readRDS(here::here("create-data/output/dv_data_1958_on.rds"))
states <- readRDS(here::here("archive/data/states-v12.rds"))

# record the correct column order so we can re-order columns for the mod data
# later
cnames_ordered <- colnames(states)

states_mod <- states

updown2 <- dvs[, c("gwcode", "year", spaces$Indicator)]
updown2 <- updown2 %>% filter(!is.na(gwcode))
for (ind in spaces$Indicator) {
  cpi <- cp[[ind]]
  new_col <- sprintf("dv_%s_change", ind)
  updown2 <- updown2 %>%
    dplyr::group_by(gwcode) %>%
    dplyr::arrange(gwcode, year) %>%
    dplyr::mutate(temp = changes_one_country(.data[[ind]], !!cpi))
  updown2[[new_col]] <- updown2$temp
}
updown2$temp <- NULL
updown2[, spaces$Indicator] <- NULL

# for the stuff below, we can't have NAs; set these to "same"
for (var in setdiff(colnames(updown2), c("gwcode", "year"))) {
  updown2[[var]][is.na(updown2[[var]])] <- "same"
}

# updown2 now has the mod dv_[ind]_change columns; we can drop those from
# states_mod and join to bring in the new ones
cols <- sprintf("dv_%s_change", spaces$Indicator)
states_mod[, cols] <- NULL
states_mod <- left_join(states_mod, updown2, by = c("gwcode", "year"))

# now we can create the "up_next2" indicators
# Instead of a hard to read dplyr block with symbols etc. so that we can create
# the correct column names on the fly, just manually loop over the variables
# we want to create and use a temp column.
for (ind in spaces$Indicator) {
  change_col <- sprintf("dv_%s_change", ind)
  up_col     <- sprintf("dv_%s_up_next2", ind)
  down_col   <- sprintf("dv_%s_down_next2", ind)

  states_mod$.change <- states_mod[[change_col]]
  states_mod <- states_mod %>%
    group_by(gwcode) %>%
    arrange(gwcode, year) %>%
    mutate(up = as.integer(.change=="up"),
           lead1_up = lead(up, 1L),
           lead2_up = lead(up, 2L),
           next2_up = pmax(lead1_up, lead2_up),
           down = as.integer(.change=="down"),
           lead1_down = lead(down, 1L),
           lead2_down = lead(down, 2L),
           next2_down = pmax(lead1_down, lead2_down)
    ) %>%
    ungroup()
  states_mod[[up_col]] <- states_mod[["next2_up"]]
  states_mod[[down_col]] <- states_mod[["next2_down"]]
}
# remove temp columns
remove <- c(".change", "up", "lead1_up", "lead2_up", "next2_up", "down",
            "lead1_down", "lead2_down", "next2_down")
states_mod[, remove] <- NULL

# fix column order
stopifnot(all.equal(sort(colnames(states)), sort(colnames(states_mod))))
states_mod <- states_mod[, cnames_ordered]

saveRDS(states_mod, here::here("outcome-v2/data/states-v12-mod.rds"))
