# _targets.R file
library(targets)
library(tarchetypes)

tar_source("config.R")
tar_source() # Source R/*.R

# TODO: Seems a bit naff, but somewhat standard
dir.create("figs", showWarnings = FALSE, recursive = TRUE)

list(
  # Open database from assessment_model
  tar_target(
    pax_db,
    pax::pax_connect("_assessment_model/objects/pax_db", read_only = TRUE),
    format = pax::pax_tar_format_duckdb()
  ),

  tar_target(
    table_nb_lnd_by_yr,
    ft_nb_lnd_by_yr(pax_db),
    format = pax::pax_tar_format_parquet()
  ),

  tar_target(
    fig_catch_dist_plot,
    ft_catch_dist_plot(pax_db, year_start = 1989),
    format = "rds"
  ),

  tar_target(
    fig_catchdistplot_selectyrs,
    c(2001, 2005, 2010, 2015, year_end - 1)
  ),

  ## Technical reports
  tar_quarto(
    techreport_en,
    path = "techreport_en.qmd",
    execute_params = list(
      year_end = year_end
    ),
    quiet = FALSE
  ),
  tar_quarto(
    techreport_is,
    path = "techreport_is.qmd",
    execute_params = list(
      year_end = year_end
    ),
    quiet = FALSE
  )
)
