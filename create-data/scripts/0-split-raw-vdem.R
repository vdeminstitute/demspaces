#
#   Split raw V-Dem data into CY set, DV, IV pieces
#
#   Andreas Beger & Rick Morgan
#   2026-01-21
#
#   Adapted from `VDem_data_build.r`, which Rick Morgan originally wrote.
#
#   Output:
#
#     - output/dv_data_1968_on.csv
#     - output/vdem_data_1968_on.csv
#     - output/country_year_set_1968_on.csv
#     - dashboard/Data/dv_data_1968-2022.csv
#
#   NOTE FOR UPDATES:
#     For every vdem version update, we need to comment out any
#     "country_name == """ mutate function in the "vdem_clean_data"
#     construction.
#     It is likely that VDem fixed the NAs these mutate functions are
#     addressing...
#     Also, it is likely that the are other different NAs from version to
#     version...


library(tidyverse)
library(states)
library(tidyr)
library(here)
library(zoo)
devtools::load_all(here::here("demspaces.dev"))

oldwd <- getwd()
setwd(here::here("create-data"))

naCountFun <- function(dat, exclude_year){
  dat %>%
    dplyr::filter(year < exclude_year) %>%
    sapply(function(x) sum(is.na(x))) %>%
    sort()
}

# The end year of observed data. Usually should be the year prior to the
# current year.
# UPDATE:
END_YEAR   <- get_option("data_end_year")
START_YEAR <- get_option("data_start_year")

# UPDATE: v[X]
vdem_fn <- sprintf("input/V-Dem-CY-Full+Others-%s.rds", get_option("version"))
vdem_raw <- readRDS(vdem_fn)

## Remove countries that have a lot of missingness in the VDem data... and make adjustments to merge with GW country-year set
vdem_complete <- vdem_raw %>%
  mutate(country_name = ifelse(country_id == 196, "Sao Tome and Principe", country_name)) %>%
  dplyr::filter(year >= START_YEAR - 20 &
                  country_name != "Palestine/West Bank" & country_name != "Hong Kong" & country_name != "Bahrain" & country_name != "Malta" &
                  country_name != "Zanzibar" & country_name != "Somaliland" & country_name != "Palestine/Gaza") %>%
  dplyr::filter(!(country_name == "Timor-Leste" & year < 2002)) %>%
  mutate(gwcode = COWcode,
         gwcode = case_when(gwcode == 255 ~ 260,
                            gwcode == 679 ~ 678,
                            gwcode == 345 & year >= 2006 ~ 340,
                            TRUE ~ gwcode)) %>%
  select(gwcode, everything())

dim(vdem_complete)
# 2020 update (v10): 8430, 4109
# 2021 update (v11): 8602, 4177
# 2022 update (v12): 8774, 4171
# 2023 update (v13): 11929, 4603
# 2024 update (v14): 12101, 4608 *done in 2026 for MPSA

vdem_country_year0 <- vdem_complete %>%
  select(c(country_name, country_text_id, country_id, gwcode, year, v2x_pubcorr))
# no_gwcode <- vdem_country_year0[is.na(vdem_country_year0$gwcode), c("country_name", "country_id", "year")]
naCountFun(vdem_country_year0, 2024)

vdem_country_year <- vdem_country_year0 %>%
  dplyr::filter(year >= START_YEAR) %>%
  dplyr::filter(!is.na(gwcode)) %>%
  group_by(gwcode) %>%
  complete(country_name, country_id, country_text_id, year = min(year):END_YEAR) %>%
  # fill(country_name) %>%
  ungroup()

dim(vdem_country_year)
# v??: 8753, 6
# v12: 8927, 6
# v13: 9104, 6
# v14: 9281, 6

## GW_template is a balanced gwcode yearly data frame from START_YEAR to END_YEAR Need to drop microstates.
data(gwstates)

keep <- gwstates$gwcode[gwstates$microstate == FALSE]

GW_template <- state_panel(START_YEAR, END_YEAR, partial = "any", useGW = TRUE) %>%
  dplyr::filter(gwcode %in% keep)
dim(GW_template)
# 8344 2
# v12: 8692, 2
# v13: 8866, 2
# v14: 9040, 2

