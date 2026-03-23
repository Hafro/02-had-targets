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

basis_table <- dplyr::bind_rows(
  c(
    id.is = 'Forsendur ráðgjafar',
    id.en = 'Basis of the advice',
    desc.is = 'Aflaregla',
    desc.en = 'Management plan'
  ),
  c(
    id.is = 'Aflaregla',
    id.en = 'Management plan',
    desc.is = 'Aflamark sett sem 35 % af viðmiðunarstofni (lífmassi 45 cm og stærri ýsu) á stofnmatsári',
    desc.en = 'TAC set as 35% of reference biomass (biomass of 45 cm and larger) in the assessment year'
  ),
  c(
    id.is = 'Stofnmat',
    id.en = 'Assessment type',
    desc.is = 'Tölfræðilegt aldurs-aflalíkan',
    desc.en = 'Statistical catch at age model'
  ),
  c(
    id.is = 'Inntaksgögn',
    id.en = 'Input data',
    desc.is = 'Aldursgreindur afli og aldursgreindar fjöldavísitölur úr stofnmælingum (SMB, SMH)',
    desc.en = 'Catch in numbers and age disaggregated indices (IS-SMB, IS-SMH)'
  )
)

ref_points_basis_table <- dplyr::bind_rows(
  c(
    render = 'MGT B~trigger~',
    approach.is = 'Aflaregla',
    approach.en = 'Management plan',
    ref_point = 'MGT_btrigger',
    basis.is = 'Aflaregla',
    basis.en = 'From the management plan'
  ),
  c(
    render = 'HR~MGT~',
    approach.is = 'Aflaregla',
    approach.en = 'Management plan',
    ref_point = 'HR_mgt',
    basis.is = 'Aflaregla',
    basis.en = 'From the management plan'
  ),
  c(
    render = 'HR~MSY~',
    approach.is = 'Hámarksafrakstur',
    approach.en = 'MSY approach',
    ref_point = 'HR_msy',
    basis.is = 'HR~pa~',
    basis.en = 'HR~pa~'
  ),
  c(
    render = 'MSY B~trigger~',
    approach.is = 'Hámarksafrakstur',
    approach.en = 'MSY approach',
    ref_point = 'MSY_btrigger',
    basis.is = 'B~pa~',
    basis.en = 'B~pa~'
  ),
  c(
    render = 'B~lim~',
    approach.is = 'Varúðarnálgun',
    approach.en = 'Precautionary approach',
    ref_point = 'B_lim',
    basis.is = 'B~loss~',
    basis.en = 'B~loss~'
  ),
  c(
    render = 'B~pa~',
    approach.is = 'Varúðarnálgun',
    approach.en = 'Precautionary approach',
    ref_point = 'B_pa',
    basis.is = 'B~lim~ x e^1.645 * 0.2^',
    basis.en = 'B~lim~ x e^1.645 * 0.2^'
  ),
  c(
    render = 'HR~pa~',
    approach.is = 'Varúðarnálgun',
    approach.en = 'Precautionary approach',
    ref_point = 'HR_pa',
    basis.is = 'Veiðihlutfall sem leiðir til P(SSB > B~lim~) = 95 % með B~trigger~',
    basis.en = 'HR leading to P(SSB > B~lim~) = 95 % with B~trigger~'
  )
)
