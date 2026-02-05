ft_input_data_had <- function(
  year_start,
  year_end,
  input_data_comm_index,
  input_data_igfs_index,
  input_data_agfs_index,
  input_data_landings
) {
  tidyr::expand_grid(
    year = year_start:year_end,
    age = 0:max(input_data_comm_index$age)
  ) |>
    dplyr::full_join(input_data_comm_index) |>
    dplyr::rename(catch = n, catch_weight = mw) |>
    dplyr::full_join(
      input_data_igfs_index |>
        dplyr::rename(smb = n, stock_weight = mw, maturity = mat),
      by = c('year', 'age')
    ) |>
    dplyr::full_join(
      input_data_agfs_index |> dplyr::select(year, age, smh = n),
      by = c('year', 'age')
    ) |>
    dplyr::left_join(
      input_data_landings |> dplyr::rename(lnd = catch),
      by = c('year')
    ) |>
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
    dplyr::group_by(year) |>
    dplyr::mutate(
      catch = catch * lnd / sum(catch * catch_weight, na.rm = TRUE),
      stock_weight = ifelse(
        is.na(stock_weight) & year < 1985,
        ws,
        stock_weight
      ),
      maturity = ifelse(is.na(maturity), ms, maturity)
    ) |>
    dplyr::mutate(
      catch_weight = tidyr::replace_na(catch_weight, 4000),
      stock_weight = tidyr::replace_na(stock_weight, 4000),
      catch = tidyr::replace_na(catch, 0)
    ) |>
    dplyr::select(-c(lnd, ms, ws)) |>
    dplyr::arrange(year, age) |>
    dplyr::mutate(M = 0.2)
}
