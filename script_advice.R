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

icesSAG::sag_use_token(FALSE)

list(
  # Open database from assessment_model
  tar_target(
    pax_db,
    pax_connect("_assessment_model/objects/pax_db", read_only = TRUE),
    format = pax_tar_format_duckdb()
  ),

  # Read historical landings from file
  # TODO: The other option should be to read from last year's S3 bucket
  tar_target(
    historical_assessment_file,
    "data/assessment.csv",
    format = "file"
  ),
  tar_target(
    assessment,
    hr_assessment_combine(
      readr::read_csv(historical_assessment_file),
      # Override any current assessment_year data in file with SAG data
      hr_assessment_from_sag(
        species,
        ices_stock_key_label,
        ices_median_refbio = ices_median_refbio,
        assessment_year = assessment_year
      )
    ),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    assessment_results,
    hr_advice_table_assessment(assessment),
    format = pax::pax_tar_format_parquet()
  ),

  ## tables
  tar_target(
    advice_table_landings,
    hr_advice_table_landings(pax_db),
    format = pax::pax_tar_format_parquet()
  ),

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
