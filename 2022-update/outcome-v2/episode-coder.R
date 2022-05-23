#
#   ERT-lite episode coder
#

episode_coder <- function(x, cp, direction = c("up", "down")) {
  stopifnot(
    "cp must be single number" = length(cp)==1,
    "cp must be single numer" = is.numeric(cp),
    "x must be a numeric vector" = is.numeric(cp)
  )
  direction <- match.arg(direction)

  # to get the down direction, we can simply reverse x
  if (direction=="down") {
    x <- -1 * x
  }

  ep <- integer(length(x))
  # The total window considered is up to 2 back and 1 forward, so those values
  # in a vector are missing because the window is incomplete. However, if the
  # simple t:t-1 change is above cutpoint, we _can_ code a 1 instead of NA.
  # For that reason also, do the simple 1-year back window after doing the
  # more complicated windows.
  ep[1:2] <- NA_integer_
  ep[length(ep)] <- NA_integer_

  # t:t-1 difference
  xd1 <- c(NA, diff(x))

  # 2-year window, looking back
  # if the change from 2 years ago is > cp, and both the current xd1 and
  # xd1[t-1] are above some minimal treshold, we can code episode
  xd2 <- c(NA, NA, diff(x, lag = 2))
  xd1_lg1 <- c(NA, head(xd1, -1))
  # condition 1: 2-year change is > cp
  # condition 2: 1-year change is < cp
  # condition 3: xd1[t-1] is above minimal threshold
  c1 <- (xd2 > cp) %in% TRUE
  c2 <- (xd1 > (cp*0.1)) %in% TRUE
  c3 <- (xd1_lg1 > (cp*0.1)) %in% TRUE
  ep[c1 & c2 & c3] <- 1L

  # Look ahead version, same logic but we don't want to include the year
  # before opening started, so need to consider 2-year change from [t-1] to
  # [t+1] for point t
  xd1_ld1 <- c(tail(xd1, -1), NA)
  xd2_ld1 <- c(tail(xd2, -1), NA)
  c1 <- (xd2_ld1 > cp) %in% TRUE
  c2 <- (xd1 > (cp*0.1)) %in% TRUE
  c3 <- (xd1_ld1 > (cp*0.1)) %in% TRUE
  ep[c1 & c2 & c3] <- 1L

  # Simple t:t-1 criterion
  ep[(xd1 > cp) %in% TRUE] <- 1L

  ep
}

# time_series_dat_v2 <- time_series_dat
# col <- rep("black", length(x))
# col[up %in% 1L] <- "red"
# plot(foo$v2x_freexp_altinf, col = col)

#' Code changes vector for one indictor for one country
changes_one_country <- function(x, cp) {
  up <- episode_coder(x, cp, "up")
  down <- episode_coder(x, cp, "down")
  if (any((up %in% 1) & (down %in% 1))) stop("Something wrong")
  changes <- rep("same", length(x))
  changes[is.na(up) | is.na(down)] <- NA_character_
  changes[up %in% 1] <- "up"
  changes[down %in% 1] <- "down"
  changes
}

#changes_one_country(foo[[ind]], cp[[ind]])
