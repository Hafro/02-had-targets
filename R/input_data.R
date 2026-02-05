ft_input_data_lw <- function(
  pcon,
  sampling_type = 30,
  prediction_length_range = NULL
) {
  lw_dat <- dplyr::tbl(pcon, "station") |>
    dplyr::filter(sampling_type %in% local(sampling_type)) |>
    dplyr::left_join(dplyr::tbl(pcon, "aldist"), by = c('sample_id')) |>
    dplyr::filter(!is.na(length), weight > 0) |>
    dplyr::select(species, length, weight) |>
    dplyr::collect(n = Inf)

  if (!is.null(prediction_length_range)) {
    lw_dat <-
      modelr::add_predictions(
        tibble::tibble(
          species = lw_dat$species[[1]],
          length = prediction_length_range
        ),
        gam::gam(
          weight ~ gam::s(log(length), df = 8),
          family = Gamma(link = log),
          data = lw_dat
        ),
        var = 'weight'
      ) |>
      dplyr::mutate(weight = as.numeric(exp(weight)))
  }
  return(lw_dat)
}

ft_input_data_maturity_key <- function(
  pcon,
  lgroups = seq(0, 200, 5),
  regions = NULL,
  default_region = 'S',
  ignore_years = c(),
  sampling_type = 30
) {
  mat_length <- dplyr::tbl(pcon, "station") |>
    dplyr::filter(sampling_type %in% local(sampling_type)) |>
    dplyr::inner_join(
      dplyr::tbl(pcon, "measurement") |>
        dplyr::filter(
          measurement_type == "OTOL",
          !is.na(age),
          !is.na(maturity_stage)
        ) |>
        dplyr::mutate(mat = ifelse(maturity_stage == 1, 0, 1))
    ) |>
    pax::pax_add_lgroups(lgroups = lgroups) |>
    pax::pax_add_regions(regions = regions, default = default_region) |>
    dplyr::group_by(year, lgroup, age, region) |>
    dplyr::summarise(mat_p = mean(mat))

  mat_model <-
    mat_length |>
    na.omit() |>
    dplyr::filter(!(year %in% local(ignore_years))) |>
    glm(
      mat_p ~ log(lgroup) * region,
      data = _,
      family = quasi(variance = "mu(1-mu)", link = "logit")
    )

  mat_filler <- expand.grid(
    lgroup = lgroups,
    region = (if (is.null(regions)) 'all' else names(regions))
  ) |>
    dplyr::filter(lgroup > 0) |>
    modelr::add_predictions(mat_model, type = 'response', var = 'mat_p')

  # Combine measurements & estimates, with year/age = NA signifying the estimates
  return(dplyr::union_all(
    mat_length |> dplyr::collect(),
    mat_filler |> dplyr::mutate(year = NA, age = NA)
  ))
}

## Generate the ALK from the survey
ft_input_data_si_index <- function(
  pcon,
  lw_key = NULL,
  maturity_key = NULL,
  strata_name = NULL,
  sampling_type = 30,
  tow_number = 0:35,
  tgroup = NULL,
  regions = list(all = 101:115),
  lgroups = seq(0, 200, 5),
  gear_group = list(
    Other = 'Var',
    BMT = c('BMT', 'NPT', 'SHT', 'PGT'),
    LLN = 'LLN',
    DSE = c('PSE', 'DSE')
  ),
  gear_id_filter = NULL,
  scale_by_landings = FALSE
) {
  ldist <- dplyr::tbl(pcon, "ldist")
  if (!is.null(lw_key)) {
    ldist <- dplyr::left_join(
      ldist,
      pax::pax_temptbl(pcon, lw_key),
      by = c("species", 'length')
    )
  } else {
    ldist <- pax::pax_ldist_add_weight(ldist)
  }

  alk <- dplyr::tbl(pcon, "station") |>
    dplyr::filter(
      sampling_type %in% local(sampling_type),
      coalesce(tow_number, 0) %in% local(tow_number),
      local(is.null(gear_id_filter)) | (gear_id %in% local(gear_id_filter))
    ) |>
    pax::pax_ldist_alk(
      lgroups = lgroups,
      tgroup = tgroup,
      regions = regions,
      gear_group = gear_group
    )

  at_age <- dplyr::tbl(pcon, "station") |>
    dplyr::filter(
      sampling_type %in% local(sampling_type),
      coalesce(tow_number, 0) %in% local(tow_number)
    ) |>
    pax::pax_si_by_length(ldist = ldist)
  if (!is.null(strata_name)) {
    at_age <- pax::pax_si_scale_by_strata(at_age, strata_name)
  }
  if (!is.null(alk)) {
    at_age <- pax::pax_si_scale_by_alk(
      at_age,
      lgroups = lgroups,
      tgroup = tgroup,
      regions = regions,
      gear_group = gear_group,
      alk = alk
    )
  }
  if (isTRUE(scale_by_landings)) {
    at_age <- pax::pax_si_scale_by_landings(
      at_age,
      tgroup = tgroup,
      regions = regions,
      gear_group = gear_group
    )
  }

  if (!is.null(maturity_key)) {
    # Break apart measurements & filler, join both separately
    mat_measurements <- maturity_key |> dplyr::filter(!is.na(year))
    mat_filler <- maturity_key |>
      dplyr::filter(is.na(year)) |>
      dplyr::select(-year, -age) |>
      dplyr::rename(mat_p_est = mat_p)
    at_age <- at_age |>
      dplyr::left_join(
        pax::pax_temptbl(pcon, mat_measurements),
        by = c("year", "lgroup", "age", "region")
      ) |>
      dplyr::left_join(
        pax::pax_temptbl(pcon, mat_filler),
        by = c("lgroup", "region")
      )

    mat_c <- quote(sum(si_abund * coalesce(mat_p, mat_p_est)) / sum(si_abund))
  } else {
    mat_c <- NA
  }

  out <- at_age |>
    dplyr::group_by(year, age) |>
    dplyr::summarise(
      n = sum(si_abund) / 1000,
      mw = 1000 * sum(si_biomass) / sum(si_abund),
      mat = {{ mat_c }}
    )
  return(out)
}

ft_input_data_landings <- function(pcon) {
  dplyr::tbl(pcon, "landings") |>
    dplyr::group_by(year) |>
    dplyr::summarize(catch = sum(catch))
}
