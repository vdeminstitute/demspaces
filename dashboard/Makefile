# Don't use this for updating. This is a convenience for re-building the
# dashboard once the initial update has been done and only minor changes are
# being made

demspaces-dashboard.tar.gz: global.R server.R ui.R dash-data
	tar --exclude='data-raw' --exclude='.DS_Store' --exclude='Makefile' \
	--exclude='demspaces-dashboard.tar.gz' --exclude='README.md' \
	--exclude='setup.R' \
	-zcvf demspaces-dashboard.tar.gz .

# data-raw/update-data.R writes multiple outputs. I want to track all outputs,
# but don't want make to re-run data-raw/update-data.R multiple times.
# Solution in theory is a grouped target, but macos' make is pre-4.3, so grouped
# target with & won't work yet. This approach works also, from:
# https://stackoverflow.com/a/10609434/1083960
data/country_characteristics_dat.rds data/map_color_data.rds map_dat.rds \
  prob1_dat.rds table_dat.rds: dash-data ;
.INTERMEDIATE: dash-data
dash-data: data-raw/update-data.R data-raw/dv_data_1968_on.csv \
  data-raw/fcasts-rf.csv data-raw/region-mapping.csv
		Rscript data-raw/update-data.R

# Update data-raw inputs from other folders if neccessary
data-raw/dv_data_1968_on.csv: ../create-data/trafo-data/dv_data_1968_on.csv
		cp ../create-data/trafo-data/dv_data_1968_on.csv data-raw/

data-raw/region-mapping.csv: ../create-data/output-data/region-mapping.csv
		cp ../create-data/output-data/region-mapping.csv data-raw

data-raw/fcasts-rf.csv: ../modelrunner/output/fcasts-rf.csv
		cp ../modelrunner/output/fcasts-rf.csv data-raw/


