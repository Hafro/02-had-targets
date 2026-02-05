ft_populate_pax <- function(
  species,
  year_start,
  year_end,
  sampling_type,
  ices_area_like = "5a%",
  strata = pax::pax_def_strata_list()
) {
  pcon <- pax::pax_connect()

  # Open a connection to upstream hafro DB
  mar <- mar::connect_mar()
  on.exit(DBI::dbDisconnect(mar), add = TRUE, after = TRUE)

  import_defs <- list(
    mar,
    species = species,
    year_start = year_start,
    year_end = year_end
  )

  # Extract required tables, place into pcon
  for (s in strata) {
    pax::pax_import(pcon, pax::pax_def_strata(s))
  }
  pax::pax_import(
    pcon,
    pax::pax_mar_station(
      mar,
      species = species,
      year_start = year_start,
      year_end = year_end,
      sampling_type = sampling_type
    )
  )
  pax::pax_import(pcon, do.call(pax::pax_mar_measurement, import_defs))
  pax::pax_import(pcon, do.call(pax::pax_mar_logbook, import_defs))
  pax::pax_import(
    pcon,
    pax::pax_mar_landings(
      mar,
      species = import_defs$species,
      ices_area_like = ices_area_like,
      year_start = import_defs$year_start,
      year_end = import_defs$year_end
    )
  )
  pax::pax_import(pcon, do.call(pax::pax_mar_sampling, import_defs))
  pax::pax_import(pcon, pax::pax_mar_aldist(mar, species = import_defs$species))
  pax::pax_import(pcon, pax::pax_mar_ldist(mar, species = import_defs$species))
  pax::pax_import(
    pcon,
    pax::pax_mar_lw_coeffs(mar, species = import_defs$species)
  )
  return(pcon)
}
