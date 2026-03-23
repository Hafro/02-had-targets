species <- 2
year_start <- 1979
year_end <- lubridate::year(Sys.Date())
assessment_year <- year_end - 1
age_end <- 14

publication_date <- "2024-06-07"
tac <- 76774
# TODO: This is TAC in scripts_assessment_model()
tac_last_year <- 76415

ices_stock_key_label <- "had.27.5a"
ices_median_refbio <- "B45cm+"

ref_points <- list(
  MGT_btrigger = 64.4,
  MSY_btrigger = 64.4,
  HR_msy = 0.35,
  F_msy = 0.45,
  B_lim = 46,
  B_pa = 64.4,
  #HR_lim = NA_real_,
  F_lim = NA_real_,
  F_pa = 0.45,
  HR_pa = 0.35,
  HR_mgt = 0.35,
  #HR_mgt_upper = 0.57,
  #HR_mgt_lower = 0.23,
  F_mgt = NA,
  F_mgt_upper = NA,
  F_mgt_lower = NA
)
