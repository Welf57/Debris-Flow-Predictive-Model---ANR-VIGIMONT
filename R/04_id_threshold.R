#' Test whether rainfall events lie above the (fixed) ID triggering threshold
#'
#' Applies a pre-fitted Intensity-Duration (ID) threshold, expressed as a set
#' of coefficients (\code{id_threshold_params}), to a data.frame of rainfall
#' events. The threshold itself was fitted once on a reference dataset (see
#' the package's internal documentation); only its resulting coefficients are
#' distributed here, not the reference data used to derive them.
#'
#' @param df Data.frame of rainfall events to test, with at least Duration
#'   and Mean.Intensity columns.
#' @param id_threshold_params A named list of coefficients produced when the
#'   threshold was fitted: \code{type} ("regression" or "IC95_inf"), \code{a},
#'   \code{b}, \code{delta_alpha}, and — for \code{type == "IC95_inf"} —
#'   \code{n}, \code{xbar}, \code{SSx}, \code{sigma_hat}, \code{t_crit}.
#' @return Logical vector, TRUE where the event's mean intensity lies above
#'   the ID threshold for its duration.
#' @export
is_above_ID <- function(df, id_threshold_params) {

  p <- id_threshold_params
  logDur   <- log10(df$Duration)
  logIMean <- log10(df$Mean.Intensity)

  if (p$type == "regression") {
    seuil <- p$a + p$b * logDur + p$delta_alpha
  } else { # "IC95_inf"
    y_hat <- p$a + p$b * logDur
    marge <- p$t_crit * p$sigma_hat * sqrt(1 / p$n + (logDur - p$xbar)^2 / p$SSx)
    seuil <- y_hat - marge + p$delta_alpha
  }

  logIMean > seuil
}
