Democratic Spaces Barometer
===========================

The Demoractic Spaces Barometer forecasts significant changes, both democratizing and autocratizing, for six facets of democratic governance for all major countries in the world 2 years ahead. The forecasts can be explored with the dashboard at https://www.v-dem.net/en/analysis/DemSpace/.

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

1. In `create-data/`, run the data munging scripts in the `scripts/` folder to recreate the final data, `output-data/states.rds`. See `create-data/README.md` for more details.
2. In `modelrunner/`, run `R/rf.R` to run the forecast models and create the test and live forecasts. See `modelrunner/README.md` for more details.
3. Update the forecast data in `dashboard`.

## Updates

The `create-data`, `modelrunner`, and `dashboard` folders contain the core components of the project. They are designed to be self-contained, and outputs from one that serve as inputs in others have to be manually copied over. See the respective README's for more details. I also tried to mark all places that require manual updates with "UPDATE:". 

The general process is to:

1. Update the merged data using `create-data`, including the external data sources that feed into the final merged data. Copy the updated `states.rds` data to `modelrunner/input/`. 
2. Run the forecast model using `modelrunner/R/rf.R`. Copy `modelrunner/output/fcasts-rf.csv` to `dashboard/data/`.
3. Update the dashboard by rebuilding the data and manually updating the text in the UI where needed. 

## Citation

Andreas Beger, Richard K. Morgan, and Laura Maxwell, 2020, “The Democratic Spaces Barometer: global forecasts of autocratization and democratization”, <https://www.v-dem.net/en/analysis/DemSpace/>

```bibtex
@misc{beger2020democratic,
  auhor = {Beger, Andreas and Morgan, Richard K. and Maxwell, Laura},
  title = {The Democratic Spaces Barometer: Global Forecasts of Autocratization and Democratization},
  year  = {2020},
  url   = {https://www.v-dem.net/en/analysis/DemSpace/},
}
```

## Contributing

We welcome any error and bug reports dealing with mistakes in the existing code and data. Please open an issue here on GitHub. 

This repo is not under active development and mainly serves for the sake of transparency and to allow reproduction of the forecasts and dashboard. There is no plan for continuing development aside from, potentially, annual forecast updates in the future. It is thus unlikely that more substantive feedback, like suggestions about additional features/predictors or alternative models, would be incorporated unless you do most of the legwork and can clearly demonstrate improved performance. This is not meant as discouragement, we simply don't have the resources to put more time in this and want to prevent disappointment. 

## Acknowledgement

The Democratic Space Barometer is the product of a collaboration between Andreas Beger ([Predictive Heuristics](https://www.predictiveheuristics.com)), Richard K. Morgan ([V-Dem](https://www.v-dem.net/en/)), and Laura Maxwell ([V-Dem](https://www.v-dem.net/en/)).

The six conceptual dimensions we focus on come from the International Republican Institute’s Closing Space Barometer, which includes an analytical framework for assessing the processes that facilitate a substantial reduction (closing events) within these six spaces. This framework was developed based on a series of workshops conducted with Democracy, Human Rights, and Governance (DRG) donors and implementing partners in 2016 and represent the conceptual features of democratic space which are most amenable to DRG assistance programs.

We adapted these conceptual spaces, expanded the scope to include substantial improvements (opening events), and developed an operationalization method to identify opening and closing events within each space. This dashboard, and the forecast that drive it, is the output of these efforts.

## Dev notes

The original Democratic Spaces project development and code, which covers the 2019 and 2020 forecasts (V-Dem v9 and v10), was in these 3 repos:

- [`andybega/closing-spaces`](https://github.com/andybega/closing-spaces) (private): development repo with all the ugly bits
- [`andybega/democratic-spaces`](https://github.com/andybega/democratic-spaces): a cleaned-up subset of the development repo for reproducibility
- [`andybega/demspaces`](https://github.com/andybega/demspaces): companion R package with helper functions

For the 2021 V-Dem v11 update I copied over the existing code in the last two repos to the corresponding V-Dem owned repos. 


