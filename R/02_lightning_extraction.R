#' Maximum number of lightning strikes in a sliding time window
#'
#' @param dates POSIXct vector of strike timestamps.
#' @param start_event,end_event POSIXct bounds of the rainfall event.
#' @param window_min Sliding window length in minutes.
#' @return Integer, maximum count of strikes within any window of that length
#'   during the event.
#' @export
max_strikes_sliding <- function(dates, start_event, end_event, window_min) {
  dates_in_event <- sort(dates[dates >= start_event & dates <= end_event])
  if (length(dates_in_event) == 0) return(0)

  window_sec <- window_min * 60
  upper_idx <- findInterval(as.numeric(dates_in_event) + window_sec, as.numeric(dates_in_event))
  counts <- upper_idx - seq_along(dates_in_event) + 1
  max(counts)
}


#' Extract the lightning-strike descriptors used by the model, for each event
#'
#' Computes, for each rainfall event, only the lightning-strike descriptors
#' actually used by the debris-flow triggering model. This function expects
#' lightning strikes already filtered to 30 km and 2 km around the watershed
#' of interest.
#'
#' @param rain_events_df Data.frame of rainfall events (one row per event)
#'   with a Dates column formatted as produced by \code{extract_rain_events}.
#' @param lightning_30km A SpatVector (terra) or data.frame of lightning
#'   strikes already restricted to a 30 km radius, with a flash_time
#'   attribute (character, "%Y-%m-%d %H:%M:%OS").
#' @param lightning_2km A SpatVector (terra) or data.frame of lightning
#'   strikes already restricted to a 2 km radius, with a flash_time
#'   attribute (character, "%Y-%m-%d %H:%M:%OS").
#' @return rain_events_df with added lightning-strike descriptor columns:
#'   N_LghtStrk_2km, Max_LghtStrk_30km_60min, Max_LghtStrk_2km_30min,
#'   Max_LghtStrk_2km_60min, Max_LghtStrk_2km_90min.
#' @export
extract_basin_lightning <- function(rain_events_df, lightning_30km, lightning_2km) {

  dates_30km <- as.POSIXct(lightning_30km$flash_time, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")
  dates_2km  <- as.POSIXct(lightning_2km$flash_time, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")

  for (l in seq_len(nrow(rain_events_df))) {
    event_l <- rain_events_df[l, ]
    start_l <- as.POSIXct(substr(event_l$Dates, 1, 19), format = "%Y-%m-%d %H:%M", tz = "UTC")
    end_l   <- as.POSIXct(substr(event_l$Dates, 23, 41), format = "%Y-%m-%d %H:%M", tz = "UTC")

    rain_events_df$N_LghtStrk_2km[l] <- length(dates_2km[dates_2km >= start_l & dates_2km <= end_l])

    rain_events_df$Max_LghtStrk_30km_60min[l] <- max_strikes_sliding(dates_30km, start_l, end_l, 60) / 60

    rain_events_df$Max_LghtStrk_2km_30min[l] <- max_strikes_sliding(dates_2km, start_l, end_l, 30) / 30
    rain_events_df$Max_LghtStrk_2km_60min[l] <- max_strikes_sliding(dates_2km, start_l, end_l, 60) / 60
    rain_events_df$Max_LghtStrk_2km_90min[l] <- max_strikes_sliding(dates_2km, start_l, end_l, 90) / 90
  }

  rain_events_df
}
