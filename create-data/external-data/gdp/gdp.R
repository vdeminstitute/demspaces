
# don't attach packages unless in development
# assumes for development, wd is set to module path
if (basename(getwd())=="gdp") {
  library("dplyr")
  library("WDI")
  library("states")
  library("lubridate")
  library("countrycode")
  library("lme4")
  library("lubridate")
  library("imputeTS")
}

# Setup path to module directory, so we can access data stored locally
determine_path <- function() {
  path <- getSrcDirectory(function(x) {x})
  # sources from RMD
  if (!length(path) > 0) path <- ""
  if (path == "") path <- "."
  path
}
GDP_PATH <- determine_path()
rm(determine_path)

# API function; everything else should not be called directly by user
gdp_api <- function(what = NULL) {
  gdp_get_yearly()
}



# Setup -------------------------------------------------------------------


if (!dir.exists(file.path(GDP_PATH, "input/expgdpv6.0"))) {
  tmp <- tempfile()
  download.file("http://ksgleditsch.com/data/expgdpv6.0.zip", destfile = tmp)
  unzip(tmp, exdir = file.path(GDP_PATH, "input/expgdpv6.0"))
}


# Functions ---------------------------------------------------------------


# API function; everything else should not be called directly by user
gdp_api <- function(what = "yearly", impute = TRUE) {
  gdp_get_yearly(impute = impute)
}


gdp_wdi_add_gwcode <- function(x) {
  starty <- min(x$year)
  endy <- max(x$year)
  cy1 <- states::state_panel(as.Date(sprintf("%s-01-01", starty)), 
                             as.Date(sprintf("%s-12-31", endy)),
                             by = "year", useGW = TRUE)
  cy2 <- states::state_panel(as.Date(sprintf("%s-12-31", starty)), 
                             as.Date(sprintf("%s-12-31", endy)),
                             by = "year", useGW = TRUE)                           
  cy1$year <- lubridate::year(cy1$date)
  cy1$date <- NULL
  cy2$year <- lubridate::year(cy2$date)
  cy2$date <- NULL
  cy <- full_join(cy1, cy1, by = c("gwcode", "year"))
  
  x <- x %>%
    mutate(gwcode = countrycode::countrycode(x$iso2c, "iso2c", "cown", warn = FALSE)) %>%
    mutate(gwcode = case_when(
      iso2c=="RS" ~ 340L,
      iso2c=="XK" ~ 347L,
      
      gwcode==255 ~ 260L,
      gwcode==679 ~ 678L,
      
      gwcode==970 ~ 971L,
      gwcode==946 ~ 970L,
      gwcode==947 ~ 973L,
      gwcode==955 ~ 972L,
      TRUE ~ gwcode
    ))
  
  # drop countries that unify
  x <- x %>%
    filter(!(gwcode==260 & year < 1990)) %>%
    filter(!(gwcode==678 & year < 1990))
  
  x <- dplyr::select(x, -iso2c, -country)
  x <- x %>% filter(!is.na(gwcode))
  
  cy <- dplyr::left_join(cy, x, by = c("gwcode", "year"))
  cy
}

