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

# https://books.ropensci.org/targets/projects.html#sharing-targets
# TODO: This will need to read from S3, and potentially switch stores based on assessment_year
tar_load(
  c(
    advice_hist,
    stock_dev,
    tac_hist,
    landings_by_gear,
    landings_by_fishing_year_country
  ),
  store = "_assessment_model"
)

list(
  # Read historical landings from file
  # TODO: The other option should be to read from last year's S3 bucket
  tar_target(
    historical_assessment_file,
    "data/assessment.csv",
    format = "file"
  ),
  tar_target(
    assessment_hist,
    hr_update_hist(
      hr_assessment_template(),
      historical_assessment_file,
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
    data_assessment,
    hr_advice_data_assessment(assessment_hist),
    format = pax::pax_tar_format_parquet()
  ),

  tar_target(
    data_prog_input,
    stock_dev |>
      dplyr::inner_join(prog_input_notes_table, by = c("name", "year"))
  ),

  tar_target(
    data_prognosis,
    hr_advice_data_prognosis(
      basis_table,
      tac_hist,
      ref_points,
      stock_dev,
      assessment_year
    )
  ),

  tar_target(
    data_tac,
    hr_advice_data_tac(advice_hist, tac_hist, landings_by_fishing_year_country)
  ),

  tar_target(
    data_landings,
    hr_advice_data_landings(landings_by_gear),
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
