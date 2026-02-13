ft_nb_lnd_by_yr <- function(
  pcon,
  year_end
) {
  dplyr::tbl(pcon, "landings") |>
    pax::pax_landings_by_gear() |>
    dplyr::ungroup() |>
    dplyr::filter(
      gear_name %in% c('BMT', 'DSE', 'LLN', 'Other'),
      catch > 0,
      country == 'Iceland'
    ) |>
    dplyr::mutate(catch = round(catch / 1e3)) |>
    pax::pax_landings_boat_summary()
}

ft_catch_dist_plot <- function(
  pcon,
  year_start = max(year_start, year_end - 22)
) {
  logbook_tbl <- dplyr::tbl(pcon, "logbook") |>
    dplyr::filter(year > local(year_start)) |>
    dplyr::group_by(year, lat, lon) |>
    dplyr::summarise(
      catch = sum(1e-3 * catch / tow_area, na.rm = TRUE),
      tow_time = sum(tow_time / tow_area, na.rm = TRUE)
    ) |>
    dplyr::ungroup()

  pax::pax_map_base() |>
    pax::pax_map_layer_depth(dplyr::tbl(pcon, "ocean_depth")) |>
    pax::pax_map_layer_catch(
      logbook_tbl |> dplyr::collect(n = Inf),
      alpha = 1,
      na.fill = -50,
      breaks = c(0, 1, 2, seq(3, 20, by = 3), 40, 60)
    )
}
