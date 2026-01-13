# 2023 Modelling and Tuning experiments

- run 1: comparison of the existing RF models and default XGBoost and LightGBM.

- run 2: learning rate from 0.01 - 1.0
- run 3: learning rate from 0.01 - 0.4

- run 4: lambda1 and lambda2 from 0 - 2 instead of from (0 or (0 - 1)), bagging_freq less samples from 0

- run 5: HP for XGBoost; because of error had fixed nrounds
- run 6-8: XGBoost, now with fixed nrounds sampling

- run 9: explore higher nrounds [200, 400] and lower eta [0, 0.2].
- run 10: nrounds [10, 400] but eta focus more on [0, 0.3].

- run 11: horse race with new xgboost_2023
