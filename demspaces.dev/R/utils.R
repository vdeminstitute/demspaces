
# When loading the package from Rmd files, the working directory will not be
# root, meaning the usual package load will not find the global config.yml file
# This function sets the option when given path to the config file.
set_options <- function(file = NULL) {
  config <- yaml::read_yaml(file)
  opts <- config
  names(opts) <- paste0("demspaces.", names(opts))
  do.call(options, opts)
  invisible(opts)
}

#' Get all current DemSpaces options
#'
#' @return named list
#' @export
all_options <- function() {
  options()[grepl("demspaces", names(options()))]
}

#' Option accessor
#'
#' Get DemSpaces internal package options, with additional safety checks. I.e.
#' I don't want to build the merge data with a NULL value for start_year.
#'
#' @param x Option name, either short like "version" or with the prefix like
#'   "demspaces.version".
#'
#' @return Option value, with correct type.
#'
#' @export
get_option <- function(x) {
  if (!grepl("demspaces", x)) {
    op_id <- paste0("demspaces.", x)
  } else {
    op_id <- x
  }
  op <- getOption(op_id)
  # option-specific safety checks:
  if (op_id=="demspaces.data_start_year") {
    op <- as.integer(op)
    stopifnot(
      "value is NA" = !is.na(op),
      "value is NULL" = !is.null(op)
    )
  }
  if (op_id=="demspaces.data_end_year") {
    op <- as.integer(op)
    stopifnot(
      "value is NA" = !is.na(op),
      "value is NULL" = !is.null(op)
    )
  }
  if (op_id=="demspaces.min_f") {
    op <- as.numeric(op)
    stopifnot(
      "value is NA" = !is.na(op),
      "value is NULL" = !is.null(op)
    )
  }
  op
}



proj_root <- function(...) {
  root_path <- get_option("root_path")
  if (is.null(root_path) | root_path=="") {
    stop("Invalid root path, is it set in the config file?")
  }
  file.path(root_path, ...)
}

#' @param version Data version, e.g. "v13"; default is the latest available.
#'
#' @details This function will preferentially look for data in
#'   `create-data/output` so that during updates the latest available data is
#'   read. As a backup it will check in `archive/data`.
#'
#' @export
read_merge_data <- function(version = "latest") {
  if (version=="latest") {
    available <- dir(proj_root("create-data/output"), pattern = "v[0-9\\.]+.rds")
    file_path <- proj_root("create-data/output", tail(available, 1))
  } else {
    file_name <- sprintf("states-%s.rds", version)
    # check if available
    exists_in_create_data <- file.exists(proj_root("create-data/output", file_name))
    if (exists_in_create_data) {
      file_path <- proj_root("create-data/output", file_name)
    } else {
      exists_in_archive <- file.exists(proj_root("archive/data", file_name))
      if (!exists_in_archive) {
        stop("Could not find data with this version")
      }
      file_path <- proj_root("archive/data", file_name)
    }
  }
  readRDS(file_path)
}