country_year_set <- left_join(GW_template, vdem_country_year) %>%
  dplyr::filter(!is.na(country_id)) %>%
  mutate(keep = ifelse(is.na(v2x_pubcorr) & year != END_YEAR, 0, 1)) %>%
  dplyr::filter(keep == 1) %>%
  select(-c(keep, v2x_pubcorr))

naCountFun(country_year_set, END_YEAR)
dim(country_year_set)
# 8120    5
# v13: 8627, 5
# v14: 8796, 5

write_csv(country_year_set, "output/country_year_set_1968_on.csv")


# Country to region mapping -----------------------------------------------
#
#   The dashboard needs a mapping from country codes to regions; write that
#   out now
#

# Check that gwcode uniquely maps to regions
xx <- vdem_complete %>%
  dplyr::filter(year >= START_YEAR) %>%
  select(gwcode, e_regionpol_6C) %>%
  count(gwcode, e_regionpol_6C)
stopifnot(
  "Regions don't map uniquely to gwcode, need to add year" =
    nrow(xx)==length(unique(xx$gwcode))
)

region_mapping <- xx[, c("gwcode", "e_regionpol_6C")]
write_csv(region_mapping, "output/region-mapping.csv")


# DVs ---------------------------------------------------------------------
#
#   Get the 6 indicators for our DV outcomes
#

vdem_dvs <- vdem_complete %>%
  dplyr::filter(year >= START_YEAR) %>%
  select(c(country_name, country_text_id, country_id, gwcode, year,
           v2x_veracc_osp, v2xcs_ccsi, v2xcl_rol, v2x_freexp_altinf,
           v2x_horacc_osp, v2x_pubcorr)) %>%
  mutate(v2x_pubcorr = 1 - v2x_pubcorr)

naCountFun(vdem_dvs, 2023)

dvs <- left_join(country_year_set, vdem_dvs)
naCountFun(dvs, END_YEAR)  # no NAs

write_csv(dvs, "output/dv_data_1968_on.csv")



# V-Dem predictor data ----------------------------------------------------
#
#   Predictor (IV) data from V-Dem
# This needs to be changed

vdem_ivs <- vdem_complete %>%
  dplyr::filter(year >= START_YEAR) %>%
    select(country_name, country_text_id, gwcode, country_id, year, v2x_polyarchy, v2x_liberal, v2xdl_delib, v2x_jucon,
           v2x_frassoc_thick, v2xel_frefair, v2x_elecoff, v2xlg_legcon, v2x_partip, v2x_cspart, v2x_egal, v2xeg_eqprotec,
           v2xeg_eqaccess, v2xeg_eqdr, v2x_diagacc, v2xex_elecleg, v2x_civlib, v2x_clphy, v2x_clpol, v2x_clpriv, v2x_corr,
           v2x_EDcomp_thick, v2x_elecreg, v2x_freexp, v2x_gencl, v2x_gencs, v2x_hosabort, v2x_hosinter, v2x_rule, v2xcl_acjst,
           v2xcl_disc, v2xcl_dmove, v2xcl_prpty, v2xcl_slave, v2xel_elecparl, v2xel_elecpres, v2xex_elecreg, v2xlg_elecreg,
           v2ex_legconhog, v2ex_legconhos, v2x_ex_confidence, v2x_ex_direlect, v2x_ex_hereditary, v2x_ex_military, v2x_ex_party,
           v2x_execorr, v2x_legabort, v2xlg_leginter, v2x_neopat, v2xnp_client, v2xnp_pres, v2xnp_regcorr, v2elvotbuy, v2elfrcamp,
           v2elpdcamp, v2elpaidig, v2elmonref, v2elmonden, v2elrgstry, v2elirreg, v2elintim, v2elpeace, v2elfrfair, v2elmulpar,
           v2elboycot, v2elaccept, v2elasmoff, v2eldonate, v2elpubfin, v2ellocumul, v2elprescons, v2elprescumul, v2elembaut,
           v2elembcap, v2elreggov, v2ellocgov, v2ellocons, v2elrsthos, v2elrstrct, v2psparban, v2psbars, v2psoppaut, v2psorgs,
           v2psprbrch, v2psprlnks, v2psplats, v2pscnslnl, v2pscohesv, v2pscomprg, v2psnatpar, v2pssunpar, v2exremhsp, v2exdfdshs,
           v2exdfcbhs, v2exdfvths, v2exdfdmhs, v2exdfpphs, v2exhoshog, v2exrescon, v2exbribe, v2exembez, v2excrptps, v2exthftps,
           v2ex_elechos, v2ex_hogw, v2expathhs, v2lgbicam, v2lgqstexp, v2lginvstp, v2lgotovst, v2lgcrrpt, v2lgoppart, v2lgfunds,
           v2lgdsadlobin, v2lglegplo, v2lgcomslo, v2lgsrvlo, v2ex_hosw, v2dlreason, v2dlcommon, v2dlcountr, v2dlconslt,
           v2dlengage, v2dlencmps, v2dlunivl, v2jureform, v2jupurge, v2jupoatck, v2jupack, v2juaccnt, v2jucorrdc, v2juhcind,
           v2juncind, v2juhccomp, v2jucomp, v2jureview, v2clacfree, v2clrelig, v2cltort, v2clkill, v2cltrnslw, v2clrspct, v2clfmove,
           v2cldmovem, v2cldmovew, v2cldiscm, v2cldiscw, v2clslavem, v2clslavef, v2clstown, v2clprptym, v2clprptyw, v2clacjstm,
           v2clacjstw, v2clacjust, v2clsocgrp, v2clrgunev, v2svdomaut, v2svinlaut, v2svstterr, v2cseeorgs, v2csreprss, v2cscnsult,
           v2csprtcpt, v2csgender, v2csantimv, v2csrlgrep, v2csrlgcon, v2mecenefm, v2mecrit, v2merange, v2meharjrn, v2meslfcen, v2mebias,
           v2mecorrpt, v2pepwrses, v2pepwrsoc, v2pepwrgen, v2pepwrort, v2peedueq, v2pehealth)
