

library(dplyr)
library(ggplot2)
library(tidyr)

tr <- readRDS("~/Work/2021-vdem-updates/demspaces/modelrunner/output/tuning/all-results.rds")

tr$cost <- sapply(tr$cost, mean)

# Time model

plot(tr$num.trees, tr$time)
plot(tr$mtry, tr$time)
plot(tr$min.node.size, tr$time)
plot(factor(tr$nodename), tr$time)

mdl <- lm(time ~ num.trees*mtry*rep_n*nodename, data = tr)
summary(mdl)
predict(mdl, data.frame(num.trees = 1000, mtry = 20, min.node.size = 1, rep_n = 5))



# HP analysis

tr <- tr %>%
  group_by(num.trees, mtry, min.node.size) %>%
  summarize(cost = mean(cost), .groups = "drop")

plot(tr$num.trees, tr$cost, xlab = "num.trees")
plot(tr$mtry,      tr$cost, xlab = "mtry")
plot(tr$min.node.size, tr$cost, xlab = "min.node.size")

tr |>
  tidyr::pivot_longer(c(num.trees, mtry, min.node.size)) |>
  ggplot(aes(x = value, y = cost, group = name)) +
  geom_point() +
  facet_grid(outcome + direction ~ name, scales = "free")


with(tr[tr$min.node.size==1, ], plot(num.trees, cost))

col <- tr[tr$min.node.size==1, ][["num.trees"]]
lbl <- unique(tr[tr$min.node.size==1, ][["num.trees"]])
col <- as.integer(as.factor(col))
with(tr[tr$min.node.size==1, ], plot(mtry, cost, col = col))
legend(x = 60, y = 0.044, col = unique(col), legend = lbl,
       lwd = 1)
