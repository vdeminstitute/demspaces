

library(readr)
library(ggplot2)


# Horserace ---------------------------------------------------------------



horserace <- bind_rows(
  read_csv("results/run-01_results.csv"),
  read_csv("results/run-11_results.csv")
)

horserace <- horserace %>%
  select(indicator, direction, model, cv_pos_rate:time)

horserace %>%
  pivot_longer(-c(indicator, direction, model), names_to = "metric", values_to = "metric_value") %>%
  group_by(model, metric) %>%
  summarize(metric_value = mean(metric_value)) %>%
  pivot_wider(names_from = "metric", values_from = "metric_value") %>%
  View()

horserace %>%
  pivot_longer(-c(indicator, direction, model), names_to = "metric",
               values_to = "metric_value") %>%
  ggplot(aes(x = model, y = metric_value)) +
  facet_wrap(~ metric, scales = "free") +
  geom_boxplot() +
  geom_jitter(width = 0.1, height = 0, color = "gray50", alpha = 0.2) +
  coord_flip() +
  theme_minimal()


# LightGBM ----------------------------------------------------------------

res_raw <- bind_rows(
  read_csv("results/run-02_results.csv"),
  read_csv("results/run-03_results.csv"),
  read_csv("results/run-04_results.csv")
)

res <- res_raw
res$mg_id <- res$indicator <- res$direction <- res$model <- NULL

res <- res %>%
  pivot_longer(num_iterations:lambda_l2, names_to = "param", values_to = "param_value") %>%
  mutate(cv_pos_rate = NULL, test_pos_rate = NULL) %>%
  pivot_longer(-c(hp_set_id, param, param_value), names_to = "metric", values_to = "metric_value")

res <- res %>%
  group_by(hp_set_id, param, metric) %>%
  summarize(param_value = mean(param_value),
            metric_value = mean(metric_value))

res %>%
  filter(metric %in% c("cv_log_loss")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point()

res %>%
  filter(metric %in% c("cv_brier")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ metric, scales = "free") +
  geom_point()

res %>%
  filter(metric %in% c("cv_auc_roc")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point()

res %>%
  filter(metric %in% c("cv_auc_pr")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ metric, scales = "free") +
  geom_point()

res %>%
  filter(metric %in% c("test_auc_roc")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point() +
  theme_minimal()

res %>%
  filter(metric %in% c("test_auc_pr")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point() +
  theme_minimal()


# Lambda L2 seems to be key
res_subset <- res %>%
  pivot_wider(names_from = "param", values_from = "param_value") %>%
  filter(lambda_l2 > 0, lambda_l1 > 0, learning_rate < 0.5) %>%
  pivot_longer(-c(hp_set_id, metric, metric_value), names_to = "param",
               values_to = "param_value")

res_subset %>%
  filter(metric %in% c("test_auc_roc")) %>%
  ggplot(aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point() +
  geom_smooth() +
  theme_minimal()



# XGBoost -----------------------------------------------------------------

xgboost_raw <- bind_rows(
  read_csv("results/run-05_results.csv"),
  read_csv("results/run-06_results.csv"),
  read_csv("results/run-07_results.csv"),
  read_csv("results/run-08_results.csv"),
  read_csv("results/run-09_results.csv"),
  read_csv("results/run-10_results.csv")
)

res_xgboost <- xgboost_raw
res_xgboost$mg_id <- res_xgboost$indicator <- res_xgboost$direction <- res_xgboost$model <- NULL

res_xgboost <- res_xgboost %>%
  pivot_longer(nrounds:alpha, names_to = "param", values_to = "param_value") %>%
  mutate(cv_pos_rate = NULL, test_pos_rate = NULL) %>%
  pivot_longer(-c(hp_set_id, param, param_value), names_to = "metric", values_to = "metric_value")

res_xgboost <- res_xgboost %>%
  group_by(hp_set_id, param, metric) %>%
  summarize(param_value = mean(param_value),
            metric_value = mean(metric_value))

xgboost_defaults <- tibble(
  param = c("alpha", "eta", "gamma", "max_depth", "nrounds", "min_child_weight",
            "max_delta_step", "subsample", "colsample_bytree", "colsample_bylevel",
            "colsample_bynode", "lambda", "alpha"),
  param_value = c(0, 0.3, 0, 6, 100, 1,
                  0, 1, 1, 1,
                  1, 1, 0)
)

res_xgboost %>%
  filter(metric %in% c("cv_auc_roc")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point() +
  geom_vline(data = xgboost_defaults, aes(xintercept = param_value), color = "red") +
  theme_minimal() +
  geom_smooth()

res_xgboost %>%
  filter(metric %in% c("test_auc_roc")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point() +
  geom_vline(data = xgboost_defaults, aes(xintercept = param_value), color = "red") +
  theme_minimal() +
  geom_smooth()


# zoom in on lower eta, higher nrounds subset
res_subset_xgboost <- res_xgboost %>%
  pivot_wider(names_from = "param", values_from = "param_value") %>%
  filter(eta < 0.3) %>%
  pivot_longer(-c(hp_set_id, metric, metric_value), names_to = "param",
               values_to = "param_value")

res_subset_xgboost %>%
  filter(metric %in% c("cv_auc_roc")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point() +
  geom_vline(data = xgboost_defaults, aes(xintercept = param_value), color = "red") +
  theme_minimal() +
  geom_smooth()

res_subset_xgboost %>%
  filter(metric %in% c("test_auc_roc")) %>%
  ggplot(., aes(x = param_value, y = metric_value)) +
  facet_wrap(param ~ ., scales = "free") +
  geom_point() +
  geom_vline(data = xgboost_defaults, aes(xintercept = param_value), color = "red") +
  theme_minimal() +
  geom_smooth()
