
.onLoad <- function(libname, pkgname) {
  if (file.exists("config.yml")) {
    config <- yaml::read_yaml("config.yml")
    options(demspaces.version = config$version,
            demspaces.current_window = "2022 - 2023")
  }
}

.onAttach <- function(libname, pkgname) {
  msg <- paste0("---- demspaces\nUsing version: '",
                getOption("demspaces.version"),
                "'\n----")
  packageStartupMessage(msg)
}