gdp_un_add_gwcode <- function(x) {
  starty <- min(x$year)
  endy <- max(x$year)
  cy1 <- states::state_panel(as.Date(sprintf("%s-01-01", starty)), 
                             as.Date(sprintf("%s-12-31", endy)),
                             by = "year", useGW = TRUE)
  cy2 <- states::state_panel(as.Date(sprintf("%s-12-31", starty)), 
                             as.Date(sprintf("%s-12-31", endy)),
                             by = "year", useGW = TRUE)                           
  cy1$year <- lubridate::year(cy1$date)
  cy1$date <- NULL
  cy2$year <- lubridate::year(cy2$date)
  cy2$date <- NULL
  cy <- full_join(cy1, cy1, by = c("gwcode", "year"))
  
  x <- x %>%
    mutate(cowcode = countrycode(country_name, "country.name", "cown", warn = FALSE))
  
  x <- x %>%
    mutate(gwcode = case_when(
      country_name=="Democratic Republic of Vietnam" ~ 816L,
      # UN seems to have correct series for Yugo/Serbia
      country_name=="Serbia" & year > 2006 ~ 340L,
      country_name=="Serbia" & year <= 2006 ~ 345L,
      # need to add 2006 for Serbia
      cowcode==255 ~ 260L,
      cowcode==679 ~ 678L,
      cowcode==955 ~ 972L,
      # Czechoslovakia/CR also treated correctly, and they had a nice split date
      cowcode==316 & year < 1993 ~ 315L,
      TRUE ~ cowcode
    ))
  serbia2006 <- x[x$country_name=="Serbia" & x$year==2006, ]
  serbia2006$gwcode <- 340L
  
  x <- bind_rows(x, serbia2006) %>%
    arrange(gwcode, year)
  
  # drop countries that unify, historic GDP values are incorrect
  x <- x %>%
    filter(!(gwcode==260 & year < 1990)) %>%
    filter(!(gwcode==678 & year < 1990)) %>%
    filter(!(gwcode==816 & year < 1975)) 
  
  in_un_not_in_master <- anti_join(x, cy, by = c("year", "gwcode")) %>%
    group_by(country_name) %>% 
    summarize(gwcode = unique(gwcode)[1], year = paste0(range(year), collapse = " - "))
  
  in_master_not_in_un <- anti_join(cy, x, by = c("gwcode", "year")) %>%
    group_by(gwcode) %>%
    summarize(year = paste0(range(year), collapse = " - "))
  
  x <- dplyr::select(x, -country_name, -country_id, -cowcode)
  x <- x %>% filter(!is.na(gwcode))
  
  cy <- dplyr::left_join(cy, x, by = c("gwcode", "year"))
  cy
}

gdp_load_inputs <- function() {
  wdigdp <- WDI::WDI(country = "all", start = 1960, end = lubridate::year(today()),
                     indicator = c("NY.GDP.MKTP.KD"))
  
  # don't want column specification messages
  suppressMessages({
    ksggdp <- read_delim(file.path(GDP_PATH, "input/expgdpv6.0/gdpv6.txt"), delim = "\t") %>%
      rename(gwcode = statenum) %>%
      select(-stateid)
    
    ungdp <- read_csv(file.path(GDP_PATH, "input/UNgdpData.csv")) %>%
      select(country_name, country_id, year, gdp_2010USD) 
  })
  
  pop <- read_csv(file.path(GDP_PATH, "input/population.csv"))

  list(wdigdp = wdigdp, ksggdp = ksggdp, ungdp = ungdp, pop = pop)
}