dim(vdem_ivs) ## 8430  186
# v14: 9118, 186

vdem_clean_data <- vdem_ivs %>%
  group_by(country_id) %>%
  arrange(year) %>%
  mutate(# is_jud = ifelse(is.na(v2x_jucon), 0, 1), this is unnecessary as of v14 update
         is_leg = ifelse(v2lgbicam > 0, 1, 0),
         is_elec = ifelse(v2x_elecreg == 0, 0, 1),
         is_election_year = ifelse(!is.na(v2elirreg), 1, 0)) %>%
         fill(v2elrgstry) %>%
           fill(v2elvotbuy) %>%
           fill(v2elirreg) %>%
           fill(v2elintim) %>%
           fill(v2elpeace) %>%
           fill(v2elfrfair) %>%
           fill(v2elmulpar) %>%
           fill(v2elboycot) %>%
           fill(v2elaccept) %>%
           fill(v2elasmoff) %>%
           fill(v2elfrcamp) %>%
           fill(v2elpdcamp) %>%
           fill(v2elpaidig) %>%
           fill(v2elmonref) %>%
           fill(v2elmonden) %>%
           mutate(v2elrgstry = ifelse(is.na(v2elrgstry) & v2x_elecreg == 0, 0, v2elrgstry),
                  v2elvotbuy = ifelse(is.na(v2elvotbuy) & v2x_elecreg == 0, 0, v2elvotbuy),
                  v2elirreg = ifelse(is.na(v2elirreg) & v2x_elecreg == 0, 0, v2elirreg),
                  v2elintim = ifelse(is.na(v2elintim) & v2x_elecreg == 0, 0, v2elintim),
                  v2elpeace = ifelse(is.na(v2elpeace) & v2x_elecreg == 0, 0, v2elpeace),
                  v2elfrfair = ifelse(is.na(v2elfrfair) & v2x_elecreg == 0, 0, v2elfrfair),
                  v2elmulpar = ifelse(is.na(v2elmulpar) & v2x_elecreg == 0, 0, v2elmulpar),
                  v2elboycot = ifelse(is.na(v2elboycot) & v2x_elecreg == 0, 0, v2elboycot),
                  v2elaccept = ifelse(is.na(v2elaccept) & v2x_elecreg == 0, 0, v2elaccept),
                  v2elasmoff = ifelse(is.na(v2elasmoff) & v2x_elecreg == 0, 0, v2elasmoff),
                  v2elpaidig = ifelse(is.na(v2elpaidig) & v2x_elecreg == 0, 0, v2elpaidig),
                  v2elfrcamp = ifelse(is.na(v2elfrcamp) & v2x_elecreg == 0, 0, v2elfrcamp),
                  v2elpdcamp = ifelse(is.na(v2elpdcamp) & v2x_elecreg == 0, 0, v2elpdcamp),
                  v2elpdcamp = ifelse(is.na(v2elpdcamp) & v2x_elecreg == 0, 0, v2elpdcamp),
                  v2elmonref = ifelse(is.na(v2elmonref) & v2x_elecreg == 0, 0, v2elmonref),
                  v2elmonden = ifelse(is.na(v2elmonden) & v2x_elecreg == 0, 0, v2elmonden)) %>%#,
           ungroup() %>%
           mutate(#v2x_jucon = ifelse(is_jud == 0, 0, v2x_jucon), v14 note above
                  v2xlg_legcon = ifelse(is_leg == 0, 0, v2xlg_legcon),
                  v2elmonref = ifelse(is.na(v2elmonref) & is_elec == 1, 0, v2elmonref),
                  v2elmonden = ifelse(is.na(v2elmonden) & is_elec == 1, 0, v2elmonden),
# update: check if these are necessary with each update.
                  v2svstterr = ifelse(is.na(v2svstterr) & country_name == "South Yemen" & year == 1990, 97.4, v2svstterr), ## Not sure why this is NA. last year in the series, carry forward
                  v2svstterr = ifelse(is.na(v2svstterr) & country_name == "Republic of Vietnam" & year == 1975, 48, v2svstterr), ## Not sure why this is NA. last year in the series, carry forward
                  v2svstterr = ifelse(is.na(v2svstterr) & country_name == "German Democratic Republic" & year == 1990, 99, v2svstterr), ## Not sure why this is NA. last year in the series, carry forward
                  v2psoppaut = ifelse(is.na(v2psoppaut) & country_name == "Qatar" & between(year, 1971, 2023), -3.527593, v2psoppaut), ## Opposition parties are banned in Qatar. Going with the min score in the data (1970-2017)
                  v2psoppaut = ifelse(is.na(v2psoppaut) & country_name == "United Arab Emirates" & between(year, 2020, 2023), -2.468, v2psoppaut), ## Opposition parties are banned in UAE. Going with the min score in the data (1970-2017)
                  v2psoppaut = ifelse(is.na(v2psoppaut) & country_name == "Oman" & between(year, 2000, 2023), -2.573, v2psoppaut), ## Carry forward. There are a handful of nominal opposition parties, but they are co-opted. No much changed after 1999...
                  v2psoppaut = ifelse(is.na(v2psoppaut) & country_name == "Eswatini" & between(year, 2021, 2023), -1.821, v2psoppaut), ## Carry forward. It was the same value for since 1973
                  v2psoppaut = ifelse(is.na(v2psoppaut) & country_name == "Vietnam" & between(year, 2021, 2023), -3.418, v2psoppaut), ## Carry forward. It was the same value for since 1990
                  v2lgqstexp = ifelse(is_leg == 0, 0, v2lgqstexp),
                  v2lginvstp = ifelse(is_leg == 0, 0, v2lginvstp),
                  v2lgotovst = ifelse(is_leg == 0, 0, v2lgotovst),
                  v2lgcrrpt = ifelse(is_leg == 0, 0, v2lgcrrpt),
                  v2lgoppart = ifelse(is_leg == 0, 0, v2lgoppart),
                  v2lgfunds = ifelse(is_leg == 0, 0, v2lgfunds),
                  v2lgdsadlobin = ifelse(is_leg == 0, 0, v2lgdsadlobin),
                  v2lglegplo = ifelse(is_leg == 0, 0, v2lglegplo),
                  v2lgcomslo = ifelse(is_leg == 0, 0, v2lgcomslo),
                  v2lgsrvlo =  ifelse(is_leg == 0, 0, v2lgsrvlo)) %>%
  select(country_name, country_text_id, gwcode, country_id, year, is_leg, is_elec, is_election_year, everything())
