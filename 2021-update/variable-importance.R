

code_group <- function(x) {
  yy <- c("v2x_veracc_osp", "v2xcl_rol", "v2x_horacc_osp", "v2x_freexp_altinf",
          "v2xcs_ccsi", "v2x_pubcorr")

  out <- rep(NA_character_, length(x))
  out[str_detect(x, "_pt_")] <- "P&T Coups"
  out[str_detect(x, "_v2")] <- "VD-v2"
  out[str_detect(x, "v2x")] <- "VD-v2x"
  out[str_detect(x, "_is_")] <- "VD-v2"
  out[str_detect(x, "diff_year_prior")] <- "VD-diff"
  out[str_detect(x, "_war")] <- "ACD"
  out[str_detect(x, "_confl")] <- "ACD"
  out[str_detect(x, "_conf")] <- "ACD"
  out[x %in% c("gwcode", "year", "lag0_state_age", "lag0_log_state_age")] <- "SL"
  out[str_detect(x, "_gdp|_pop|_infmort")] <- "WDI"
  out[str_detect(x, "_epr_")] <- "EPR"
  out[x %in% yy] <- "VD-y"
  out
}

foo <- readRDS("artifacts/varimp.rds")
foo$var_imp <- lapply(foo$var_imp, tibble::enframe, name = "variable")
foo <- foo %>% tidyr::unnest(var_imp)

foo$group <- code_group(foo$variable)
foo$variable[is.na(foo$group)]

foo %>% count(group)

ggplot(foo, aes(x = group, y = value)) +
  geom_jitter(width = 0.2, alpha = 0.5) +
  coord_flip() +
  facet_grid(outcome ~ direction)

foo %>%
  group_by(group) %>%
  summarize(mean = mean(value),
            median = median(value),
            n = n(),
            n_over_005 = sum(value >= 0.005)) %>%
  arrange(desc(mean))

foo %>%
  filter(group=="ACD") %>%
  group_by(variable) %>%
  summarize(mean = mean(value)) %>%
  arrange(desc(mean))

foo %>%
  filter(group=="EPR") %>%
  group_by(variable) %>%
  summarize(mean = mean(value)) %>%
  arrange(desc(mean))

foo %>%
  filter(group=="VD-diff") %>%
  group_by(variable) %>%
  summarize(mean = mean(value),
            max = max(value),
            n_over_005 = sum(value >= 0.005)) %>%
  arrange(desc(mean))

foo %>%
  filter(group=="VD-v2") %>%
  group_by(variable) %>%
  summarize(mean = mean(value),
            max = max(value),
            n_over_005 = sum(value >= 0.005)) %>%
  arrange(desc(mean)) %>%
  View()

foo %>%
  filter(group=="VD-v2x") %>%
  group_by(variable) %>%
  summarize(mean = mean(value),
            max = max(value),
            n_over_005 = sum(value >= 0.005)) %>%
  arrange(desc(mean)) %>%
  View()

foo %>%
  filter(group=="SL") %>%
  group_by(variable) %>%
  summarize(mean = mean(value)) %>%
  arrange(desc(mean))

foo %>%
  filter(group=="P&T Coups") %>%
  group_by(variable) %>%
  summarize(mean = mean(value)) %>%
  arrange(desc(mean))

foo %>%
  filter(group=="WDI") %>%
  group_by(variable) %>%
  summarize(mean = mean(value),
            max = max(value),
            n_over_005 = sum(value >= 0.005)) %>%
  arrange(desc(mean))

