#
#   Compare current to previous forecast
#

library(demspaces.dev)

library(ggplot2)



# Compare to previous forecasts -------------------------------------------

current_fcasts <- read_forecasts("v13")
current_fcasts <- current_fcasts[with(current_fcasts, from_year==max(from_year)), ]

previous_fcasts <- read_forecasts("v12.1")
previous_fcasts <- previous_fcasts[with(previous_fcasts, from_year==max(from_year)), ]

fcast_delta <- bind_rows(current_fcasts, previous_fcasts)
fcast_delta <- fcast_delta |>
  arrange(from_year) |>
  group_by(outcome, gwcode) |>
  summarize(p_up_delta = diff(p_up),
            p_same_delta = diff(p_same),
            p_down_delta = diff(p_down),
            .groups = "drop")

wtg <- read_csv("https://gist.githubusercontent.com/maartenzam/787498bbc07ae06b637447dbd430ea0a/raw/9a9dafafb44d8990f85243a9c7ca349acd3a0d07/worldtilegrid.csv")
wtg$gwcode <- countrycode::countrycode(wtg$alpha.3, "iso3c", "gwn")
wtg$gwcode[wtg$alpha.3=="XKX"] <- 347
wtg$gwcode[wtg$alpha.3=="VNM"] <- 816
wtg$gwcode[wtg$alpha.3=="YEM"] <- 678
# add a row for taiwan
wtg <- bind_rows(wtg,
                 data.frame(name = "Taiwan", region = "Asia", x = 26, y = 7, gwcode = 713))
wtg <- wtg[, c("gwcode", "name", "region", "x", "y", "alpha.3")]

wtg |>
  dplyr::left_join(fcast_delta, by = "gwcode") |>
  dplyr::select(-p_same_delta) |>
  dplyr::filter(!is.na(outcome)) |>
  tidyr::pivot_longer(c(p_up_delta, p_down_delta), names_to = "direction") |>
  dplyr::mutate(direction = ifelse(grepl("up", direction), "up", "down")) |>
  ggplot(aes(x = x, y = y)) +
  geom_tile(aes(fill = value), color = "black") +
  facet_grid(outcome ~ direction) +
  scale_fill_distiller(type = "div", palette = 5) +
  scale_y_reverse() +
  theme_minimal() +
  theme(
    legend.position = "top"
  )

wtg |>
  dplyr::left_join(current_fcasts, by = "gwcode") |>
  dplyr::select(-p_same) |>
  dplyr::filter(!is.na(outcome)) |>
  tidyr::pivot_longer(c(p_up, p_down), names_to = "direction") |>
  dplyr::mutate(direction = ifelse(grepl("up", direction), "up", "down")) |>
  ggplot(aes(x = x, y = y)) +
  geom_tile(aes(fill = value), color = "black") +
  facet_grid(outcome ~ direction) +
  scale_fill_distiller(type = "div", palette = 5) +
  scale_y_reverse() +
  theme_minimal() +
  theme(
    legend.position = "top"
  )

fcast_delta |>
  dplyr::select(-p_same_delta) |>
  dplyr::filter(!is.na(outcome)) |>
  tidyr::pivot_longer(c(p_up_delta, p_down_delta), names_to = "direction") |>
  dplyr::mutate(direction = ifelse(grepl("up", direction), "up", "down")) |>
  ggplot(aes(x = gwcode, y = value)) +
  facet_grid(outcome ~ direction) +
  geom_point() +
  coord_flip()

fcast_delta |>
  dplyr::select(-p_same_delta) |>
  dplyr::filter(!is.na(outcome)) |>
  tidyr::pivot_longer(c(p_up_delta, p_down_delta), names_to = "direction") |>
  dplyr::mutate(direction = ifelse(grepl("up", direction), "up", "down")) |>
  ggplot(aes(y = factor(gwcode), x = value)) +
  geom_point(aes(color = direction, shape = outcome)) +
  scale_y_reverse()



# Correlation of up and down forecasts ------------------------------------

fcasts <- read_forecasts()