dim(vdem_clean_data) ## 8430  190
# v14: 9118, 189 (removed `is_jud`)

# START add sdX vars
#
# 2022-03: write a version of this that goes back further, for historical
# DV transforms
keep <- gwstates$gwcode[gwstates$microstate == FALSE]
GW_template_longer <- state_panel(START_YEAR - 20, END_YEAR, partial = "any", useGW = TRUE) %>%
  dplyr::filter(gwcode %in% keep)
country_year_set_longer <- GW_template_longer

vdem_dvs_longer <- vdem_complete %>%
  select(c(country_name, country_text_id, country_id, gwcode, year,
           v2x_veracc_osp, v2xcs_ccsi, v2xcl_rol, v2x_freexp_altinf,
           v2x_horacc_osp, v2x_pubcorr)) %>%
  mutate(v2x_pubcorr = 1 - v2x_pubcorr)

# I'm not sure what this is doing dvs_longer isn't used elsewhere...
dvs_longer <- left_join(country_year_set_longer, vdem_dvs_longer)
naCountFun(dvs_longer, END_YEAR)  # nope there are NAs :(
# table(dvs_longer$gwcode[is.na(dvs_longer$country_name)])

# !!! DOES THIS MATTER???
# NOTE 2026: there were 249 NAs in v14
# gwcode: 31  80 338 345 471 511 692 711 835
# freq:   51  43  60   1   1   2  53   3  40
# Bahamas - 51, Belize - 43, Malta - 60, Yugoslavia - 1,
# Armenia - 1, Zanzibar - 2, Bahrain - 53, Tibet - 3, Brunei - 40)

