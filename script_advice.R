# _targets.R file
library(targets)
library(tarchetypes)

tar_source("config.R")
tar_source() # Source R/*.R

list(
  # Open database from assessment_model
  tar_target(
    pax_db,
    pax::pax_connect("_assessment_model/objects/pax_db", read_only = TRUE),
    format = pax::pax_tar_format_duckdb()
  ),

  ## tables
  tar_target(advice_table_landings, ft_advice_table_landings(pax_db)),

  ## Advice sheets
  tar_quarto(
    advice_en,
    path = "advice_en.qmd",
    execute_params = list(
      tac = tac,
      tac_last_year = tac_last_year,
      year_end = year_end
    ),
    quiet = FALSE
  ),
  tar_quarto(
    advice_is,
    path = "advice_is.qmd",
    execute_params = list(
      tac = tac,
      tac_last_year = tac_last_year,
      year_end = year_end
    ),
    quiet = FALSE
  )
)
