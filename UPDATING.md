Updating the data and forecasts
===============================

The `create-data`, `modelrunner`, and `dashboard` folders contain the core components of the project. They are designed to be self-contained, and outputs from one that serve as inputs in others have to be manually copied over. See the respective README's for more details. I also tried to mark all places that require manual updates with "UPDATE:".

The general process is to:

1. Update the merged data using `create-data`, including the external data sources that feed into the final merged data. Copy the updated `states.rds` data to `modelrunner/input/`.
2. Run the forecast model using `modelrunner/R/rf.R`. Copy `modelrunner/output/fcasts-rf.csv` to `dashboard/data/`.
3. Update the dashboard by rebuilding the data and manually updating the text in the UI where needed.


## Things to improve in the next cycle

Ideas for what to improve in the next update cycle. 

Redo tuning for the RF models. The number of predictors went down a lot, so probably different HP values now give better results. I am also not happy with the remaining CV auto-tuning for mtry. Like I did with the PART models, rather move to more extensive manual tuning experiments and then just hard-code all hyperparameters in the forecast models so that they run massively quicker. The PART random forests (about 8 of them, compared to ~100 here becauase we have 12 outcomes) run in under 10m after this change, so probably I could get these down to under 1 hours, rather than the current 7 or 8 hours. (I did manual pre-tuning of this sort for the first iteration of this project, see `andybega/closing-spaces/2019-11-tunerf` and the git ignored `modeldev/` code.)

Speaking of which, integrate what's left in `modeldev` (the development modelrunner) into the main modelrunner. 

Clean up the differentiation between primary outputs and ancillary trackers for git. Like put the latter in `tracker` folders or something like that. 

Makefile automation. Although the data updating requires manual, interactive checking, most of the other stuff down the road lends itself to full automation. To that end I started writing both versioned and un-versioned file names already, but this can probably be taken further. Also, make life is easier if output file names correspond to R script names; then I could use pattern rules instead of the current ugly mess of targets and recipes. 


