Closing spaces dashboard
========================

This is the R Shiny app that is shown at https://www.v-dem.net/en/analysis/DemSpace/

Run `StartUp.R` to serve the dashboard prototype in a local browser. 

To update the dashboard with new data, see the 2020 data cleaning R script in the `Data/` folder and copy over the relevant output files from the `create-data` and `modelrunner` folders. 

Also, search for all "2021-2022" strings in the dashboard files and replace.


To run the dashboard locally (this also presupposes all neccessary packages are installed):

```r
library(shiny)
runUrl('https://github.com/vdeminstitute/demspaces/raw/main/dashboard/demspaces-dashboard.tar.gz')
```