ggplot(fcasts, aes(x = p_up, y = p_down)) +
  geom_bin_2d(binwidth = 0.02, color = "white") +
  scale_fill_viridis_c("Cases", trans = "log10", option = "magma") +
  labs(x = "Opening Forecast", y = "Closing Forecast",
       caption = "Forecast version v13(beta)") +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  theme(
    text = element_text(color = "white"),
    panel.background = element_rect(fill = "gray20"),
    plot.background = element_rect(fill = "gray20"),
    panel.border = element_rect(fill=NA,color="white", size=0.5, linetype="solid"),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.line = element_blank(),
    axis.ticks = element_blank(),
    axis.title = element_text(color = "white"),
    axis.text = element_text(color="white"),
    axis.text.y  = element_text(hjust=1),
    legend.text = element_text(color="white"),
    legend.background = element_rect(fill="gray20"),
    legend.position = "bottom",
    legend.title = element_text(color = "white")
    )


mean(fcasts$p_up > 0.5 | fcasts$p_down > 0.5)
mean(fcasts$p_up > 0.5 & fcasts$p_down > 0.5)


# How is DV coded? --------------------------------------------------------


plot_coding <- function(x, cp = 0.39) {
  # extend the head and tail of x
  xlong <- c(rep(x[1], 2), x, tail(x, 1))
  status <- changes_one_country(xlong, cp)
  status <- head(status, -1) |> tail(-2)
  col = rep("gray", length(x))
  col[status=="up"] <- "blue"
  col[status=="down"] <- "red"
  plot(1L:length(x), x, col = col, ylim = c(0, 1))
}

plot_coding(c(0.5, 0.5, 0.1, 0.1, 0.1))

plot_coding(c(0.5, 0.4, 0.1, 0.1, 0.1))

plot_coding(c(0.5, 0.5, 0.1, 0.05, 0.05))

plot_coding(c(0.5, 0.4, 0.1, 0.05, 0.05))

plot_coding(c(0.5, 0.4, 0.1, 0.0, 0.0))



# Relationship between d1 and d2 ------------------------------------------
#
#   I.e. what kinds of changes are common after a large spike or drop?
#

data(spaces)

merge_data <- read_merge_data()
merge_data <- merge_data[, c("gwcode", "year", spaces$Indicator)]
merge_data <- merge_data |> group_by(gwcode)
for (var in spaces$Indicator) {
  # year to year change
  d1_name <- sprintf("%s_d1", var)
  merge_data$.xx <- merge_data[[var]]
  merge_data <- merge_data |>
    mutate(.d1 = c(NA, diff(.xx)))
  merge_data[[d1_name]] <- merge_data$.d1

  # lagged y2y
  d1_l1_name <- sprintf("%s_d1_l1", var)
  merge_data <- merge_data |>
    mutate(.d1l1 = c(NA, head(lag(.d1), -1)))
  merge_data[[d1_l1_name]] <- merge_data$.d1l1
}
merge_data$.d1 <- merge_data$.d1l1 <- merge_data$.xx <- NULL

cor(merge_data$v2x_veracc_osp_d1_l1, merge_data$v2x_veracc_osp_d1, use = "complete.obs")

#
#   How can both opening and closing risk be high?
#   One possibility is single year drops and spikes, check some out.
#

# Big spikes
merge_data |>
  dplyr::filter(v2x_veracc_osp_d1_l1 > 0.4, v2x_veracc_osp_d1 > -0.4) |>
  arrange(desc(year))

# Lesotho 1999
merge_data |>
  dplyr::filter(gwcode==570) |>
  ggplot(aes(x = year, y = v2x_veracc_osp)) +
  geom_line()

# Big drops
merge_data |>
  dplyr::filter(v2x_veracc_osp_d1_l1 < -0.4, v2x_veracc_osp_d1 > 0.4) |>
  arrange(desc(year))

# Guinea-Bissau 2014
merge_data |>
  dplyr::filter(gwcode==404) |>
  ggplot(aes(x = year, y = v2x_veracc_osp)) +
  geom_line()

