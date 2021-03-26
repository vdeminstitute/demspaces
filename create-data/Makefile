# Don't use this for updating. I just added this as a convenience when
# rebuilding the data with the same V-Dem version.

STATES = output-data/states-v11.rds

# made by scripts/0-split-raw-vdem.R
$(STATES): trafo-data/country_year_set_1968_on.csv trafo-data/vdem_data_1968_on.csv
# made by scripts/2-create-dv-data.Rmd
$(STATES): trafo-data/dv-data.rds
$(STATES): scripts/3-combine-data.Rmd
		cd scripts; Rscript -e 'rmarkdown::render("3-combine-data.Rmd", output_format = "all")'
		rm scripts/3-combine-data.html

trafo-data/dv-data.rds: trafo-data/dv_data_1968_on.csv
trafo-data/dv-data.rds: output-data/cutpoints.csv
trafo-data/dv-data.rds: scripts/2-create-dv-data.Rmd
		cd scripts; Rscript -e 'rmarkdown::render("2-create-dv-data.Rmd", output_format = "all")'
		rm scripts/2-create-dv-data.html

output-data/cutpoints.csv: trafo-data/dv_data_1968_on.csv
output-data/cutpoints.csv: scripts/1-calculate-cutpoints.Rmd
		cd scripts; Rscript -e 'rmarkdown::render("1-calculate-cutpoints.Rmd", output_format = "all")'
		rm scripts/1-calculate-cutpoints.html

# macos' make is pre-4.3, so grouped target with & won't work yet
# hack to avoid multiple invocations of 0-....R; https://stackoverflow.com/a/10609434/1083960
trafo-data/country_year_set_1968_on.csv trafo-data/vdem_data_1968_on.csv trafo-data/dv_data_1968_on.csv: split-raw-vdem-output ;
.INTERMEDIATE: split-raw-vdem-output
split-raw-vdem-output: scripts/0-split-raw-vdem.R input/V-Dem-CY-Full+Others-v11.rds
		Rscript scripts/0-split-raw-vdem.R

#input/gdp.csv: external-data/gdp/output/gdp.csv
#		cp external-data/gdp/output/gdp.csv input/
