# Lessons from porting the saithe assessment (03-sai) to this layout

The saithe assessment has been moved to the same targets layout as this repository (Hafro/03-sai), and now reproduces the published 2026 saithe assessment: TAC 49,900 t vs 49,887 t, with SSB, B4+ and HR within 0.1%. To get there, several things in this template and in `hafroreports`/`pax` had to be changed. Most are haddock-specific defaults, but some look like they also affect the haddock assessment. They are listed here while the details are fresh.

Each item gives what went wrong, whether it applies to haddock, and what 03-sai does now. For the details, see the "Choices" and "Known issues" sections of the 03-sai README.

## Likely to affect haddock

### 1. The tow filter drops commercial samples

`hr_input_data_si_index()` has `tow_number = 0:35` as its default and applies it to every sampling type. For survey stations that is the standard tow list. For commercial samples (sampling types 1, 2, 8) `tow_number` is the haul number, which can be above 35, so those samples are silently dropped from both the age-length key and the length distributions.

* **Saithe:** 8–14% of commercial samples were dropped in 2016–2021. That shifted the catch at age towards older fish, with age 3 down 28% in 2020 and ages 8+ up 10–15%.
* **Haddock** (`pax_db` in this repo, samples containing haddock):

  | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | 4.2% | 2.6% | 8.2% | 5.6% | 6.9% | 3.5% | 0% | 3.1% | 6.0% | 8.3% | 11.5% |

  Before 2016 almost no samples are affected. The `input_data_comm_index` target in `script_assessment_model.R` doesn't set `tow_number`, so it uses this default.
* **Suggested fix:** don't filter commercial samples by tow number. In 03-sai, `tow_number = NULL` means no filter (`sai_input_data_si_index()`, `R/input_data.R`).

### 2. The reference point table shows biomass in thousand tonnes

`config.R` stores biomass reference points in kt (`MGT_btrigger = 64.4`, `B_lim = 46`) because the advice figures plot biomass in kt. `hr_advice_ref_table()` then shows the values rounded as they are, so the advice sheet lists **64** and **46** instead of 64 400 and 46 000 t.

* **Saithe fix:** `sai_ref_points_tonnes()` converts the biomass reference points to tonnes for the table only.

### 3. The reference biomass is missing from the biomass legend

`hr_advice_plot_ssb()` keys its colours by `hr_label("ref biomass")`. That key isn't in `hr_locale`, so it returns the text "ref biomass", which doesn't match the data's labels ("Reference biomass" / "Viðmiðunarstofn"). The reference biomass is then drawn in the NA grey and left out of the legend. This happens for haddock too.

### 4. The reports don't rebuild when the assessment changes

The report and advice pipelines load results from `_assessment_model` with `tar_load(..., store = ...)`. targets doesn't track dependencies across stores, so after a new fit `run.R` skips the reports and they keep showing the old results.

* **03-sai fix:** each report script lists the assessment result files its documents load and passes them to `tar_quarto(extra_files = ...)`. When a result changes, the reports rebuild; otherwise everything is skipped. This could be copied here directly.

### 5. Landings with no month are left out of the landings scaling

`pax_si_scale_by_landings()` gives landings with a missing month no half-year, so they aren't used when raising the samples within each cell. For saithe, 2–10% of landings before 2000 have no month or gear. The old `tidypax` code assumed month 6 and bottom trawl. For haddock this would only matter in early years, so it's worth checking how much of the landings lack a month or gear.

### 6. Survey strata are assigned from tow positions

`pax_si_scale_by_strata()` assigns each tow to a stratum from the h3 cell of its first position. The old `tidypax` index used the fixed station list (`biota.strata_stations`). About 48 spring survey stations a year fall in a different stratum under the two methods.

* **Saithe:** the spring survey index moved by −47% to +64% in some years, because single large hauls near a stratum boundary changed stratum.
* **Haddock** (spring survey, all ages): median ratio 0.994, range 0.94–1.06 (1992 −6%, 2007 −6%, 2009 +6%). So it's small for haddock, but it isn't the same index as before.
* **Saithe fix:** assign strata from the station list (`sai_si_scale_by_strata_stations()`). Choosing between the two methods is a methods decision, not necessarily a bug.

## Hard-coded haddock values, worth making arguments

* **Advice figures:** `hr_advice_plot_landings()`, `_recruitment()`, `_fpl()` and `_ssb()` have fixed axis limits (catch ≤ 120 kt, recruitment ≤ 600, HR 0–1, biomass ≤ 275 kt). The recruitment plot also has a fixed title and unit ("age 1", "million tonnes"; recruitment is numbers, so "millions" is probably meant for haddock too). The gear groups (`hr_advice_data_landings()`: bottom trawl, longline, Danish seine, other) and the four fill colours are fixed as well. 03-sai wraps these functions and replaces the scales, which works because a new ggplot scale replaces the old one.
* **Before-spawning proportions:** `hr_sam_pf()` and `hr_sam_pm()` hard-code 0.4 and 0.3. This lowered saithe SSB by about 14%, because the saithe benchmark uses 0. It's worth confirming 0.4/0.3 is the intended haddock setting and documenting where it comes from.
* **Model setup:** `hr_sam_conf()`, `hr_sam_smh()` (the 2011 exclusion, ages ≤ 10) and `hr_input_data_combine()` (the fill-in weights and maturity) are haddock-specific. That's fine, but the names suggest they are general.
* **Maturity key:** `hr_input_data_maturity_key()` fits `mat_p ~ log(lgroup) * region`, which fails with a single region (a `contrasts` error).

## Smaller issues

* **ICES SAG download:** `hr_assessment_from_sag()` joins the summary table to the custom columns on every column they share. The 2025 saithe submission has a custom column named `F`, which then joins on F as well and loses the reference biomass for most years. Joining on `Year` only avoids this. 03-sai now builds the assessment history from the SAM fit instead of downloading it from SAG.
* **SAMutils:** `input_data_plot()` calls `pivot_longer()` without `tidyr::`, so it fails unless tidyr is attached.
* **SAMutils:** `model_ices_plot()` and `model_retro_plot()` only support the length-based reference biomass.
* **Year convention:** `config.R` uses `assessment_year <- year_end - 1`. For saithe, which is assessed in spring with that spring's survey, the current year is used. If haddock uses `- 1` only to reproduce the 2025 run, it's worth a comment in `config.R`.
