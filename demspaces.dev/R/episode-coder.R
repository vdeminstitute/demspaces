#
#   ERT-lite episode coder
#

#' Episode coder
#'
#' Identifies opening/closing episodes in a stream of space indicator values.
#'
#' @param x vector containing values for one of the space indicators, for
#'   \emph{one country} only.
#' @param cp a single value for the space cutpoint
#' @param direction code opening ("up") or closing ("down") events?
#' @param type use the original single-year event coding ("orig"), or the ERT-lite coding ("mod")?
#' @param min_f for type="mod", the minimum yearly change threshold factor to use.
#'   This is multiplied with the space cutpoint to determine the minimum yearly
#'   change threshold.
#'
#' @returns `episode_coder` returns a binary (integer) vector with `length(x)`
#'   marking opening or closing events in `x`
#'
#' @export
#' @aliases changes_one_country
episode_coder <- function(x, cp, direction = c("up", "down"),
                          type = c("mod", "orig", "2year"),
                          min_f = 0.1) {
  stopifnot(
    "cp must be single number" = length(cp)==1,
    "cp must be single numer" = is.numeric(cp),
    "x must be a numeric vector" = is.numeric(cp)
  )
  direction <- match.arg(direction)
  type <- match.arg(type)

  # to get the down direction, we can simply reverse x
  if (direction=="down") {
    x <- -1 * x
  }

  # Initialize to 0 and then below only set NA's and 1's as needed
  # Easier than initializing to NA because 0's are non-trivial to code
  # explicitly, just like 1's
  ep <- rep(0L, length(x))

  if (type=="orig") {
    # t:t-1 difference
    xd1 <- c(NA, diff(x))
    ep[1] <- NA_integer_

    # Simple t:t-1 criterion
    ep[(xd1 > cp) %in% TRUE] <- 1L
  }

  if (type=="2year") {
    # Instead of only looking at whether the year-to-year change is greater
    # than the cutpoint, look at the change over a 2-year window, i.e. change
    # from 2 years prior

    # t:t-2 difference
    xd2 <- c(NA, NA, diff(x, lag = 2))

    ep[1:2] <- NA_integer_
    ep[(xd2 > cp) %in% TRUE] <- 1L
  }

  if (type=="mod") {
    # The total window considered is up to 2 back and 1 forward, so those values
    # in a vector are missing because the window is incomplete. However, if the
    # simple t:t-1 change is above cutpoint, we _can_ code a 1 instead of NA.
    # For that reason also, do the simple 1-year back window after doing the
    # more complicated windows.
    ep[1:2] <- NA_integer_
    ep[length(ep)] <- NA_integer_

    # t:t-1 difference
    xd1 <- c(NA, diff(x))
    # t:t-2 difference
    xd2 <- c(NA, NA, diff(x, lag = 2))

    # 2-year window, looking back
    # if the change from 2 years ago is > cp, and both the current xd1 and
    # xd1[t-1] are above some minimal treshold, we can code episode
    xd1_lg1 <- c(NA, utils::head(xd1, -1))
    # condition 1: 2-year change is > cp
    # condition 2: 1-year change is < cp
    # condition 3: xd1[t-1] is above minimal threshold
    c1 <- (xd2 > cp) %in% TRUE
    c2 <- (xd1 > (cp*min_f)) %in% TRUE
    c3 <- (xd1_lg1 > (cp*min_f)) %in% TRUE
    ep[c1 & c2 & c3] <- 1L

    # Look ahead version, same logic but we don't want to include the year
    # before opening started, so need to consider 2-year change from [t-1] to
    # [t+1] for point t
    xd1_ld1 <- c(utils::tail(xd1, -1), NA)
    xd2_ld1 <- c(utils::tail(xd2, -1), NA)
    c1 <- (xd2_ld1 > cp) %in% TRUE
    c2 <- (xd1 > (cp* min_f)) %in% TRUE
    c3 <- (xd1_ld1 > (cp* min_f)) %in% TRUE
    ep[c1 & c2 & c3] <- 1L

    # Simple t:t-1 criterion
    ep[(xd1 > cp) %in% TRUE] <- 1L
  }

  as.integer(ep)
}

# time_series_dat_v2 <- time_series_dat
# col <- rep("black", length(x))
# col[up %in% 1L] <- "red"
# plot(foo$v2x_freexp_altinf, col = col)

#' @rdname episode_coder
#'
#' @returns `changes_one_country` returns a character vector with `length(x)`
#'   and values "same", "up", "down"
#'
#' @export
changes_one_country <- function(x, cp, type = c("mod", "orig", "2year"), min_f = 0.1) {
  type <- match.arg(type)
  up <- episode_coder(x, cp, "up", type, min_f)
  down <- episode_coder(x, cp, "down", type, min_f)
  if (any((up %in% 1) & (down %in% 1))) stop("Something wrong")
  changes <- rep("same", length(x))
  changes[is.na(up) | is.na(down)] <- NA_character_
  changes[up %in% 1] <- "up"
  changes[down %in% 1] <- "down"
  changes
}

#changes_one_country(foo[[ind]], cp[[ind]])
