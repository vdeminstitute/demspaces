
#' Format seconds
#'
#' Format seconds into hh:mm:ss
#'
#' @param x a numeric vector
#'
#' @examples format_sec(1683)
#'
#' @export
format_sec <- function(x) {

  hh <- x %/% 3600
  x  <- x %% 3600
  mm <- x %/% 60
  x  <- x %% 60
  ss <- round(x)

  str <- sprintf("%ds", ss)
  idx <- (mm > 0 | hh > 0)
  if (any(idx)) {
    str[idx] <- sprintf("%dm %s", mm[idx], str[idx])
  }
  idx <- (hh > 0)
  if (any(idx)) {
    str[idx] <- sprintf("%dh %s", hh[idx], str[idx])
  }
  str <- gsub("^0", "", str)
  str
}
