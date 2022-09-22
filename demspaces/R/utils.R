
# When loading the package from Rmd files, the working directory will not be
# root, meaning the usual package load will not find the global config.yml file
# This function sets the option when given path to the config file.
set_options <- function(file = NULL) {
  config <- yaml::read_yaml(file)
  options(demspaces.version = config$version)
  options(demspaces.current_window = config$current_window)
  invisible(TRUE)
}
