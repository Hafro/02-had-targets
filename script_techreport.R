# _targets.R file
library(pax)
library(targets)
library(tarchetypes)

tar_option_set(
  packages <- c(
    'hafroreports',
    'pax',
    'tidyverse'
  ),
  tidy_eval = TRUE
)

tar_source("config.R")
tar_source() # Source R/*.R

list(
  ## Technical reports
  tar_quarto(
    techreport_en,
    path = "techreport_en.qmd",
    quiet = FALSE
  ),
  tar_quarto(
    techreport_is,
    path = "techreport_is.qmd",
    quiet = FALSE
  )
)
