#
#   This script cleans/processes various data sets from create-data/ and
#   modelrunner/.
#
#   Originally Laura Maxwell & Rick Morgan
#   2021 changes/updates by Andreas Beger
#
#   Input:
#     - fcasts-rf-2020.csv: forecasts created in March 2020;
#       from modelrunnner/output/fcasts-rf.csv (file has just been renamed)
#     - dv_data_1968_on.csv: from create-data/scripts/0-split-raw-vdem.R
#
#   Output:
#     - map_dat.rds
#     - country_characteristic_dat.RDS
#     - prob1_dat.rds
#     - rank_data_up.rds
#     - rank_data_down.rds
#

library(tidyverse)
library(magrittr)
library(sf)
library(rmapshaper)
library(rgeos)
library(rgdal)
library(cshapes)
library(here)
library(yaml)

setwd(here::here("dashboard"))

iri_dat <- read.csv("data-raw/fcasts-rf-v11b.csv", stringsAsFactors = F)
current_forecast <- iri_dat %>%
  filter(from_year == max(from_year))
outcomes <- unique(iri_dat$outcome)

dvs <- read_csv("data-raw/dv_data_1968_on.csv") %>%
  filter(year >= 2000)

current_dvs <- dvs %>%
  dplyr::select(gwcode, year, country_name, country_id, country_text_id, e_regionpol_6C,
                v2x_veracc_osp, v2xcs_ccsi, v2xcl_rol, v2x_freexp_altinf, v2x_horacc_osp, v2x_pubcorr) %>%
  tidyr::gather(outcome, level, -gwcode, -year, -country_name, -country_id, -country_text_id, -e_regionpol_6C) %>%
  #dplyr::mutate(level = as.numeric(level)) %>%
  dplyr::group_by(outcome, country_name) %>%
  dplyr::arrange(year) %>%
  dplyr::mutate(change = c(NA, diff(level, lag = 1))) %>%
  dplyr::filter(year == max(year)) %>%
  dplyr::arrange(country_name)

region_labels <- data.frame(names = c("E. Europe and Central Asia", "Latin America and the Caribbean", "Middle East and N. Africa", "Sub-Saharan Africa", "W. Europe and N. America*", "Asia and Pacific"),
                            level = 1:6)
space_labels <-  data.frame(names = c("Electoral", "Governing", "Individual", "Associational", "Informational", "Economic"),
                            outcome = c("v2x_veracc_osp", "v2x_horacc_osp", "v2xcl_rol", "v2xcs_ccsi", "v2x_freexp_altinf", "v2x_pubcorr"), stringsAsFactors = F)

thres_labels <-  data.frame(thres = c("+/-0.08", "+/-0.06", "+/-0.04", "+/-0.05", "+/-0.05", "+/-0.03"),
                            outcome = c("v2x_veracc_osp", "v2x_horacc_osp", "v2xcl_rol", "v2xcs_ccsi", "v2x_freexp_altinf", "v2x_pubcorr"), stringsAsFactors = F)
vdem_labels <- data.frame(index_name = c("V-Dem&apos;s Vertical Accountability Index", "V-Dem&apos;s Horizontal Accountability Index", "V-Dem&apos;s Equality Before the Law and Individual Liberty Index", "V-Dem&apos;s Core Civil Society Index", "V-Dem&apos;s Freedom of Expression and Alternative Sources of Information Index", "V-Dem&apos;s Public Corruption Index"),
                          outcome = c("v2x_veracc_osp", "v2x_horacc_osp", "v2xcl_rol", "v2xcs_ccsi", "v2x_freexp_altinf", "v2x_pubcorr"), stringsAsFactors = F)

all_forecast_data <- current_forecast %>%
  left_join(current_dvs, by = c("outcome", "from_year" = "year", "gwcode")) %>%
  dplyr::select(gwcode, country_name, outcome, year = from_year, for_years, region = e_regionpol_6C, level, change, p_up, p_down, p_same) %>%
  group_by(outcome) %>%
  arrange(desc(p_down)) %>%
  dplyr::mutate(down_rank = row_number()) %>%
  arrange(desc(p_up)) %>%
  dplyr::mutate(up_rank = row_number()) %>%
  left_join(space_labels) %>%
  left_join(thres_labels) %>%
  left_join(vdem_labels)

all_forecast_data$change <- ifelse(all_forecast_data$change > 0, paste0("+", round(all_forecast_data$change,3)), round(all_forecast_data$change,3))

#add colors

colfunc1 <- colorRampPalette(c("#E2F1F7", "#0082BA"))
colfunc2 <- colorRampPalette(c("#FDEFE6", "#F37321"))
colors_down  = c(colfunc2(5), "#D0D0D1")
colors_up  = c(colfunc1(5), "#D0D0D1")

all_forecast_data$map_color_up <- ifelse(all_forecast_data$p_up < 0.05, colors_up[1],
                                         ifelse(all_forecast_data$p_up < 0.15, colors_up[2],
                                                ifelse(all_forecast_data$p_up < 0.25, colors_up[3],
                                                       ifelse(all_forecast_data$p_up < 0.35, colors_up[4],
                                                              ifelse(!is.na(all_forecast_data$p_up), colors_up[5], colors_up[6])))))


