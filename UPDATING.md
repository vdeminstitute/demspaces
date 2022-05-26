Updating the data and forecasts
===============================

The `create-data`, `modelrunner`, and `dashboard` folders contain the core components of the project. They are designed to be self-contained, and outputs from one that serve as inputs in others have to be manually copied over. See the respective README's for more details. I also tried to mark all places that require manual updates with "UPDATE:".

The general process is to:

1. Update the external data (this part is shared with PART) in `andybega/ds-external-data`. 
2. Update the config settings in `config.yml`.
3. Update the merged data using `create-data`, including the external data sources that feed into the final merged data. Copy the updated `states.rds` data to `modelrunner/input/`.
4. Run the forecast model using `modelrunner/R/rf.R`. Copy `modelrunner/output/fcasts-rf.csv` to `dashboard/data/`.
5. Update the dashboard by rebuilding the data and manually updating the text in the UI where needed.


## Things to improve in the next cycle

Ideas for what to improve in the next update cycle. 

- In 2022, I ran tuning experiments to pick fixed HPs. However, I did that before the ERT-lite change, i.e. with "v12" not "v12.1" data. So those could probably be re-run.
- I started a skeleton R package during the last update. There are two basic directions to go in with this: (1) throw everything--data, models, forecasts, dashboard--into a big monolithic `demspaces` package, or (2) do a demspaces-verse with more lighweight packages, e.g. for the dashboard. Right now I'm thinking do a lightweight package with the current forecasts and dashboard, and then leave everyhing else in a big dev package. Hmm. 

Items from the 2021 update that I didn't spend time on (I think):

- Clean up the differentiation between primary outputs and ancillary trackers for git. Like put the latter in `tracker` folders or something like that. 
- Makefile automation. Although the data updating requires manual, interactive checking, most of the other stuff down the road lends itself to full automation. To that end I started writing both versioned and un-versioned file names already, but this can probably be taken further. Also, make life is easier if output file names correspond to R script names; then I could use pattern rules instead of the current ugly mess of targets and recipes. 


