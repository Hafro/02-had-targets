# Write (fl), a list of file path->plain-text contents to (workdir)
write_file_list <- function(fl, workdir) {
  for (f_name in names(fl)) {
    f_path <- file.path(workdir, f_name)
    dir.create(dirname(f_path), showWarnings = FALSE, recursive = TRUE)
    writeLines(fl[[f_name]], con = f_path)
  }
  return(workdir)
}

ft_muppet_run <- function(
  model_name,
  muppet_input_files,
  clear_on_exit = TRUE,
  md = file.path(
    tempdir(),
    paste0("muppet-run-", digest::digest(muppet_input_files, algo = "xxh3_64"))
  ),
  muppet_args = c('nox')
) {
  write_file_list(muppet_input_files, md)
  if (isTRUE(clear_on_exit)) {
    on.exit(unlink(md, recursive = TRUE), add = TRUE)
  }

  ind <- grep(
    '^params/.*\\.dat\\.opt$',
    names(muppet_input_files),
    value = TRUE
  )
  if (length(ind) != 1) {
    stop("Zero (or multiple) option files found at params/*.dat.opt")
  }
  res <- withr::with_dir(md, rmuppet::callMuppet(c(ind = ind, muppet_args)))
  if (!is.null(attr(res, "status"))) {
    writeLines(res)
    stop("rmuppet failed, returning status ", attr(res, "status"))
  }

  read_output <- function(path) {
    readr::read_table2(path) |>
      dplyr::mutate_all(function(x) ifelse(x == -1, NA, x)) |>
      dplyr::mutate(model = local(model_name))
  }

  fit <- list()
  if (file.exists(file.path(md, "resultsbyyear.out"))) {
    fit$rby <- read_output(file.path(md, "resultsbyyear.out"))
  }
  if (file.exists(file.path(md, "resultsbyyearandage.out"))) {
    fit$rbyage <- read_output(file.path(md, "resultsbyyearandage.out")) |>
      dplyr::mutate(CalcCno = ifelse(model_name == 'vpa', NA, CalcCno))
  }
  if (file.exists(file.path(md, "muppet.std"))) {
    fit$params <- read_output(file.path(md, "muppet.std")) |>
      dplyr::mutate(
        value = ifelse(
          grepl('ln|log|estSSBRecParameters', name),
          exp(value),
          value
        ),
        variable = gsub('ln|log', '', name) |>
          gsub('([a-zA-Z]+)\\[([0-9])\\]', '\\1.\\2', x = _),
        variable = ifelse(
          grepl('estSSBRecParameters', variable),
          forcats::fct_recode(
            gsub('estSSBRecParameters.', '', variable, fixed = TRUE),
            Rmax = "1",
            ssbbreak = "2",
            `Recruitment CV` = '3',
            rho = '4'
          ) |>
            as.character(),
          variable
        )
      )
  }

  return(fit)
}