all_forecast_data$map_color_down <- ifelse(all_forecast_data$p_down < 0.05, colors_down[1],
                                           ifelse(all_forecast_data$p_down < 0.15, colors_down[2],
                                                  ifelse(all_forecast_data$p_down < 0.25, colors_down[3],
                                                         ifelse(all_forecast_data$p_down < 0.35, colors_down[4],
                                                                ifelse(!is.na(all_forecast_data$p_down), colors_down[5], colors_down[6])))))

all_forecast_data$popUp_text_up <- paste('<h3><b>', all_forecast_data$country_name,'</b></h3>',
                                         '<h5><span style="color:#002649">Event probabilities for the <b>', all_forecast_data$names, ' Space</b> <span style="font-size: 80%">(', all_forecast_data$thres, ' change in <b>', all_forecast_data$index_name, '</b>)</span></span></h5>',
                                         paste('<b><span style="color:#0082BA">Opening Event: ',floor(all_forecast_data$p_up * 100), '%</b></span><br>', sep = ''),
                                         paste('<b><span style="color:#777778">Stable: ',floor(all_forecast_data$p_same * 100), '%</b></span><br>', sep = ''),
                                         paste('<b><span style="color:#F37321">Closing Event: ',floor(all_forecast_data$p_down * 100), '%</b></span><br><br>', sep = ''),
                                         paste('<b><span style="color:#0082BA"> Opening </span><span style="color:#002649">Risk Ranking: ', all_forecast_data$up_rank, '</b></span><br>', sep = ''),
                                         paste('<b><span style="color:#F37321"> Closing </span><span style="color:#002649">Risk Ranking: ', all_forecast_data$down_rank, '</b></span><br>', sep = ''),
                                         paste('<b><span style="color:#002649"> ',all_forecast_data$names,' Level in 2020: ', all_forecast_data$level, '</b></span><br>', sep = ''),
                                         paste('<b><span style="color:#002649"> ',all_forecast_data$names,' Change 2018-2020: ', all_forecast_data$change, '</b></span>', sep = ''),sep = '')

all_forecast_data$popUp_text_down <- paste('<h3><b>', all_forecast_data$country_name,'</b></h3>',
                                           '<h5><span style="color:#002649">Event probabilities for the <b>', all_forecast_data$names, ' Space</b> <span style="font-size: 80%">(', all_forecast_data$thres, ' change in the <b>', all_forecast_data$index_name, '</b>)</span></h5>',
                                           paste('<b><span style="color:#F37321">Closing Event: ',floor(all_forecast_data$p_down * 100), '%</b></span><br>', sep = ''),
                                           paste('<b><span style="color:#777778">Stable: ',floor(all_forecast_data$p_same * 100), '%</b></span><br>', sep = ''),
                                           paste('<b><span style="color:#0082BA">Opening Event: ',floor(all_forecast_data$p_up * 100), '%</b></span><br><br>', sep = ''),
                                           paste('<b><span style="color:#F37321"> Closing </span><span style="color:#002649">Risk Ranking: ', all_forecast_data$down_rank, '</b></span><br>', sep = ''),
                                           paste('<b><span style="color:#0082BA"> Opening </span><span style="color:#002649">Risk Ranking: ', all_forecast_data$up_rank, '</b></span><br>', sep = ''),
                                           paste('<b><span style="color:#002649"> ',all_forecast_data$names,' Level in 2020: ', all_forecast_data$level, '</b></span><br>', sep = ''),
                                           paste('<b><span style="color:#002649"> ',all_forecast_data$names,' Change 2019-2020: ', all_forecast_data$change, '</b></span>', sep = ''),sep = '')

all_forecast_data$popUp_text_down <- paste('<h3><b>', all_forecast_data$country_name,'</b></h3>',
                                            '<h5><span style="color:#002649">Event probabilities for the <b>', all_forecast_data$names, ' Space</b> <span style="font-size: 80%">(', all_forecast_data$thres, ' change in the <b>', all_forecast_data$index_name, '</b>)</span></h5>',
                                            paste('<b><span style="color:#F37321">Closing Event: ',floor(all_forecast_data$p_down * 100), '%</b></span><br>', sep = ''),
                                            paste('<b><span style="color:#777778">Stable: ',floor(all_forecast_data$p_same * 100), '%</b></span><br>', sep = ''),
                                            paste('<b><span style="color:#0082BA">Opening Event: ',floor(all_forecast_data$p_up * 100), '%</b></span><br><br>', sep = ''),
                                            paste('<b><span style="color:#F37321"> Closing </span><span style="color:#002649">Risk Ranking: ', all_forecast_data$down_rank, '</b></span><br>', sep = ''),
                                            paste('<b><span style="color:#0082BA"> Opening </span><span style="color:#002649">Risk Ranking: ', all_forecast_data$up_rank, '</b></span><br>', sep = ''),
                                            paste('<b><span style="color:#002649"> ',all_forecast_data$names,' Level in 2020: ', all_forecast_data$level, '</b></span><br>', sep = ''),
                                            paste('<b><span style="color:#002649"> ',all_forecast_data$names,' Change 2019-2020: ', all_forecast_data$change, '</b></span>', sep = ''),sep = '')


