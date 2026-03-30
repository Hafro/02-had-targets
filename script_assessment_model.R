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
      lgroups = seq(0, 200, 5),
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
  ),

  ## Update advice with current assessment
  tar_target(
    historical_advice_file,
    "data/advice_hist.csv",
    format = "file"
  ),
  tar_target(
    advice_hist,
    hr_update_hist(
      historical_advice_file,
      data.frame(
        assessment_year = assessment_year,
        advice = SAMutils::rby.sam(sam_fit$fit, run_ref_bio = TRUE) |>
          dplyr::filter(variable == 'ref_bio', year == assessment_year) |>
          dplyr::mutate(median = round(0.35 * median)) |>
          dplyr::pull(median),
        advice_basis.en = 'TAC 0.35 x B45+cm',
        advice_basis.is = '35 % aflaregla'
      )
    )
  ),

  ## Update TAC with current assessment
  tar_target(
    historical_tac_file,
    "data/tac_hist.csv",
    format = "file"
  ),
  tar_target(
    tac_hist,
    hr_update_hist(
      historical_tac_file,
      data.frame(
        assessment_year = assessment_year,
        ices_area = '5a',
        tac = advice_hist |>
          filter(assessment_year == .env$assessment_year) |>
          dplyr::pull(advice)
      )
    ),
    format = pax::pax_tar_format_parquet()
  ),

  ## Prognosis
  tar_target(
    prognosis,
    {
      starting_catch <-
        dplyr::tbl(pax_db, "landings") |>
        dplyr::filter(
          species == .env$species,
          ices_area == '5a',
          year == local(assessment_year - 1),
          # i.e. select the first half of the fishing year
          (is.na(month) || month >= 9),
        ) |>
        dplyr::summarise(l = sum(catch) / 1e3) |>
        dplyr::pull(l)
      tac_previous <- tac_hist[
        tac_hist$assessment_year == assessment_year - 1,
        "tac"
      ]
      tac_latest <- tac_hist[tac_hist$assessment_year == assessment_year, "tac"]

      x <- stockassessment::forecast(
        sam_fit$fit,
        catchval = c(
          ## This years catch (remainder of current fishing year TAC at the beginning of this year + 1/3 of next years TAC)
          tac_previous - starting_catch + tac_latest / 3,
          ## Next years TAC
          tac_latest,
          NA
        ),
        fval = c(
          NA,
          NA,
          0.45
        ),
        deterministic = TRUE #, ave.years = max(res$fit$data$years) + (-0)
      )
      stockassessment::forecast(
        sam_fit$fit,
        catchval = c(
          ## This years catch (remainder of current fishing year TAC at the beginning of this year + 1/3 of next years TAC)
          tac_previous - starting_catch + tac_latest / 3,
          ## Next years TAC
          2 / 3 * tac_latest + attr(x, 'tab')[2, 'IS_refbio:median'] * 0.35 / 3,
          NA
        ),
        fval = c(
          NA,
          NA,
          0.45
        ),
        deterministic = TRUE #, ave.years = max(res$fit$data$years) + -(0)
      )
    },
    format = "rds"
  ),
  tar_target(
    stock_dev,
    as.data.frame(attr(prognosis, 'tab')) |>
      dplyr::select(dplyr::contains('median')) |>
      dplyr::mutate(
        year = assessment_year:(assessment_year + n() - 1),
        ssb_ratio = (`ssb:median` / lag(`ssb:median`)),
      ) |>
      tidyr::pivot_longer(-year) |>
      dplyr::mutate(
        name = gsub(':median', '', name),
        name = ifelse(name == "IS_HR", "HR", name),
        name = ifelse(name == "IS_refbio", "refbio", name)
      )
  ),

  ## Projections
  tar_target(
    projections_at_age_file,
    "data/projections_at_age.csv",
    format = "file"
  ),
  tar_target(
    projections_at_age_hist,
    hr_update_hist(
      projections_at_age_file,
      data.frame(
        assessment_year = assessment_year
        # TODO: Presumably munge SAMutils::rbya.sam(sam_fit$fit), but do we need to do a projection first?
      )
    ),
    format = pax::pax_tar_format_parquet()
  ),

  ## Landings summaries for advice
  tar_target(
    landings_by_fishing_year_country,
    dplyr::tbl(pax_db, "landings") |>
      pax::pax_add_fishing_year() |>
      dplyr::group_by(fishing_year, country) |>
      dplyr::summarize(catch = sum(catch, na.rm = TRUE)) |>
      dplyr::arrange(fishing_year),
    format = pax::pax_tar_format_parquet()
  ),
  tar_target(
    landings_by_gear, # Was advice/tables/landings.csv
    dplyr::tbl(pax_db, "landings") |>
      pax::pax_landings_by_gear(),
    format = pax::pax_tar_format_parquet()
  )
)
