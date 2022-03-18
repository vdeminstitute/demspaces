#
#   Quick and dirty script to examine tuning experiment results
#
#   Note that this is using the Dropbox data store folder.
#

library(dplyr)
library(ggplot2)
library(tidyr)

tr <- readRDS("~/Dropbox/Work/vdem/demspaces/tuning/all-results.rds")

tr$cost <- sapply(tr$cost, mean)

# Time model

tr$time <- tr$time / tr$rep_n

plot(tr$num.trees, tr$time)
plot(log(tr$num.trees), log(tr$time))
plot(tr$mtry, tr$time)
plot(log(tr$mtry), log(tr$time))
plot(tr$min.node.size, tr$time)
plot(log(tr$min.node.size), log(tr$time))
plot(factor(tr$nodename), log(tr$time))


mdl <- lm(log(time) ~ log(num.trees)*log(mtry)*nodename, data = tr)
summary(mdl)

plot(predict(mdl), log(tr$time))
plot(exp(predict(mdl)), tr$time)
abline(a = 0, b = 1, col = "red")

# the actual models run two ranger models for each outcome, so need to multiply
# this by 2 to get production model time
2*exp(predict(mdl, data.frame(num.trees = 2000, mtry = 20, min.node.size = 1, nodename = "mbp-2019.local")))


# HP analysis

ggplot(tr, aes(x = num.trees, y = cost)) +
  geom_point() +
  facet_grid(direction ~ outcome) +
  theme_light()

ggplot(tr, aes(x = min.node.size, y = cost)) +
  geom_point() +
  facet_grid(direction ~ outcome) +
  theme_light()

ggplot(tr, aes(x = mtry, y = cost)) +
  geom_point(alpha = 0.2) +
  facet_grid(direction ~ outcome) +
  theme_light()




tr <- tr %>%
  group_by(num.trees, mtry, min.node.size) %>%
  summarize(cost = mean(cost), .groups = "drop")

plot(tr$num.trees, tr$cost, xlab = "num.trees")
plot(tr$mtry,      tr$cost, xlab = "mtry")
plot(tr$min.node.size, tr$cost, xlab = "min.node.size")


with(tr[tr$min.node.size==1, ], plot(num.trees, cost))

col <- tr[tr$min.node.size==1, ][["num.trees"]]
lbl <- unique(tr[tr$min.node.size==1, ][["num.trees"]])
col <- as.integer(as.factor(col))
with(tr[tr$min.node.size==1, ], plot(mtry, cost, col = col))
legend(x = 60, y = 0.044, col = unique(col), legend = lbl,
       lwd = 1)
