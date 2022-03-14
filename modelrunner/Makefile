# Just a convenience for copying over states.rds

ALL: input/states-v12.rds input/cutpoints.csv output/tuning/all-results.rds
.PHONY: ALL

input/states-v12.rds: ../create-data/output/states-v12.rds
		cp ../create-data/output/states-v12.rds input/

input/cutpoints.csv: ../create-data/output/cutpoints.csv
		cp ../create-data/output/cutpoints.csv input/

# copy over the latest tuning file from dropbox
output/tuning/all-results.rds: ~/Dropbox/Work/vdem/demspaces/tuning/all-results.rds
		cp ~/Dropbox/Work/vdem/demspaces/tuning/all-results.rds output/tuning
