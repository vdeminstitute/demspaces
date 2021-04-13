#
#   Pull references from a central BibTeX file, which not everyone might have,
#   to a reduced local version that only includes cite keys needed for a
#   document.
#

library(condensebib)

stopifnot(basename(getwd())=="2021-update")

reduce_bib(
  # Path to local .tex or .md/.Rmd document
  file       = "DemocraticSpaces2021.Rmd",
  # Path to central .bib file
  master_bib = "../../../whistle/master.bib",
  # Path for local .bib file
  out_bib    = "refs.bib"
)
