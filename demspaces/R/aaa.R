
.onLoad <- function(libname, pkgname) {
  if (file.exists(here::here("config.yml"))) {
    set_options(here::here("config.yml"))
  }
}

.onAttach <- function(libname, pkgname) {
  if (!is.null(getOption("demspaces.version"))) {
    msg <- paste0("---- demspaces\nUsing version: '",
                  getOption("demspaces.version"),
                  "'\n----")
  } else {
    msg <- paste0("---- demspaces\nWARNING: could not find 'config.yml', manually set options with 'set_options(\"path/to/config.yml\")'\n----")
  }

  packageStartupMessage(msg)
}
