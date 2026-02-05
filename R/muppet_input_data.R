ft_muppet_input_datafiles <- function(
  assessment_input_data,
  year_start,
  year_end,
  age_end,
  age_start = 1
) {
  out_files <- list()

  prepend_header <- function(x, head) paste(head, x, sep = "\n")

  dat <- assessment_input_data |>
    dplyr::filter(year >= year_start, age %in% 1:age_end) |>
    dplyr::full_join(tidyr::expand_grid(
      year = year_start:year_end,
      age = 1:age_end
    )) |>
    dplyr::left_join(tibble::tibble(
      age = 1:14,
      ws = c(
        37,
        185,
        481,
        910,
        1409,
        1968,
        2496,
        3077,
        3300,
        4000,
        5741,
        6171,
        4000,
        5213
      )
    )) |>
    dplyr::left_join(tibble::tibble(
      age = 1:14,
      ms = c(
        0,
        0.08,
        0.301,
        0.539,
        0.722,
        0.821,
        0.868,
        0.904,
        0.963,
        1,
        1,
        1,
        1,
        1
      )
    )) |>
    dplyr::mutate(
      catch = tidyr::replace_na(catch, 0),
      catch_weight = dplyr::case_when(
        age == 1 ~ -1,
        is.na(catch_weight) & age > 2 ~ 4000,
        (is.na(catch_weight) | catch_weight >= 4000) & age == 2 ~ 600,
        TRUE ~ catch_weight
      ),
      stock_weight = ifelse(is.na(stock_weight), ws, stock_weight),
      maturity = ifelse(is.na(maturity), ms, maturity)
    ) |>
    dplyr::arrange(year, age) |>
    dplyr::mutate(across(everything(), ~ tidyr::replace_na(.x, -1))) # TODO: ?

  out_files[['Files/catchandstockdata.dat']] <- dat |>
    dplyr::mutate(ssbwt = stock_weight) |>
    dplyr::select(
      year,
      age,
      cno = catch,
      cwt = catch_weight,
      swt = stock_weight,
      mat = maturity,
      ssbwt
    ) |>
    dplyr::mutate(
      cno = ifelse(year == local(year_end) | age == 1, -1, cno),
      cwt = ifelse(year == local(year_end) | age == 1, -1, cwt)
    ) |>
    readr::format_delim(
      col_names = FALSE,
      delim = '\t'
    ) |>
    prepend_header("# year age cno cwt swt mat ssbwt")

  out_files[['Files/totcatch.dat']] <- dat |>
    dplyr::group_by(year) |>
    dplyr::filter(year < local(year_end), catch > 0) |>
    dplyr::summarise(landings = round(sum(catch * catch_weight))) |>
    readr::format_delim(
      col_names = FALSE,
      delim = '\t'
    ) # TODO: Should we be strsplitting, or not combining in the first place?

  out_files[['Files/marsurveydata.dat']] <- dat |>
    dplyr::select(year, age, smb) |>
    dplyr::mutate(smb = round(smb, 3), smb = ifelse(smb == -1, 0, smb)) |>
    dplyr::filter(year > 1984, age %in% 1:13) |>
    readr::format_delim(
      col_names = FALSE,
      delim = '\t'
    )

  out_files[["Files/autsurveydata.dat"]] <- dat |>
    dplyr::select(year, age, smh) |>
    dplyr::mutate(smh = round(smh, 3), smh = ifelse(smh == -1, 0, smh)) |>
    dplyr::filter(year > 1995, age %in% 1:13) |>
    dplyr::mutate(smh = ifelse(year == 2011, -1, smh)) |>
    readr::format_delim(
      col_names = FALSE,
      delim = '\t'
    )

  return(out_files)
}
