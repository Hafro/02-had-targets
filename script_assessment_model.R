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
  ## Populate local database
  tar_target(
    pax_db,
    if (nzchar(Sys.getenv("PAX_SOURCE_DB"))) {
      pax_connect(Sys.getenv("PAX_SOURCE_DB"))
    } else {
      pax_from_mar(
        species,
        year_start,
        year_end,
      )
    },
    format = pax_tar_format_duckdb()
  ),

  ## Generate input data
  tar_target(
    input_data_lw_pred,
    hr_input_data_lw(
      pax_db,
      sampling_type = 30,
      prediction_length_range = 1:150
    ),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    input_data_maturity_key,
    hr_input_data_maturity_key(
      pax_db,
      lgroup = seq(0, 200, 5),
      regions = list(
        S = c(101, 107, 106, 108, 109, 114),
        N = c(102, 103, 104, 105, 111, 113),
        S = pax_add_other()
      ),
    ),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    input_data_igfs_index,
    hr_input_data_si_index(
      pax_db,
      sampling_type = 30,
      sam_use_10_11_first_2_years = TRUE,
      tow_number = 0:35,
      lw_key = input_data_lw_pred,
      maturity_key = input_data_maturity_key,
      strata_name = "old_strata",
      tgroup = NULL,
      regions = list(
        S = c(101, 107, 106, 108, 109, 114),
        N = c(102, 103, 104, 105, 111, 113),
        S = pax_add_other()
      )
    ),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    input_data_agfs_index,
    hr_input_data_si_index(
      pax_db,
      regions = list(all = 101:115),
      sampling_type = 35,
      sam_use_10_11_first_2_years = TRUE,
      tow_number = 0:75,
      gear_id_filter = 77:78,
      strata_name = "new_strata_autumn"
    ),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    input_data_comm_index,
    hr_input_data_si_index(
      pax_db,
      sampling_type = c(1, 2, 8),
      sam_use_10_11_first_2_years = TRUE,
      tgroup = list(t1 = 1:6, t2 = 7:12),
      gear_group = list(
        Other = 'Var',
        BMT = NA, # i.e. unknown gears are BMT
        BMT = c('BMT', 'NPT', 'SHT', 'PGT', 'DRD'),
        LLN = c('HLN', 'LLN', 'GIL'),
        DSE = c('PSE', 'DSE')
      ),
      scale_by_landings = TRUE
    ),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    # TODO: Starts in 1903, not 1970
    input_data_landings,
    hr_input_data_landings(
      pax_db
    ),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    input_data,
    hr_input_data_had(
      year_start,
      year_end,
      age_start = 0,
      age_end = age_end,
      input_data_comm_index,
      input_data_igfs_index,
      input_data_agfs_index,
      input_data_landings
    ),
    format = pax::pax_tar_format_parquet()
  ),

  ## Build/run SAM model
  tar_target(
    sam_dat,
    hr_sam_dat(
      model_dat = input_data |> dplyr::filter(year <= assessment_year, age > 0),
      minage = 1,
      maxage = 12
    ),
    format = 'rds'
  ),

  tar_target(
    sam_conf,
    hr_sam_conf(
      sam_dat
    ),
    format = 'rds'
  ),

  tar_target(
    sam_fit,
    SAMutils::full_sam_fit(
      sam_dat,
      sam_conf
    ),
    format = 'rds'
  )
)