# Map data ----------------------------------------------------------------

raw_map_data <- cshapes::cshp(date = as.Date("2013/01/01"), useGW = TRUE)
raw_map_data <- rmapshaper::ms_simplify(raw_map_data, keep = 0.2)

# Convert to an sf object
map_data <- st_as_sf(raw_map_data)
map_data <- map_data %>%
  st_transform("+proj=longlat +datum=WGS84")
map_data <- map_data %>%
  select(GWCODE) %>%
  dplyr::rename(gwcode = GWCODE)

# Add centroid lat/long
centroids <- map_data %>% st_centroid() %>% st_coordinates()
map_data$center_lon <- centroids[, 1]
map_data$center_lat <- centroids[, 2]

forecast_colors <- all_forecast_data %>%
  dplyr::select(gwcode, country_name, year, outcome, map_color_up, map_color_down, p_up, p_down, p_same, popUp_text_up, popUp_text_down, level, change) %>%
  pivot_wider(names_from = outcome, values_from = c(map_color_down, map_color_up, level, change, p_up, p_down, p_same, popUp_text_up, popUp_text_down))

map_data <- map_data %>%
  left_join(forecast_colors)

# Some countries that are not covered by the forecasts will have missing map
# color and other values. Set the map color for missing to gray.
cnames <- colnames(map_data)[grepl("^map_", colnames(map_data))]
for (cc in cnames) {
  map_data[[cc]] <- ifelse(is.na(map_data[[cc]]), "#D0D0D1", map_data[[cc]])
}

write_rds(map_data, "data/map_dat.rds", compress = "none")

# Keep a readable sample of the data so we can easily spot differences on git
# The .rds version will always show as changed on git.
test <- map_data[1:5, ] %>% st_set_geometry(NULL)
write_csv(test, here::here("dashboard/data-raw/map_dat_sample.csv"))


# Other; not cleaned up yet -----------------------------------------------



country_characteristic_dat <- dvs %>%
  dplyr::select(gwcode, year, country_name,
                v2x_veracc_osp, v2xcs_ccsi, v2xcl_rol, v2x_freexp_altinf, v2x_horacc_osp, v2x_pubcorr) %>%
  filter(year >= 2011)

write_rds(country_characteristic_dat, "data/country_characteristic_dat.RDS")

# Keep a signature of key stats for git diff
# The .rds version will always show as changed on git.
dat <- country_characteristic_dat
sig <- list(
  N_rows = nrow(dat),
  N_cols = ncol(dat),
  N_missing = nrow(dat) - sum(complete.cases(dat)),
  Countries = length(unique(dat$country_name)),
  Years = paste0(range(dat$year), collapse = "-")
)
write_yaml(sig, here::here("dashboard/data-raw/country_characteristic_dat_signature.yml"))


prob1_dat <- all_forecast_data %>%
  dplyr::select(-for_years, -year, -gwcode, -level) %>%
  pivot_longer(cols = c(p_up, p_down, p_same), names_to = "direction") %>%
  mutate(colors = case_when(direction == "p_up" ~ colors_up[5],
                            direction == "p_same" ~ "#D0D0D1",
                            direction == "p_down" ~ colors_down[5])) %>%

  mutate(direction = case_when(direction == "p_up" ~ "Opening",
                               direction == "p_same" ~ "Neither",
                               direction == "p_down" ~ "Closing")) %>%
  dplyr::select(-map_color_up, -map_color_down)

prob1_dat %<>%
  left_join(space_labels) %>%
  na.omit()

prob1_dat$names <- factor(prob1_dat$names, levels = c("Associational", "Economic", "Electoral", "Governing", "Individual", "Informational"), ordered = T)
prob1_dat$outcome <- factor(prob1_dat$outcome, levels = c( "v2xcs_ccsi", "v2x_pubcorr", "v2x_veracc_osp", "v2x_horacc_osp", "v2xcl_rol", "v2x_freexp_altinf"), ordered = T)

write_rds(prob1_dat, "data/prob1_dat.rds")

rank_data_up <- all_forecast_data %>%
  dplyr::group_by(outcome) %>%
  arrange(desc(p_up)) %>%
  dplyr::mutate(rank = row_number(), color_prob = map_color_up, risk = p_up) %>%
  filter(rank <= 20)

write_rds(rank_data_up, "data/rank_data_up.rds")

rank_data_down <- all_forecast_data %>%
  dplyr::group_by(outcome) %>%
  arrange(desc(p_down)) %>%
  dplyr::mutate(rank = row_number(), color_prob = map_color_down, risk = p_down) %>%
  filter(rank <= 20)

write_rds(rank_data_down, "data/rank_data_down.rds")