gdp_get_yearly <- function(impute) {
  inputs <- gdp_load_inputs()
  
  wdigdp <- inputs$wdigdp
  ksggdp <- inputs$ksggdp
  ungdp  <- inputs$ungdp
  pop <- inputs$pop
  
  wdigdp <- wdigdp %>%
    group_by(year) %>% 
    mutate(whole_year_missing = sum(is.na(NY.GDP.MKTP.KD))==n()) %>%
    ungroup() %>%
    filter(!whole_year_missing) %>%
    select(-whole_year_missing)
  wdi <- gdp_wdi_add_gwcode(wdigdp)
  
  ungdp <- gdp_un_add_gwcode(ungdp)  
  
  joint <- wdi %>%
    full_join(., ksggdp, by = c("gwcode", "year")) %>%
    select(-pop, -rgdppc, -cgdppc) %>%
    mutate(realgdp = realgdp*1e6) %>%
    full_join(., ungdp, by = c("gwcode", "year")) %>%
    arrange(gwcode, year)
  
  mdl_un <- lm(NY.GDP.MKTP.KD ~ -1 + gdp_2010USD, data = joint)
  joint <- joint %>%
    mutate(un_gdp.rescaled = predict(mdl_un, newdata = joint))
  
  mdl_ksg <- lmer(log(NY.GDP.MKTP.KD) ~ -1 + log(realgdp) + (log(realgdp)|gwcode), data = joint)
  joint <- joint %>%
    mutate(ksg_gdp.rescaled = exp(predict(mdl_ksg, newdata = joint, allow.new.levels = TRUE)))
  
  joint <- joint %>%
    mutate(NY.GDP.MKTP.KD = case_when(
      # special treatment for Qatar 1971, where otherwise a big jump occurs
      gwcode==694 & year==1971 ~ filter(joint, gwcode==694) %>% pull(un_gdp.rescaled) %>% rev() %>% imputeTS::na.kalman() %>% tail(1),
      is.na(NY.GDP.MKTP.KD) & !is.na(un_gdp.rescaled) ~ un_gdp.rescaled,
      is.na(NY.GDP.MKTP.KD) & !is.na(ksg_gdp.rescaled) ~ ksg_gdp.rescaled,
      TRUE ~ NY.GDP.MKTP.KD
    ))
  
  joint <- joint %>%
    # take out components; don't need anymore
    select(gwcode, year, NY.GDP.MKTP.KD) %>%
    # add GDP growth
    arrange(gwcode, year) %>%
    group_by(gwcode) %>%
    mutate(NY.GDP.MKTP.KD.ZG = (NY.GDP.MKTP.KD - lag(NY.GDP.MKTP.KD)) / lag(NY.GDP.MKTP.KD) * 100) %>%
    ungroup()
  
  if (impute) {
    # forward and backward impute GDP
    joint <- joint %>%
      group_by(gwcode) %>%
      mutate(NY.GDP.MKTP.KD = imputeTS::na.kalman(NY.GDP.MKTP.KD)) %>%
      ungroup()
    joint <- joint %>%
      group_by(gwcode) %>%
      arrange(desc(year)) %>%
      mutate(NY.GDP.MKTP.KD = imputeTS::na.kalman(NY.GDP.MKTP.KD)) %>%
      ungroup()
    
    # update GDP change calculation; use backward impute for first year
    joint <- joint %>%
      group_by(gwcode) %>%
      arrange(year) %>%
      mutate(NY.GDP.MKTP.KD.ZG = (NY.GDP.MKTP.KD - lag(NY.GDP.MKTP.KD)) / lag(NY.GDP.MKTP.KD) * 100) %>%
      arrange(desc(year)) %>%
      mutate(NY.GDP.MKTP.KD.ZG = tryCatch({
        suppressWarnings(imputeTS::na.kalman(NY.GDP.MKTP.KD.ZG, model = "auto.arima"))
      }, error = function(e) NY.GDP.MKTP.KD.ZG)) %>%
      arrange(year) %>%
      ungroup()
  }
  
  # Add GDP per capita
  joint <- joint %>%
    left_join(pop, by = c("gwcode", "year")) %>%
    group_by(gwcode) %>%
    arrange(year) %>%
    mutate(NY.GDP.PCAP.KD = NY.GDP.MKTP.KD / (pop*1e3),
           NY.GDP.PCAP.KD.ZG = (NY.GDP.PCAP.KD - lag(NY.GDP.PCAP.KD)) / lag(NY.GDP.PCAP.KD) * 100) %>%
    select(-pop) %>%
    # backwards impute first year of GDP per capita change
    group_by(gwcode) %>%
    arrange(desc(year)) %>%
    mutate(NY.GDP.PCAP.KD.ZG = tryCatch({
      suppressWarnings(imputeTS::na.kalman(NY.GDP.PCAP.KD.ZG, model = "auto.arima"))
    }, error = function(e) NY.GDP.PCAP.KD.ZG)) %>%
    arrange(year) %>%
    ungroup()
  
  joint$year <- as.integer(joint$year)
  
  joint
}


