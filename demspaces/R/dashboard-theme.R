#
#   Dashboard theme - colors etc.
#

#' @keywords internal
#'
#' @examples
#' color_direction(c("Opening", "Closing", "Same", ""))
color_direction <- function(direction) {
  sapply(direction, switch, "Opening" = "#0082BA", "Closing" = "#F37321",
         "Same" = "#D0D0D1", "#D0D0D1"
  )
}
