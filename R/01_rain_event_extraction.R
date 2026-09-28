#' Discretize rainfall events and their descriptors from a 15-min rainfall series
#'
#' Identifies rainfall "bursts" and merges them into events based on a
#' Minimum Duration of Rainfall Interruption (MDRI), then computes the rainfall
#' descriptors actually used by the debris-flow triggering model (duration, maximum
#' intensities at various durations, dry period before the event, seasonal
#' descriptors, rainfall energy).
#'
#' The input rainfall series is assumed to already be at a 15-min time step
#' (if needed, any aggregation from finer raw data must be done upstream).
#'
#' @param rain_event_df Data.frame with columns Date and Cumul_dT (rainfall
#'   depth per 15-min time step).
#' @param dT Time step (minutes) of rain_event_df. Must be 15.
#' @param MDRI_value Minimum Duration of Rainfall Interruption in minutes: 
#' two bursts separated by more dry time than this are considered separate events.
#' @param date_format Date format used in rain_event_df$Date.
#' @return A data.frame with one row per rainfall event and one column per
#'   descriptor used by the model (plus Dates, Cumul, Mean.Intensity, Imax as
#'   intermediate/reference columns).
#' @export
extract_rain_events <- function(
    rain_event_df,
    dT = 15,
    MDRI_value = 180,
    date_format = "%Y-%m-%d %H:%M:%S") {

  if (dT != 15) {
    stop("This pipeline expects a 15-min rainfall time step (dT = 15).")
  }

  rain_vec <- rain_event_df$Cumul_dT

  MDRI <- MDRI_value
  burst_list <- list()
  current_burst <- c()
  current_burst_values <- c()
  uncertain_burst <- c()
  j <- 0
  k <- 0

  ## --- Burst extraction -----------------------------------------------------
  for (i in seq_along(rain_vec)) {
    if (i <= j) next
    if (rain_vec[i] > 0) {
      for (j in i:length(rain_vec)) {
        if (j < k) next
        if (rain_vec[j] > 0) {
          current_burst <- c(current_burst, j)
          current_burst_values <- c(current_burst_values, rain_vec[j])
          next
        }
        if (rain_vec[j] == 0) {
          k <- j
          while (rain_vec[k] == 0 & k < length(rain_vec)) {
            uncertain_burst <- c(uncertain_burst, k)
            k <- k + 1
          }
          if (length(uncertain_burst) >= max(1, 30 / dT)) {
            if (sum(current_burst_values) > 0.6) {
              burst_list <- append(burst_list, list(current_burst))
            }
            current_burst <- c()
            current_burst_values <- c()
            uncertain_burst <- c()
            k <- 0
            break
          } else {
            current_burst <- c(current_burst, uncertain_burst)
            uncertain_burst <- c()
            next
          }
        }
      }
    }
  }

  ## --- Merge bursts into events based on MDRI --------------------------------
  events <- list()
  current_event <- c()
  if (length(burst_list) == 1) {
    current_event <- c(current_event, burst_list[[1]])
    events <- append(events, list(current_event))
  }
  if (length(burst_list) > 1) {
    for (i in seq_len(length(burst_list))) {
      current_event <- c(current_event, burst_list[[i]])
      if (i < length(burst_list)) {
        time_gap <- (burst_list[[i + 1]][1] - burst_list[[i]][length(burst_list[[i]])]) * dT
      } else {
        time_gap <- MDRI_value + 1
      }
      if (time_gap > MDRI_value) {
        events <- append(events, list(current_event))
        current_event <- c()
      }
    }
  }

  ## --- Compute descriptors for each event ------------------------------------
  events_df <- data.frame(
    Dates = character(length(events)),
    YearMoisJour = numeric(length(events)),
    Duration = numeric(length(events)),
    Cumul = numeric(length(events)),
    Mean.Intensity = numeric(length(events)),
    Imax = numeric(length(events))
  )

  if (length(events) != 0) {
    for (i in seq_along(events)) {
      duration_time <- (events[[i]][length(events[[i]])] - events[[i]][1] + 1) * dT / 60
      if (duration_time == 0) duration_time <- dT / 60
      start_step <- events[[i]][1]
      end_step <- events[[i]][length(events[[i]])]
      event_rain_data <- as.numeric(rain_vec[events[[i]]])
      cumul <- sum(event_rain_data)
      mean_intensity <- cumul / duration_time
      imax <- max(event_rain_data * (60 / dT))

      events_df$Dates[i] <- paste(rain_event_df$Date[start_step], "-", rain_event_df$Date[end_step])
      events_df$YearMoisJour[i] <- as.numeric(gsub("-", "", substr(events_df$Dates[i], 1, 10)))
      events_df$Duration[i] <- duration_time
      events_df$Cumul[i] <- cumul
      events_df$Mean.Intensity[i] <- mean_intensity
      events_df$Imax[i] <- imax

      ## Maximum intensity at various durations
      padded <- c(rep(0, 5), event_rain_data)
      imax_30 <- max(unlist(slider::slide(padded, mean, .before = 1, .after = 0))) * (60 / dT)
      imax_45 <- max(unlist(slider::slide(padded, mean, .before = 2, .after = 0))) * (60 / dT)
      imax_60 <- max(unlist(slider::slide(padded, mean, .before = 3, .after = 0))) * (60 / dT)
      imax_90 <- max(unlist(slider::slide(padded, mean, .before = 5, .after = 0))) * (60 / dT)

      events_df$Imax_15min[i] <- imax
      events_df$Imax_30min[i] <- imax_30
      events_df$Imax_45min[i] <- imax_45
      events_df$Imax_60min[i] <- imax_60
      events_df$Imax_90min[i] <- imax_90

      ## Time between event start and Imax
      imax_idx <- which.max(event_rain_data)
      events_df$Time_Between_Start_Imax[i] <- (events[[i]][imax_idx] - events[[i]][1]) * (dT / 60)

      ## Dry period before the event
      k <- events[[i]][1] - 1
      dry_period <- 0
      if (k > 0) {
        while (as.numeric(rain_vec[k]) == 0) {
          dry_period <- dry_period + dT / 60
          k <- k - 1
          if (k <= 0) break
        }
      }
      events_df$DryPeriod_BeforeEvent[i] <- dry_period

      ## Time since end of winter
      event_start_day <- as.POSIXct(sub(" -.*", "", events_df$Dates[i]), format = date_format, tz = "UTC")
      winter_end <- as.POSIXct(paste0(format(event_start_day, "%Y"), "-03-01 00:00:00"), tz = "UTC")
      winter_end_prev <- as.POSIXct(paste0(as.numeric(format(event_start_day, "%Y")) - 1, "-03-01 00:00:00"), tz = "UTC")
      time_since_winter <- difftime(event_start_day, winter_end, units = "hours")
      time_since_winter[time_since_winter < 0] <- time_since_winter[time_since_winter < 0] + 365 * 24
      events_df$TimeSinceWinter[i] <- as.numeric(time_since_winter)

      ## Significant events since end of winter
      if (i > 1) {
        if (format(event_start_day, "%m-%d") >= "01-01" & format(event_start_day, "%m-%d") < "03-01") {
          since_winter <- events_df[which(as.POSIXct(sub(" -.*", "", events_df$Dates), format = date_format, tz = "UTC") > winter_end_prev), ]
        } else {
          since_winter <- events_df[which(as.POSIXct(sub(" -.*", "", events_df$Dates), format = date_format, tz = "UTC") > winter_end), ]
        }
        n_signif <- nrow(since_winter[since_winter$Cumul > 5, ])
      } else {
        n_signif <- 0
      }
      events_df$SignifEventsSinceWinter[i] <- n_signif

      ## Rainfall energy and absolute energy
      energy <- sum(event_rain_data * event_rain_data)
      events_df$Rainfall_Energy[i] <- energy
      events_df$Absolute_Energy[i] <- energy / duration_time
    }
  }

  events_df
}
