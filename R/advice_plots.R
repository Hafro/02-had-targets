ft_advice_plot_landings <- function(
  advice_table_landings,
  year_end,
  lang = "en"
) {
  gear.land <-
    advice_table_landings |>
    dplyr::mutate(gear = ifelse(is.na(gear), 'Other', gear)) |>
    dplyr::group_by(year, gear) |>
    dplyr::summarise(tonnes = sum(landings) / 1e6) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      gear.is = ordered(
        forcats::fct_recode(
          gear,
          'Lína' = 'LLN',
          'Botnvarpa' = 'BMT',
          'Dragnót' = 'DSE',
          'Annað~og~óskilgreint' = 'Other'
        ),
        levels = c('Annað~og~óskilgreint', 'Dragnót', 'Lína', 'Botnvarpa')
      ),
      gear.en = ordered(
        gear.is,
        labels = c(
          'Other~and~undefined~gear',
          'Demersal~seine',
          'Longline',
          'Bottom~trawl'
        )
      ),
      gear = ordered(
        gear.is,
        labels = sprintf("%s~italic('%s')", levels(gear.is), levels(gear.en))
      )
    ) |>
    dplyr::arrange(desc(gear.is))

  gear.land |>
    ggplot2::ggplot(ggplot2::aes(
      year,
      tonnes,
      fill = sprintf(
        'bold(%s)',
        eval(ggplot2::sym(paste('gear', lang, sep = '.')))
      )
    )) +
    ggiraph::geom_bar_interactive(
      stat = 'identity',
      ggplot2::aes(
        tooltip = paste(
          eval(ggplot2::sym(paste('gear', lang, sep = '.'))),
          ':',
          round(1e3 * tonnes),
          't',
          '\n',
          if (lang == 'is') 'Ár' else 'Year',
          ':',
          year
        ),
        data_id = gear.is
      )
    ) +
    ggplot2::scale_fill_manual(
      values = c('black', 'steelblue3', "navajowhite3", 'tomato3'),
      labels = scales::parse_format(),
      guide = ggplot2::guide_legend(label.position = 'right')
    ) +
    ggplot2::labs(
      y = tidypax::tonnes_y_title(lang),
      title = tidypax::catch_title(lang)
    ) +
    ggplot2::scale_y_continuous(
      breaks = seq(0, 160, 20),
      expand = c(0, 0),
      limits = c(0, 120)
    ) +
    tidypax::astand.theme(legend.position = c(0.35, 0.85)) +
    tidypax::astand.x.scale(5, 0, limits = c(1978, year_end - 0.5))
}
