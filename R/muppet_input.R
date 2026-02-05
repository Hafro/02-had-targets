ft_muppet_input_optionfile <- function(
  opt_file,
  out_name,
  year_end,
  age_end = 10,
  plus_group = 1
) {
  out_files <- list()

  opt_file
  out_files[[out_name]] <- opt_file |>
    strsplit("\n") |>
    unlist() |>
    stringr::str_remove('../') |>
    rmuppet:::line_replace(age_end, '# Last model age') |>
    rmuppet:::line_replace(plus_group, '# Plus group') |>
    rmuppet:::line_replace(
      year_end - 1,
      '# Last data year, last year with catch at age data'
    ) |>
    rmuppet:::line_replace(
      year_end - 1,
      '# Last opt year i.e last year before assyear   <=lastdatayear'
    ) |>
    rmuppet:::line_replace(year_end - 1, '# Last year smh') |>
    rmuppet:::line_replace(year_end, '# Last year smb')
  return(out_files)
}
