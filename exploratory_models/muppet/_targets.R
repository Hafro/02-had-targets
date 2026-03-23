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

tar_source("../../config.R")
tar_source() # Source R/*.R

list(
  ## Fetch pax_db from main assessment model
  tar_target(
    pax_db,
    pax_connect("../../_assessment_model/objects/pax_db", read_only = TRUE),
    format = pax_tar_format_duckdb()
  ),

  ## Read input_data from main assessment model
  tar_target(file_input_data, "../../_assessment_model/objects/input_data", format = "file"),
  tar_target(
    input_data,
    # NB: Assume that the main pipeline uses parquet format, read it back in
    tarchetypes::tar_nanoparquet_read(file_input_data, class = "tbl"),
    format = pax::pax_tar_format_parquet()
  ),

  ## Generate muppet input from data
  tar_target(muppet_input_icehad, "data/icehad.dat.opt", format = "file"),
  tar_target(
    muppet_input_stockparameters,
    "data/stockparameters.dat",
    format = "file"
  ),
  tar_target(
    muppet_input_catchparameters,
    "data/catchparameters.dat",
    format = "file"
  ),
  tar_target(
    muppet_input_likelihoodparameters,
    "data/likelihoodparameters.dat",
    format = "file"
  ),
  tar_target(
    muppet_input_outputparameters,
    "data/outputparameters.dat",
    format = "file"
  ),
  tar_target(
    muppet_input_marsurveypar,
    "data/marsurveypar.dat",
    format = "file"
  ),
  tar_target(
    muppet_input_autsurveypar,
    "data/autsurveypar.dat",
    format = "file"
  ),
  tar_target(
    muppet_input_hadprognosis,
    "data/hadprognosis.dat.opt",
    format = "file"
  ),
  tar_target(
    muppet_input_optim_hockey,
    "data/optim.dat.hockey",
    format = "file"
  ),
  tar_target(
    muppet_input_files,
    c(
      hr_muppet_input_optionfile(
        readLines(muppet_input_icehad),
        "params/icehad.dat.opt",
        year_end,
        # NB: different to normal age_end?
        age_end = 10,
        plus_group = 1
      ),
      hr_muppet_input_datafiles(
        input_data,
        year_start,
        year_end,
        age_end
      ),
      hr_muppet_input_progwts(
        input_data,
        year_end
      ),
      list(
        "Files/likelihoodparameters.dat" = readLines(
          muppet_input_likelihoodparameters
        ),
        "Files/stockparameters.dat" = readLines(muppet_input_stockparameters) |>
          (function(x) {
            x[6] <- rep(0.3, 12) |> paste(collapse = ' ')
            x[7] <- rep(0.4, 12) |> paste(collapse = ' ')
            return(x)
          })(),
        "Files/catchparameters.dat" = readLines(muppet_input_catchparameters),
        "Files/likelihoodparameters.dat" = readLines(
          muppet_input_likelihoodparameters
        ),
        "Files/outputparameters.dat" = readLines(muppet_input_outputparameters),
        "Files/marsurveypar.dat" = readLines(muppet_input_marsurveypar) |>
          rmuppet:::line_replace(
            '0.335784 0.337252 0.273987 0.264007 0.256767 0.345298 0.327136 0.344655 0.345801 0.307099',
            '#pattern in CV with age. Common multiplier estimated'
          ),
        "Files/autsurveypar.dat" = readLines(muppet_input_autsurveypar) |>
          rmuppet:::line_replace(
            '0.392226 0.295314 0.180818 0.179292 0.251839 0.233800 0.383959 0.419390 0.407381',
            '#pattern in CV with age. Common multiplier estimated'
          ),
        "Files/hadprognosis.dat.opt" = readLines(muppet_input_hadprognosis),
        "Files/optim.dat.hockey" = readLines(muppet_input_optim_hockey) |>
          rmuppet:::line_replace(
            '15          5.3        0.1   -0.7    1        1.0',
            '#upper bound changed on acf'
          )
      )
    ),
    format = "rds"
  ),

  ## Size based selection (logit on weight-at-age) tuned with both surveys
  tar_target(
    muppet_output_logit_length,
    hr_muppet_run(
      "logit_length",
      muppet_input_files |>
        (function(x) {
          x[["Files/likelihoodparameters.dat"]] <-
            x[["Files/likelihoodparameters.dat"]] |>
            rmuppet:::line_replace('1\t0.001', '# Weight on surveys.')
          return(x)
        })()
    ),
    format = "rds"
  ),

  ## Size based selection (logit on weight-at-age) tuned with the spring survey
  tar_target(
    muppet_output_smb,
    hr_muppet_run(
      "smb",
      muppet_input_files |>
        (function(x) {
          x[["Files/likelihoodparameters.dat"]] <-
            x[["Files/likelihoodparameters.dat"]] |>
            rmuppet:::line_replace('1\t0.001', '# Weight on surveys.')
          return(x)
        })()
    ),
    format = "rds"
  ),

  ## Size based selection (logit on weight-at-age) tuned with the autumn survey
  tar_target(
    muppet_output_smh,
    hr_muppet_run(
      "smh",
      muppet_input_files |>
        (function(x) {
          x[["Files/likelihoodparameters.dat"]] <-
            x[["Files/likelihoodparameters.dat"]] |>
            rmuppet:::line_replace('0.001\t1', '# Weight on surveys.')
          return(x)
        })()
    ),
    format = "rds"
  ),

  ## no surveys
  tar_target(
    muppet_output_nosurvey,
    hr_muppet_run(
      "nosurvey",
      muppet_input_files |>
        (function(x) {
          x[["Files/likelihoodparameters.dat"]] <-
            x[["Files/likelihoodparameters.dat"]] |>
            rmuppet:::line_replace('0.001\t0.001', '# Weight on surveys.')
          return(x)
        })()
    ),
    format = "rds"
  ),

  ## VPA/backwards calculation
  tar_target(
    muppet_output_vpa,
    hr_muppet_run(
      "vpa",
      muppet_input_files |>
        (function(x) {
          x[["params/icehad.dat.opt"]] <-
            x[["params/icehad.dat.opt"]] |>
            # TODO: Should be 1, but muppet fails
            rmuppet:::line_replace(0, '# 0 Forward, 1 Backward vpa')

          return(x)
        })()
    ),
    format = "rds"
  ),

  ## MCMC
  tar_target(
    muppet_output_mcmc,
    hr_muppet_run(
      "mcmc",
      muppet_input_files |>
        (function(x) {
          return(x)
        })(),
      muppet_args = c('nox', mcmc = 100000, mcsave = 200, 'mcscale')
    ),
    format = "rds"
  ),
  ## Prognosis
  tar_target(
    muppet_input_hadprognosis_biorule_adviceyear,
    "data/hadprognosis.dat.biorule.adviceyear",
    format = "file"
  ),
  tar_target(
    muppet_output_prognosis,
    hr_muppet_run(
      "prognosis",
      muppet_input_files |>
        (function(x) {
          x[["Files/hadprognosis.dat.opt"]] <-
            readLines(muppet_input_hadprognosis_biorule_adviceyear) |>
            rmuppet:::line_replace(0, '# CurrentAssessmentErrmultiplier')

          x[["params/icehad.dat.opt"]] <-
            x[["params/icehad.dat.opt"]] |>
            rmuppet:::line_replace(60, '# Number of simulations years')

          x[["Files/outputparameters.dat"]] <-
            x[["Files/outputparameters.dat"]] |>
            rmuppet:::line_replace(
              1,
              '# 6. Some estimated parametes for example ssb-rec'
            )

          return(x)
        })(),
      muppet_args = c("mceval")
    ),
    format = "rds"
  ),

  ## Advice
  tar_target(
    muppet_output_advice,
    hr_muppet_run(
      "advice",
      muppet_input_files |>
        (function(x) {
          x[["data/hadprognosis.dat.opt"]] <-
            readLines(muppet_input_hadprognosis_biorule_adviceyear) |>
            rmuppet:::line_replace(0, '# CurrentAssessmentErrmultiplier') |>
            rmuppet:::line_replace(tac / 1e3, '# Last TAC') |>
            # TODO: (tac - curr_catch$c/1000)/1e3
            rmuppet:::line_replace(
              (tac - 10) / 1e3,
              '# Tac left Icelandic fishing years'
            ) |>
            rmuppet:::line_replace(ref_points$HR_mgt, '# HarvestRate')

          x[["params/icehad.dat.opt"]] <-
            x[["params/icehad.dat.opt"]] |>
            rmuppet:::line_replace(6, '# Type of relationship') |>
            rmuppet:::line_replace(-1, '# Phase of estimating SSBmax') |>
            rmuppet:::line_replace(5, '# Number of simulations years')

          x[["data/outputparameters.dat"]] <-
            x[["data/outputparameters.dat"]] |>
            rmuppet:::line_replace(
              1,
              '# 6. Some estimated parametes for example ssb-rec'
            )

          return(x)
        })(),
      muppet_args = c("nox")
    ),
    format = "rds"
  ),

  ## Combine back into fit object
  tar_target(
    muppet_fit,
    {
      outputs <- list(
        muppet_output_logit_length,
        muppet_output_smb,
        muppet_output_smh,
        muppet_output_nosurvey,
        muppet_output_vpa,
        muppet_output_prognosis,
        muppet_output_advice
      )
      list(
        rby = do.call(bind_rows, lapply(outputs, function(x) x$rby)),
        rbyage = do.call(
          bind_rows,
          lapply(outputs, function(x) x$rbyage)
        ),
        params = do.call(
          bind_rows,
          lapply(outputs, function(x) x$params)
        ),
        mcmc_results = do.call(
          bind_rows,
          lapply(outputs, function(x) x$mcmc_results)
        )
      )
    },
    format = "rds"
  )
)
