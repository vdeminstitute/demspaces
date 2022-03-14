

tr <- readRDS("~/Work/2021-vdem-updates/demspaces/modelrunner/output/tuning/all-results.rds")

tr$cost <- sapply(tr$cost, mean)

# Time model

plot(tr$num.trees, tr$time)
plot(tr$mtry, tr$time)
plot(tr$min.node.size, tr$time)

mdl <- lm(time ~ num.trees*mtry*rep_n, data = tr)
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
