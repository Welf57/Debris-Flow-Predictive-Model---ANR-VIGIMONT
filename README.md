# Debris-flow predictive model

Predict debris-flow triggering probability for rainfall events from
15-min radar-rain gauge rainfall data and lightning-strike data, using a first 
Intensity-Duration filter and a pre-trained Random
Forest model (`ranger`) developed on debris-flow triggering and non-triggering
rainfall events spread accross a network of catchments in the
Alpes-Maritimes county (France). The Random Forest model has been evaluated through
a 80/20 cross-validation. The model available in this repository is trained based 
on the full rainfall events dataset.

The example provided evaluates the model on **full rainfall events**
(the rainfall event has already ended before being submitted to the model). The same
descriptor-extraction functions could in principle be reused to evaluate a
growing rainfall event step by step, but this use case is not implemented neither
evaluated in this package.

The dataset provided to run the model is taken from the dataset used to train
the Random Forest. Therefore, the performance obtained suffer from overfitting
and should only be considered as an example of how the model is implemented.

## Pipeline

1. **Event construction and feature extraction** (`build_rainfall_event()`):
   from a 15-min rainfall series and two lightning-strike files (already
   restricted to 30 km and 2 km around the catchment of interest), builds
   the rainfall events and computes the rainfall and lightning descriptors
   needed by the model. The 15-min rainfall series and two lightning-strike files
   have been pre-extracted from a catchment whose characteristics are not
   detailed here.
2. **Intensity-Duration (ID) filter** (`is_above_ID`): tests each rainfall event
   against a fixed, pre-fitted Intensity-Duration (ID) triggering threshold.
   Events below this threshold are known not to trigger debris flows and
   are discarded before running the Random Forest model. Only the
   threshold's coefficients are distributed (`id_threshold_params.rds`);
   the reference dataset used to fit it is not shared.
3. **Prediction** (`predict_debris_flow_probability()`): normalizes the
   rainfall event's descriptors using the model's stored normalization parameters,
   then applies the pre-trained Random Forest model. Normalization parameters were
   calculated from the training dataset (i.e. 80% of the whole dataset)
   of the cross-validation process to avoid overfitting.
4. **Visualization** (`plot_debris_flow_probabilities()`): bar plot of the
   predicted triggering probability for each event, optionally against a
   reference threshold. The default threshold is set at 0.065, which has been 
   estimated to optimize the Balance Accuracy of the model.

See `scripts/run_prediction_example.R` for a complete example.

## Model variables

The model uses the following 18 descriptors:

- Rainfall: `YearMoisJour`, `Duration`, `Imax_15min`, `Imax_30min`,
  `Imax_45min`, `Imax_60min`, `Imax_90min`,
  `Time_Between_Start_Imax`, `DryPeriod_BeforeEvent`,
  `TimeSinceWinter`, `SignifEventsSinceWinter`, `Rainfall_Energy`,
  `Absolute_Energy`.
- Lightning: `N_LghtStrk_2km` (raw strike count), `Max_LghtStrk_30km_60min`,
  `Max_LghtStrk_2km_30min`, `Max_LghtStrk_2km_60min`, `Max_LghtStrk_2km_90min`
  (maximum strike rate, in strikes/min, over a sliding window of the given
  length and radius).

## Required files

Place these in `inst/extdata/`:

| File | Description |
|---|---|
| `rain_15min_event.csv` | Rainfall time series at a 15-min time step. Columns: `Date`, `Cumul_dT`. Contains rainfall series of 4 months, each containing several non-triggering rainfall events and one triggering event; `extract_rain_events()` separates them automatically based on the Minimum Duration of Rainfall Interruption. |
| `lightning_30km.geojson` | Lightning strikes already restricted to a 30 km radius around the catchment of interest, with a `flash_time` attribute, covering the same period as the rainfall series. |
| `lightning_2km.geojson` | Lightning strikes already restricted to a 2 km radius around the catchment of interest, with a `flash_time` attribute, covering the same period as the rainfall series. |
| `id_threshold_params.rds` | Named list of coefficients (`type`, `a`, `b`, `delta_alpha`, and — for `type == "IC95_inf"` — `n`, `xbar`, `SSx`, `sigma_hat`, `t_crit`) defining the fixed ID triggering threshold, used by `is_above_ID()`. |
| `model_rf.rds` | Pre-trained `ranger` Random Forest model object. |
| `normalization_params.rds` | Named list of `list(mean, sd)` per model variable, used to normalize new events the same way the training data was normalized. |
| `model_variables.rds` | Character vector giving the 18 model variable names, in the order expected by the Random Forest model. Purely informative. |
## Normalization parameters format

`normalization_params.rds` is a named list, one entry per model variable:

```r
list(
  Duration = list(mean = 12.4, sd = 8.1),
  Rainfall_Energy = list(mean = 3.2, sd = 1.9),
  ...
)
```

This file is provided directly with the model; the original training
rainfall data is not distributed with this package.

## ID threshold parameters format

`id_threshold_params.rds` is a named list holding the coefficients of the
fixed Intensity-Duration (ID) triggering threshold:

```r
list(
  type = "IC95_inf",       # or "regression"
  a = ...,                 # intercept
  b = ...,                 # slope
  delta_alpha = ...,       # quantile shift applied to the fitted line
  n = ..., xbar = ..., SSx = ..., sigma_hat = ..., t_crit = ...  # IC95_inf only
)
```

Only these coefficients are distributed; the rainfall events used to fit
the threshold are not shared with this package.

## Installation

```r
# From the package root
pkgload::load_all(".")
```

## Notes

- Rainfall descriptors (`R/01_rain_event_extraction.R`) reproduce the rainfall event
  discretization and feature extraction used during model development: rainfall event
  discretization based on a Minimum Duration of Rainfall Interuption (MDRI), maximum
  intensities at several durations, dry period before the event, seasonal
  descriptors, and rainfall energy.
- Lightning descriptors: N_LghtStrk_2km is a raw strike count (total number 
  of strikes within 2 km during the event). Max_LghtStrk_30km_60min, 
  Max_LghtStrk_2km_30min, Max_LghtStrk_2km_60min and Max_LghtStrk_2km_90min are 
  rates: each is the maximum number of strikes observed in any sliding window
  of the given length (30/60/90 min) within the given radius (2/30 km),
  divided by the window length in minutes — i.e. an average strikes-per-minute
  density over the densest such window during the event.
- Debris-flow triggering rainfall events are the one that happened during the
 following periods: "2011-11-03 09:00:00 - 2011-11-05 14:45:00",
 "2013-07-06 13:45:00 - 2013-07-06 19:30:00",
 "2016-10-14 04:15:00 - 2016-10-14 12:30:00" and 
 "2022-08-09 15:30:00 - 2022-08-09 19:00:00"
