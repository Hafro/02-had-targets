# _targets.R file
library(targets)
library(tarchetypes)

tar_source() # Source R/*.R

species <- 2
year_start <- 1979
year_end <- lubridate::year(Sys.Date())
age_end <- 14

tar_option_set(
  packages = c(),
)

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
    ft_catch_dist_plot(pax_db, year_start = 1989) |>
      ggplot2::ggsave(
        filename = "figs/catch_dist_plot.jpg",
        width = 10,
        height = 15,
        units = 'in',
        dpi = 300
      ),
    format = "file"
  )
)
