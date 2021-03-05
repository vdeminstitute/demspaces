2021 Update (v3)
================

- Variable importance investigation. 

### Simplify states data

- Drop the Ethnic Power Relations, Archigos leader data, and Armed Conflict Dataset data sources. 
- In the V-Dem data, drop the year to year change and moving average transformations, keeping only the squared transformation of the dependent variables. 
- In the Powell & Thyne coup data, keep only an indicator for the number of years since the last coup attempt. 


### Add versioning system. 

For the 2021 update, I (AB) added an explicit versioning for key files that matches the version of the V-Dem data used in that year's forecasts. 

- Key files--the `states` merge data and the actual forecasts--now include a version suffix in the filename. 
- Copies of the key files and associated summary statistics are now preserved in the `archive/` folder. I moved the 2019 and 2020 forecasts from `forecasts/` to the archive folder. 

The first version of the forecasts in 2019 was created with V-Dem version 9 data, 2020 with version 10, etc. 


2020 Update (v2)
================

- Data range from 1970 to 2019.
- Added Archigos state leader data as a data source, with 5 variables.

2019 initial version (v1)
=========================
