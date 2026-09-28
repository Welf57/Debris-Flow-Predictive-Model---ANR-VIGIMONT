

#' Predict debris-flow triggering probability for one or more rainfall events
#'
#' Loads a pre-trained ranger Random Forest model and its associated
#' normalization parameters, normalizes the input event(s) accordingly, and
#' returns the predicted triggering probability for each event.
#'
#' @param events_df Data.frame of rainfall events (output of
#'   \code{build_rainfall_event}), containing at least the columns listed in
#'   \code{model_variables}.
#' @param rf_model A ranger model object (e.g. loaded with
#'   \code{readRDS("model_rf.rds")}).
#' @param norm_params Named list of normalization parameters (e.g. loaded
#'   with \code{readRDS("normalization_params.rds")}).
#' @param model_variables Character vector of variable names expected by the
#'   model, in the exact form used at training time.
#' @return A data.frame with one row per event and columns Event (Dates) and
#'   Probability (predicted probability of debris-flow triggering).
#' @export
predict_debris_flow_probability <- function(events_df, rf_model, norm_params, model_variables) {

  missing_vars <- setdiff(model_variables, names(events_df))
  if (length(missing_vars) > 0) {
    stop("The following model variables are missing from events_df: ",
         paste(missing_vars, collapse = ", "))
  }

  df_eval <- events_df[, model_variables, drop = FALSE]
  df_eval_norm <- apply_normalization(df_eval, norm_params)

  prediction <- predict(object = rf_model, data = df_eval_norm)

  data.frame(
    Event = events_df$Dates,
    Probability = prediction$predictions[, "1"],
    stringsAsFactors = FALSE
  )
}


#' Plot predicted debris-flow triggering probabilities
#'
#' Simple bar plot of the predicted probability for each rainfall event,
#' intended as a lightweight visualization of the model output on a small
#' test dataset.
#' Debris-flow triggering rainfall events are the one that happened during the
#' following periods: "2011-11-03 09:00:00 - 2011-11-05 14:45:00",
#' "2013-07-06 13:45:00 - 2013-07-06 19:30:00",
#' "2016-10-14 04:15:00 - 2016-10-14 12:30:00" and 
#' "2022-08-09 15:30:00 - 2022-08-09 19:00:00"
#'
#' @param prediction_df Output of \code{predict_debris_flow_probability}.
#' @param threshold Optional probability threshold to display as a reference
#'   line (e.g. an operational alert threshold).
#' @export
plot_debris_flow_probabilities <- function(prediction_df, threshold = 0.065) {
  bar_colors <- if (!is.null(threshold)) {
    ifelse(prediction_df$Probability >= threshold, "firebrick", "steelblue")
  } else {
    "steelblue"
  }

  bp <- barplot(
    prediction_df$Probability,
    names.arg = seq_len(nrow(prediction_df)),
    col = bar_colors,
    ylim = c(0, max(1, max(prediction_df$Probability, na.rm = TRUE) * 1.2)),
    xlab = "Event index",
    ylab = "Predicted probability of triggering",
    main = "Debris-flow triggering probability by event"
  )

  if (!is.null(threshold)) {
    abline(h = threshold, lty = 2, col = "black")
    text(x = 0.9*max(bp), y = threshold, labels = paste0("threshold = ", threshold),
         pos = 3, cex = 0.8)
  }

  invisible(bp)
}
