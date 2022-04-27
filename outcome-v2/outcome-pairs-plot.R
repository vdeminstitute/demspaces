#
#   How correlated are the six spaces indicators?
#
#   This was follow up to a question during the 4/20 call with Rick.
#

library(GGally)

outcomes <- readRDS(here::here("create-data/output/dv-data.rds"))

dvs <- readRDS(here::here("create-data/output/dv_data_1958_on.rds"))

df <- dvs[dvs$year > 1990, spaces$Indicator]
colnames(df) <- spaces$Space

ggpairs(df,
        lower = list(continuous = wrap("points", alpha = 0.2, size=0.05))
        ) +
  theme_light()

ggsave(here::here("outcome-v2/outcome-pairs-plot.png"), height = 10, width = 12)

summary(prcomp(df, center = TRUE, scale = TRUE, retx = TRUE))

#

df <- outcomes[outcomes$year > 1990, c("dv_v2xcs_ccsi_change", "dv_v2x_freexp_altinf_change")]
df[[1]] <- factor(df[[1]], levels = c("first year of independence", "down", "same", "up"))
df[[2]] <- factor(df[[2]], levels = c("first year of independence", "down", "same", "up"))

table(Associational = df$dv_v2xcs_ccsi_change, Informational = df$dv_v2x_freexp_altinf_change)
