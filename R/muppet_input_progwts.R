ft_muppet_input_progwts <- function(assessment_input_data, year_end) {
  input_dat <- assessment_input_data |>
    dplyr::filter(year >= year_start, age %in% 1:age_end)

  wm <- input_dat |>
    dplyr::mutate(
      stock_weight = ifelse(stock_weight == 4000, NA, stock_weight),
      yc = year - age
    ) |>
    dplyr::select(yc, year, age, stock_weight) |>
    dplyr::group_by(yc) |>
    dplyr::arrange(age) |>
    dplyr::mutate(w1 = lag(stock_weight)) |>
    dplyr::filter(
      age > 1,
      (year > 1984 & age < 8) | (year > 2013 & age < 10)
    ) |>
    na.omit() |>
    lm(log(stock_weight / w1) ~ log(w1) + as.factor(year - 1), data = _)
  #mgcv::gam(log(stock_weight/w1) ~ s(log(w1),bs='cr') + as.factor(year-1),data = _)

  weight_model <-
    wm |>
    broom::tidy(conf.int = TRUE, parametric = TRUE) |>
    dplyr::mutate(source = 'Stock weights')

  catchw <-
    input_dat |>
    dplyr::filter(year > 1984, stock_weight != catch_weight) |>
    dplyr::mutate(
      stock_weight = ifelse(round(stock_weight) == 4000, NA, stock_weight),
      catch_weight = ifelse(round(catch_weight) == 4000, NA, catch_weight),
      yc = year - age,
      period = ifelse(
        year < 2000,
        '1985-1999',
        ifelse(year > 2012, '2013-2018', '2000-2012')
      )
    ) |>
    lm(log(catch_weight) ~ log(stock_weight), data = _) |>
    broom::tidy(conf.int = TRUE) |>
    dplyr::mutate(source = 'Catch weights') |>
    dplyr::select(source, term, estimate) |>
    tidyr::spread(term, estimate)

  delta_hat <-
    weight_model |>
    dplyr::filter(grepl('year', term)) |>
    dplyr::mutate(
      year = gsub('as.factor(year - 1)', '', term, fixed = TRUE) |>
        as.numeric(),
      period = ifelse(
        year < 2000,
        '1985-1999',
        ifelse(year > 2012, '2013-2018', '2000-2012')
      )
    ) |>
    dplyr::filter(year > year_end - 4) |>
    #dplyr::mutate(delta = exp(conf.high)) |>
    dplyr::mutate(delta = exp(estimate)) |>
    dplyr::summarise(delta_hat = mean(delta)) |>
    (function(x) x$delta_hat)()

  wpar <-
    weight_model |>
    dplyr::filter(term %in% c('(Intercept)', 'log(w1)')) |>
    dplyr::select(source, term, estimate) |>
    tidyr::spread(term, estimate)

  mat_model <-
    input_dat |>
    dplyr::filter(
      year > 2012,
      age %in% 3:14,
      stock_weight > 0,
      !is.na(maturity)
    ) |>
    dplyr::mutate(
      stock_weight = ifelse(round(stock_weight) == 4000, NA, stock_weight),
      catch_weight = ifelse(round(catch_weight) == 4000, NA, catch_weight),
      maturity = ifelse(maturity >= 1, 1, maturity),
      yc = year - age,
      period = ifelse(
        year < 2000,
        '1985-1999',
        ifelse(year > 2012, '2013-2018', '2000-2012')
      )
    ) |>
    glm(
      maturity ~ log(stock_weight),
      data = _,
      family = quasi(variance = "mu(1-mu)", link = "logit")
    )

  pred_dat <-
    input_dat |>
    dplyr::filter(year == local(year_end)) |>
    dplyr::right_join(tibble::tibble(year = year_end, age = 1:14)) |>
    dplyr::mutate(
      stock_weight = tidyr::replace_na(stock_weight, 4000),
      maturity = tidyr::replace_na(maturity, 1),
      catch_weight = exp(
        catchw$`(Intercept)` + catchw$`log(stock_weight)` * log(stock_weight)
      ),
      ssbwts = stock_weight
    )

  for (yr in 0:10) {
    pred_dat <-
      pred_dat |>
      dplyr::bind_rows(
        pred_dat |>
          dplyr::filter(year == (year_end + yr)) |>
          dplyr::select(year, age, w1 = stock_weight) |>
          dplyr::mutate(year = year_end - 1) |>
          modelr::add_predictions(wm) |>
          dplyr::mutate(
            diff = pred + log(delta_hat) - (-0.168),
            stock_weight = lag(exp(diff) * w1),
            stock_weight = ifelse(is.na(stock_weight), w1, stock_weight),
            year = year_end + yr + 1,
            ssbwts = stock_weight,
            catch_weight = exp(
              catchw$`(Intercept)` +
                catchw$`log(stock_weight)` * log(stock_weight)
            )
          ) |>
          modelr::add_predictions(
            mat_model,
            var = 'maturity',
            type = 'response'
          )
      ) |>
      dplyr::select(year, age, catch_weight, stock_weight, maturity, ssbwts)
  }

  out_files <- list()
  out_files[["Files/ProgWts.dat"]] <- pred_dat |>
    dplyr::arrange(year, age) |>
    readr::format_delim(
      col_names = FALSE,
      delim = '\t'
    )
  return(out_files)
}
