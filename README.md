Democratic Spaces Barometer
===========================

The Demoractic Spaces Barometer forecasts significant changes, both democratizing and autocratizing, for six facets of democratic governance for all major countries in the world 2 years ahead. The forecasts can be explored with the dashboard at https://www.v-dem.net/demspace.

To run the dashboard locally _without_ cloning the whole repo, you can use the code below, which will download and then run a tarball of the dashboard app. This presupposes all necessary packages are installed, see [dashboard/setup.R](dashboard/setup.R). 

```r
library(shiny)
runUrl('https://github.com/vdeminstitute/demspaces/raw/main/dashboard/demspaces-dashboard.tar.gz')
```

The data and forecasts, going back to the original version in 2019, are archived in the [`archive/`](archive/) folder. 


Documentation
-------------

There are various bits of documentation and other notes and reports in this repo as well.

For a general background and overall overview of the project, we wrote a technical report at the conclusion of the development of DemSpaces between 2019--2020:

- [Democratic Spaces Barometer Technical Report, 2020](docs/IRI_DArch_Final_Report_2020-03-30.pdf)

Documentation for the spring 2021 update:

- [2021 Update README](2021-update/)
- [Spring 2021 Forecast Update Report](docs/DemocraticSpaces2021.pdf)
- [FAQ for the 2021 Forecast Update](docs/DemSpaces2021-Questions.pdf)
- [Project Summary Memo](2021-update/project-summary.pdf): this is a good summary of all technical changes.
- [Variable Importance Note](2021-update/variable-importance.md): details on how and why some external data sources and variables were removed during the 2021 update. 

Documentation for the spring 2022 update:

- [2022 Update README](2022-update/)
- Several technical notes (note that these were with the original dependent variables, "v12", before the ERT-lite "v12.1" change):
  + [Investigation into the high Associational closing risk for France](2022-update/whatif-france.md): Why does France have a high Associational closing risk in this year's forecasts?
  + [Variable Importance for Moving Standard Deviation Variable Transforms](2022-update/vi-sdvars.md): I added a small number of moving standard deviation transforms of V-Dem indices--as indicators of recent instability--based on the variable importance analysis in this note.
  + [RF Stability (rf-stability.md)](rf-stability.md): What is the impact of the number of trees in a forest on the variability of point forecasts? In other words, how many trees buy you a sufficient reduction in the "randomness" of random forests?
  + [Tuning experiments (tuning-experiments.md)](tuning-experiments.md): Tuning experiments to determine the fixed hyperparameters that are now used in all models.


Citation
--------

If you refer to this project in academic work, we would appreciate it if you could cite:

Andreas Beger, Richard K. Morgan, and Laura Maxwell, 2020, “The Democratic Spaces Barometer: Global Forecasts of Autocratization and Democratization”, <https://www.v-dem.net/demspace>.

In Bibtex:

```bibtex
@misc{beger2020democratic,
  auhor = {Beger, Andreas and Morgan, Richard K. and Maxwell, Laura},
  title = {The Democratic Spaces Barometer: Global Forecasts of Autocratization and Democratization},
  year  = {2020},
  url   = {https://www.v-dem.net/demspace},
}
```

Code overview
-------------

This repo contains the code and data needed to reproduce the forecasts and dashboard. It is organized into three self-contained folders:

- `create-data/`: combine V-Dem and other data sources into the historical data that is used to code the dependent variables and estimate the forecast models
- `modelrunner/`: contains the random forest forecast models and will generate both the test and live forecasts
- `dashboard/`: the R Shiny dashboard at the V-Dem website

The folders are self-contained in the sense that each has a copy of the inputs it needs to run, and will not reach into other folders to pull code or data. For example, `modelrunner` saves the forecasts to `output/fcasts-rf.csv`, and `dashboard` contains a copy of these forecasts in `Data/fcasts-rf-2020.csv`. *(This also means that if there are any changes in relevant data, they need to be manually copied over.)*

The `forecasts/` folder contains a record of the forecasts we since the first version with V-Dem v9 in 2019. 

## Setup

The R packages needed to run all code in this repo are listed in `required-packages.txt`. Two packages need special treatment:

- **demspacesR** is not on CRAN. This package contains some custom model wrappers to make it easier to work with the 12 outcome variables we are modeling. It can be installed with:
  ```r
  remotes::install_github("vdeminstitute/demspacesR")
  ```
- **states** needs to be at least version 0.2.2.9007, which by the time you are reading this may be met by the version on CRAN. If not, you can also install the development version from GitHub:
  ```r
  # Check the package version
  packageVersion("states")
  if (packageVersion("states") < "0.2.2.9007") {
    remotes::install_github("andybega/states")
  }
  ```

To check for and install the remaining packages, try:

```r
packs <- readLines("required-packages.txt")
need  <- packs[!packs %in% rownames(installed.packages())]
need
install.packages(need)
```

## Reproducing the forecasts

1. In `create-data/`, run the data munging scripts in the `scripts/` folder to recreate the final data, `output/states.rds`. See `create-data/README.md` for more details.
2. In `modelrunner/`, run `R/rf.R` to run the forecast models and create the test and live forecasts. See `modelrunner/README.md` for more details.
3. Update the forecast data in `dashboard`.

## Updates

See [UPDATING.md](UPDATING.md) for notes.

## Contributing

We welcome any error and bug reports dealing with mistakes in the existing code and data. Please open an issue here on GitHub. 

This repo is not under active development and mainly serves for the sake of transparency and to allow reproduction of the forecasts and dashboard. There is no plan for continuing development aside from, potentially, annual forecast updates in the future. It is thus unlikely that more substantive feedback, like suggestions about additional features/predictors or alternative models, would be incorporated unless you do most of the legwork and can clearly demonstrate improved performance. This is not meant as discouragement, we simply don't have the resources to put more time in this and want to prevent disappointment. 

## Acknowledgement

The Democratic Space Barometer is the product of a collaboration between Andreas Beger ([Basil Analytics](https://www.basilanalytics.com)), Richard K. Morgan ([V-Dem](https://www.v-dem.net/en/)), and Laura Maxwell ([V-Dem](https://www.v-dem.net/en/)).

The six conceptual dimensions we focus on come from the International Republican Institute’s Closing Space Barometer, which includes an analytical framework for assessing the processes that facilitate a substantial reduction (closing events) within these six spaces. This framework was developed based on a series of workshops conducted with Democracy, Human Rights, and Governance (DRG) donors and implementing partners in 2016 and represent the conceptual features of democratic space which are most amenable to DRG assistance programs.

We adapted these conceptual spaces, expanded the scope to include substantial improvements (opening events), and developed an operationalization method to identify opening and closing events within each space. This dashboard, and the forecast that drive it, is the output of these efforts.

## Dev notes

The original Democratic Spaces project development and code, which covers the 2019 and 2020 forecasts (V-Dem v9 and v10), was in these 3 repos:

- [`andybega/closing-spaces`](https://github.com/andybega/closing-spaces) (private): development repo with all the ugly bits
- [`andybega/democratic-spaces`](https://github.com/andybega/democratic-spaces): a cleaned-up subset of the development repo for reproducibility
- [`andybega/demspaces`](https://github.com/andybega/demspaces): companion R package with helper functions

For the 2021 V-Dem v11 update I copied over the existing code in the last two repos to the corresponding V-Dem owned repos. 


