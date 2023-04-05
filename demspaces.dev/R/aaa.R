
.onLoad <- function(libname, pkgname) {
  if (file.exists(here::here("config.yml"))) {
    set_options(here::here("config.yml"))
  }
}

.onAttach <- function(libname, pkgname) {
  if (!is.null(getOption("demspaces.version"))) {
    msg <- paste0("---- demspaces.dev\nUsing version: '",
                  getOption("demspaces.version"),
                  "'\n----")
  } else {
    msg <- paste0("---- demspaces.dev\nWARNING: could not find 'config.yml', manually set options with 'set_options(\"path/to/config.yml\")'\n----")
  }

  packageStartupMessage(msg)
}

#' @importFrom rlang .data

#' @importFrom magrittr %>%
#' @export
magrittr::`%>%`

#' @importFrom utils globalVariables
utils::globalVariables(
  c(".", "year", "Value", "v2xcs_ccsi_codelow", "v2xcs_ccsi_codehigh")
)
