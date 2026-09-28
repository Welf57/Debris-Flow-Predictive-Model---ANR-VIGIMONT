#' Apply pre-computed normalization parameters to a data.frame
#'
#' Normalizes a rainfall event's descriptors using the mean/sd parameters
#' that were computed at training time and are distributed alongside the
#' model (normalization_params.rds). The original training data is
#' not required and is not distributed with this package.
#'
#' @param df Data.frame to normalize (e.g. a newly built rainfall event).
#' @param params Named list of list(mean, sd), one entry per model variable,
#'   loaded from the distributed normalization_params.rds file.
#' @return df with each listed variable replaced by its z-score.
#' @export
apply_normalization <- function(df, params) {
  for (v in names(params)) {
    mu <- params[[v]]$mean
    sigma <- params[[v]]$sd
    df[[v]] <- if (is.na(sigma) || sigma == 0) 0 else (df[[v]] - mu) / sigma
  }
  df
}
