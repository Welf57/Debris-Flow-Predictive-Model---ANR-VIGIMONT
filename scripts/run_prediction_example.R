##############################################################################
## Example: predict debris-flow triggering probability for full rainfall
## events using the pre-trained Random Forest model.
##
## Steps:
##   1) Build the rainfall event(s) and extract the descriptors used by the
##      model from a 15-min rainfall series and lightning-strike files
##      already restricted to 30 km and 2 km around the watershed of
##      interest (the watershed's exact location is not disclosed).
##   2) Filter rainfall event(s) above the ID threshold
##   3) Feed the event(s) into the pre-trained Random Forest model.
##   4) Display the predicted triggering probability for each event.
##
## Input rainfall data is assumed to already be at a 15-min time step.
## rain_15min_event.csv contains several distinct rainfall events (e.g.
## triggering and non-triggering): extract_rain_events()
## automatically separates them based on the 
## Minimum Duration of Rainfall Interruption
##############################################################################
pkgload::load_all(".")
library(terra)

## --- 0. Load the pre-trained model and its normalization parameters --------
rf_model    <- readRDS("../inst/extdata/model_rf.rds")
norm_params <- readRDS("../inst/extdata/normalization_params.rds")
model_variables <- readRDS("../inst/extdata/model_variables.rds")   # variables expected by the model
id_threshold_params <- readRDS("../inst/extdata/id_threshold_params.rds")

## --- 1. Load raw inputs ------------------------------------------------------

lightning_30km <- vect("../inst/extdata/lightning_30km.geojson")
lightning_2km  <- vect("../inst/extdata/lightning_2km.geojson")

rain_15min <- read.csv("../inst/extdata/rain_15min_event.csv", sep = ";", stringsAsFactors = FALSE)
rain_15min$Date <- as.POSIXct(rain_15min$Date, format = "%d/%m/%Y %H:%M", tz = "UTC")

## --- 2. Discretize the rainfall event(s) and extract their descriptors ----------
event_data <- build_rainfall_event(
  rain_15min     = rain_15min,
  lightning_30km = lightning_30km,
  lightning_2km  = lightning_2km
)

## --- 3. Test if the event is above the ID threshold ---------------------

event_data$Above_ID <- is_above_ID(event_data, id_threshold_params)
event_data_above_ID <- event_data[event_data$Above_ID == TRUE,]

## --- 4. Predict the triggering probability -----------------------------------
prediction <- predict_debris_flow_probability(
  events_df       = event_data_above_ID,
  rf_model        = rf_model,
  norm_params     = norm_params,
  model_variables = model_variables
)

print(prediction)

## Debris-flow triggering rainfall events are the one that happened during the
## following periods: 
## "2011-11-03 09:00:00 - 2011-11-05 14:45:00"
## "2013-07-06 13:45:00 - 2013-07-06 19:30:00"
## "2016-10-14 04:15:00 - 2016-10-14 12:30:00"
## "2022-08-09 15:30:00 - 2022-08-09 19:00:00"

## --- 5. Visualize the model output --------------------------------------------
plot_debris_flow_probabilities(prediction, threshold = 0.065)

