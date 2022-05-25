Democratic Spaces Dashboard
========================

This is the R Shiny app that is shown at https://www.v-dem.net/demspace.

[`setup.r`](setup.r) is a sourceable script that will check for and if neccessary ask to install the required packages.

If you have cloned this repo, run `startup.R` to serve the dashboard in a local browser. 

To run the dashboard locally without cloning the whole repo (this still requires the packages listed in [`setup.r`](setup.r)):

```r
library(shiny)
runUrl('https://github.com/vdeminstitute/demspaces/raw/main/dashboard/demspaces-dashboard.tar.gz')
```
