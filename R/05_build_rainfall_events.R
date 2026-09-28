#' Build a complete rainfall event with the descriptors used by the model
#'
#' Takes a 15-min rainfall time series that spans several passed
#' rainfall event, extracts their rainfall descriptors, and enriches
#' them with the lightning-strike descriptors used by the model.
#'
#' The example provided in this package evaluates the model on complete
#' rainfall events (the event has ended before being submitted to the
#' model). The same descriptor-extraction functions could in principle be
#' called repeatedly on a growing rainfall series to obtain a probability
#' that updates as an event unfolds; however, this package does not
#' implement or evaluate that use case, and the model's performance has only
#' been assessed on complete events.
#'
#' @param rain_15min Data.frame (Date, Cumul_dT) at 15-min resolution,
#'   covering the rainfall event.
#' @param lightning_30km Lightning strikes already restricted to a 30 km
#'   radius around the catchment of interest (SpatVector or data.frame with
#'   a flash_time column). No catchment geometry is required since the raw data
#'   have already been extracted for one catchment.
#' @param lightning_2km Lightning strikes already restricted to a 2 km
#'   radius around the watershed of interest (same format as lightning_30km).
#' @param date_format Date format used in rain_15min$Date.
#' @return A one-(or more)-row data.frame with all rainfall and lightning
#'   descriptors used by the model, for the event(s) found in the input series.
#' @export
build_rainfall_event <- function(
    rain_15min,
    lightning_30km,
    lightning_2km,
    date_format = "%Y-%m-%d %H:%M:%S") {
  
  events_df <- extract_rain_events(
    rain_event_df = rain_15min,
    dT = 15,
    date_format = date_format
  )
  
  events_df <- extract_basin_lightning(
    rain_events_df = events_df,
    lightning_30km = lightning_30km,
    lightning_2km = lightning_2km
  )
  
  events_df
}