naCountFun(vdem_dvs_longer, 2023)
saveRDS(vdem_dvs_longer, "output/dv_data_1958_on.rds")

data("spaces")
vdem_dv_hist <- vdem_dvs_longer %>%
  group_by(gwcode) %>%
  mutate(across(all_of(spaces$Indicator), ~rollapplyr(.x, FUN = sd, width = 10, fill = NA, partial = TRUE),
                .names = "{.col}_sd10"))
vdem_dv_hist <- vdem_dv_hist %>%
  dplyr::filter(year >= START_YEAR) %>%
  select(gwcode, year, matches("_sd[0-9]+"))

vdem_clean_data <- left_join(vdem_clean_data, vdem_dv_hist, by = c("gwcode", "year"))

# END adding sdX vars

vdem_data <- vdem_clean_data
dim(vdem_data) ## 8430  371
# v14: 9118, 195
naCountFun(vdem_data, END_YEAR)

vDem_GW_data <- country_year_set %>%
  left_join(vdem_data) %>%
  group_by(gwcode) %>%
  arrange(year) %>%
  fill(2:length(.), .direction = "up") %>% # fills-in the NAs in the lagged vars for states created between 1970 and 2019...
  ungroup() %>%
  arrange(country_id, year)
dim(vDem_GW_data)
# v??: 8120, 371
# v12: 8458, 190
# v13: 8627, 196
# v14: 8796, 195

# naCountFun(vDem_GW_data, END_YEAR + 1)
nas <- naCountFun(vDem_GW_data, END_YEAR)
table(nas)
nas[nas > 0]
#
# # # v2psoppaut has 12 NAs
# # I'm going to fix this above. Requires hard coding...
# check_ids <- vDem_GW_data |>
#   dplyr::filter(year < END_YEAR,
#                 (is.na(v2psoppaut) | is.na(v2svstterr))) |>
#   select(gwcode, country_name, v2psoppaut, v2svstterr) |>
#   distinct() |>
#   pull(gwcode)
# check <- vDem_GW_data |>
#   dplyr::filter(gwcode %in% check_ids) |>
#   select(gwcode, country_name, year, v2psoppaut, v2svstterr)

write_csv(vDem_GW_data, "output/vdem_data_1968_on.csv")

setwd(oldwd)

