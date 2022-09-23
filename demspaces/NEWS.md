demspaces 12.1.9000 (Fall 2022)
===============================

Two big changes (#25):
- I moved the small {demspaces} R package I added in version 12.1 during the spring update to the `demspaces/` sub-folder to reduce clutter and more clearly distinguish package from pipeline/documentation bits.
- I integrated the {demspacesR} helper package that was in the [vdeminstitute/demspacesR](https://github.com/vdeminstitute/demspacesR) repo with the {demspaces} package in this main repo. 

- As part of the package integration I expanded this news document with that from {demspacesR}.



demspaces 12.1 (2022 Update)
==========================

Note that there are forecasts with two versions this year. The initial update resulted in the "v12" forecasts. After the incorporation of the change in how outcomes are coded ("ERT-lite"), these became the new and current "v12.1" forecasts. I.e., the forecasts using the old outcome coding method are "v12", those with the new ERT-lite method are "v12.1".

### Change in outcomes

A major change this year was in the way that opening and closing events are coded. Up to an including version "v12", this was based on space-specific thresholds: if the increase or decrease in the indicator for a space from the previous year's value exceeded that threshold, we coded an event. 

This approach missed more gradual changes that over a period of multiple years could still lead to significant changes in the state of a country. The new outcome coding, used in version "v12.1", now considers more than just the year-on-year change, and is able to capture some of these more gradual transitions. 

Described in issue #16.

### Data and model changes

- Moved external data scripts to a new repo, [`ds-external-data`](https://github.com/andybega/ds-external-data). This is because PART and DS both require some but no the same external data, so it is just easier to pool them in one repo where updating can be done. 
- Removed "_squared" terms for the space indicator variables. Although these showed up highly in the 2021 variable importance investigation, there is no reason the a random forest model would need squared terms, and so I suspect they were getting picked just as surrogates for the untransformed indicator variables. (#18)
- Fix for impossible forecasts. These are situations where a country's indicator value is in the region between the possible range of values (0 - 1) and the relevant outcome cutpoints. For example, Tunisia had a high Governing opening forecast initially, even though it's Governing value was so high already that given the relevant cutpoint, no opening event was possible at all. Technically it could drop and then experience an opening in the 2nd year of the forecast, but this only happens once in the entire data. To fix this, the cutpoints are used to reset such forecasts to 0. The fix is actually implemented in demspacesR, in the `predict.ds_rf` function. (#15)
- Added "_sd10" variable transforms that are a 10-year moving standard deviation. The idea was to capture the extent of recent instability. This mildly improves fit. See the "[Variable importances for space indicator moving SD](https://github.com/vdeminstitute/demspaces/blob/main/2022-update/vi-sdvars.md)" note. (#18)
- Changed the models to use a larger number of trees to stabilize the forecasts, and upped the "mtry"" value slightly for accuracy. All hyper-parameters are fixed now, decreasing pipeline run time. This is described in the "[RF tuning experiments](https://github.com/vdeminstitute/demspaces/blob/main/2022-update/tuning-experiments.md)" note. See also the "[Experiments on the randomness of random forest forecasts](https://github.com/vdeminstitute/demspaces/blob/main/2022-update/rf-stability.md)" note.

### Dashboard changes

- Added the ability to highlight past opening and closing evens in the V-Dem indicator time series plot on the bottom right. (#12; and fixed a subsequent related bug, #17)
- Added a button for the V-Dem space indicator time series plot on the bottom right to select/de-select all 6 spaces. It's annoying to otherwise have to click each of the 6 checkboxes individually. (#13)
- Dashboard layout and style changes: two-column layout for top text in dashboard tab (#20); updates to the text in the About tab (#21); and an overall redo of the dashboard design, e.g. font weights etc. (#24). 

### 'demspaces' R package

I added a skeleton R package this year, to help make some development tasks easier.

- Added facility for global config settings. The purpose was to make it easier to control which version of data and related files is used, and specifically to make it easier to test out the new modified outcome (ERT-Lite).
- The package includes a dashboard for visualizing the differences between the original and ERT-lite outcomes. This can be run by cloing the repo and running: `devtools::load_all()); outcome_explorer_app()`.


demspaces 11 (2021 Update)
==========================

Aside from producing updated forecasts, I tried to streamline the updating process in several ways. The most important change was to reduce the number of external data sources that feed into the merge data, and the number of columns in the data overall. This also helps reduce forecast model runtime. 

### Trim states data

I eliminated several external data sources and other sets of variables, reducing the size of the merged states data from 481 to 228 columns. This was done on the basis of random forest variable importance using last year's models. Accuracy did not decrease. See `2021-update/README.md` for more details and documentation. 

The changes in the `create-data` scripts are in commit 6a78cd3d6d5c78070b6243921d9a7a2731b28211. 

Summary of the main changes:

- Drop the Ethnic Power Relations, Archigos leader data, and Armed Conflict Dataset data sources. 
- In the V-Dem data, drop the year to year change and moving average transformations, keeping only the squared transformation of the dependent variables.
- In the Powell & Thyne coup data, keep only an indicator for the number of years since the last coup attempt. 

### Add external data scripts

I added scripts in `create-data/external-data` for cleaning and updating the external, non-V-Dem data that feeds into the merge data. Namely:

- GDP data from several sources
- WDI infant mortality data
- Population data from several sources
- Powell & Thyne coup data

### Add versioning system. 

For the 2021 update, I (AB) added an explicit versioning for key files that matches the version of the V-Dem data used in that year's forecasts. 

- Key files--the `states` merge data and the actual forecasts--now include a version suffix in the filename. 
- Copies of the key files and associated summary statistics are now preserved in the `archive/` folder. I moved the 2019 and 2020 forecasts from `forecasts/` to the archive folder. 

The first version of the forecasts in 2019 was created with V-Dem version 9 data, 2020 with version 10, etc. 

### Other changes

- I added various "trackers" that record various summaries of other data files like RDS, but do so in a format like YAML or CSV that more easily shows substantive changes on git. I did this because RDS files will _always_ show as modified on git, even if the actual data is not changed, and that is an important difference. 
- Various minor changes in the dashboard, like removing explicit references to a specific forecast time interval like "2021-2022", as those have to be manually updated. 
- Removing dependencies and streamlining data for the dashboard: the tarball size has decreased from 1.3MB in the v10 version to 0.7MB, i.e. almost half. 
- Started marking places that need attention during updates with "UPDATE:", so that they can be more easily found with a global search. 
- Fix a bug in the dashboard that prevented clicking on a bar in the bottom left plot to add/remove the corresponding index from the linechart on the right (#5). 
- Fix a phantom nav item in the dashboard navigation bar by moving the nav bar style tags to the dashboard CSS file (#2).

### demspacesR 0.3

Development in February 2021. 

- Moved package to **vdeminstitute** GitHub account; package renamed from **demspaces** to **demspacesR**
- Added mean log loss to `score_ds_fcast()`. This is a better metric for comparing models to each other than AUC-ROC/PR. 


demspaces 10 (2020 Update)
==========================

- Data range from 1970 to 2019.
- Added Archigos state leader data as a data source, with 5 variables.

demspaces 9 (2019 Initial Version)
==================================

Original forecasts produced during development of this project in the fall of 2019. 
### demspacesR 0.2 

Development in November 2019.

* Added a tuner for `ds_rf()` that picks optimal `mtry` values. 

### demspacesR 0.1

Development in October 2019. 

* `reg_logreg()` and `ds_reg_logreg()` implement a self-tuning regularized logistic regression model based on the **glmnet** package. Tuning is performed via cross-validation and successively picks alpha and then lambda values. 
* `rf()` and `ds_rf()` implement a random forest probability tree model using the **ranger** package. 

### demspacesR 0.0.1

Initial version in September 2019. This had the following models:

* `logistic_reg()` is a standard logistic regression model, with `ds_logistic_reg()` as a wrapper for modeling democratic spaces. It includes an option to standardize features prior to model estimation ("normalize" argument), using a standardizer function made by `make_standardizer()`. 
* `logistic_reg_featx()` and `ds_logistic_reg_featx()` are standard logistic regression models with a feature extraction pre-processing step for the input feature data. This uses PCA (the only method implemented currently) to reduce the number of numeric input features to 5, via `make_extract_features()`. 

The GitHub repo, but not package, includes a template for adding new models in `add_new_model.R`. 
