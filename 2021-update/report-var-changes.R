
library(dplyr)
library(ggplot2)


# Rule of law -------------------------------------------------------------

vdem10 <- readRDS("create-data/input/V-Dem-CY-Full+Others-v10.rds")
vdem11 <- readRDS("create-data/input/V-Dem-CY-Full+Others-v11.rds")

keep <- c("country_id", "year", "country_name", "v2xcl_rol")
vdem10 <- vdem10[, keep]
vdem10$v2xcl_rol_v10 <- vdem10$v2xcl_rol
vdem10$v2xcl_rol <- NULL

vdem11 <- vdem11[, keep]
vdem11$v2xcl_rol_v11 <- vdem11$v2xcl_rol
vdem11$v2xcl_rol <- NULL

joint <- inner_join(vdem10, vdem11)
joint <- joint[joint$year >= 1970, ]

# What cases are missing?
joint %>%
  filter(!complete.cases(.)) %>%
  group_by(country_name) %>%
  summarize(n = n(), years = paste0(range(year), collapse = "-"))

# Take out missing
joint <- joint[complete.cases(joint), ]

with(joint, plot(v2xcl_rol_v10, v2xcl_rol_v11))
with(joint, hist(v2xcl_rol_v11 - v2xcl_rol_v10))

ggplot(joint, aes(x = v2xcl_rol_v10, y = v2xcl_rol_v11)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0.05) +
  geom_abline(slope = 1, intercept = -0.05)

table(abs(joint$v2xcl_rol_v10 - joint$v2xcl_rol_v11) > 0.05)
mean(abs(joint$v2xcl_rol_v10 - joint$v2xcl_rol_v11) > 0.05)


# Public corruption -------------------------------------------------------

vdem10 <- readRDS("create-data/input/V-Dem-CY-Full+Others-v10.rds")
vdem11 <- readRDS("create-data/input/V-Dem-CY-Full+Others-v11.rds")

keep <- c("country_id", "year", "country_name", "v2x_pubcorr")
vdem10 <- vdem10[, keep]
vdem10$v2x_pubcorr_v10 <- vdem10$v2x_pubcorr
vdem10$v2x_pubcorr <- NULL

vdem11 <- vdem11[, keep]
vdem11$v2x_pubcorr_v11 <- vdem11$v2x_pubcorr
vdem11$v2x_pubcorr <- NULL

joint <- inner_join(vdem10, vdem11)
joint <- joint[joint$year >= 1970, ]

# What cases are missing?
joint %>%
  filter(!complete.cases(.)) %>%
  group_by(country_name) %>%
  summarize(n = n(), years = paste0(range(year), collapse = "-"))

# Take out missing
joint <- joint[complete.cases(joint), ]

with(joint, plot(v2x_pubcorr_v10, v2x_pubcorr_v11))
with(joint, hist(v2x_pubcorr_v11 - v2x_pubcorr_v10))

ggplot(joint, aes(x = v2x_pubcorr_v10, y = v2x_pubcorr_v11)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0.05) +
  geom_abline(slope = 1, intercept = -0.05)

table(abs(joint$v2x_pubcorr_v10 - joint$v2x_pubcorr_v11) > 0.05)
mean(abs(joint$v2x_pubcorr_v10 - joint$v2x_pubcorr_v11) > 0.05)



# Vertical accountability -------------------------------------------------

vdem10 <- readRDS("create-data/input/V-Dem-CY-Full+Others-v10.rds")
vdem11 <- readRDS("create-data/input/V-Dem-CY-Full+Others-v11.rds")

keep <- c("country_id", "year", "country_name", "v2x_veracc_osp")
vdem10 <- vdem10[, keep]
vdem10$v2x_veracc_osp_v10 <- vdem10$v2x_veracc_osp
vdem10$v2x_veracc_osp <- NULL

vdem11 <- vdem11[, keep]
vdem11$v2x_veracc_osp_v11 <- vdem11$v2x_veracc_osp
vdem11$v2x_veracc_osp <- NULL

joint <- inner_join(vdem10, vdem11)
joint <- joint[joint$year >= 1970, ]

# What cases are missing?
joint %>%
  filter(!complete.cases(.)) %>%
  group_by(country_name) %>%
  summarize(n = n(), years = paste0(range(year), collapse = "-"))

# Take out missing
joint <- joint[complete.cases(joint), ]

with(joint, plot(v2x_veracc_osp_v10, v2x_veracc_osp_v11))
with(joint, hist(v2x_veracc_osp_v11 - v2x_veracc_osp_v10))

ggplot(joint, aes(x = v2x_veracc_osp_v10, y = v2x_veracc_osp_v11)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0.05) +
  geom_abline(slope = 1, intercept = -0.05)

table(abs(joint$v2x_veracc_osp_v10 - joint$v2x_veracc_osp_v11) > 0.05)
mean(abs(joint$v2x_veracc_osp_v10 - joint$v2x_veracc_osp_v11) > 0.05)

