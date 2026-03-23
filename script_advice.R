# _targets.R file
library(pax)
library(targets)
library(tarchetypes)

tar_option_set(
  packages <- c(
    'hafroreports',
    'pax',
    'tidyverse'
  ),
  tidy_eval = TRUE
)

tar_source("config.R")
tar_source() # Source R/*.R

list(
  # Open database from assessment_model
  tar_target(
    pax_db,
    pax_connect("_assessment_model/objects/pax_db", read_only = TRUE),
    format = pax_tar_format_duckdb()
  ),

  ## tables
  tar_target(advice_table_landings, hr_advice_table_landings(pax_db)),

  ## Advice sheets
  tar_quarto(
    advice_en,
    path = "advice_en.qmd",
    quiet = FALSE
  ),
  tar_quarto(
    advice_is,
    path = "advice_is.qmd",
    quiet = FALSE
  )
)
