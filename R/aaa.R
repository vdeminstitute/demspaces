
.onLoad <- function(libname, pkgname) {
  if (file.exists("config.yml")) {
    config <- yaml::read_yaml("config.yml")
    options(demspaces.version = config$version)
  }
}

.onAttach <- function(libname, pkgname) {
  msg <- paste0("---- demspaces\nUsing version: '",
                getOption("demspaces.version"),
                "'\n----")
  packageStartupMessage(msg)
}
