2021 Update (v11)
================

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

2020 Update (v10)
================

- Data range from 1970 to 2019.
- Added Archigos state leader data as a data source, with 5 variables.

2019 initial version (v9)
=========================

Original forecasts produced during development of this project in the fall of 2019. 
