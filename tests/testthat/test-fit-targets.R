# Tests for R/14_fit_targets.R (the fit-first deliverable). Validate attainability
# (seller pool only), verb obedience (no buy lists for reassess / seller / hold),
# and that every shortlisted player cleared the R/13 eligibility screen.
# Reads output/fit_targets.csv, so R/14 must have run first.

test_that("fit_targets.csv exists and every candidate is from a seller team", {
  f <- proj_path("output", "fit_targets.csv")
  expect_true(file.exists(f))
  ft <- readr::read_csv(f, show_col_types = FALSE)
  expect_gt(nrow(ft), 0)

  sellers <- readr::read_csv(proj_path("output", "standing.csv"), show_col_types = FALSE) %>%
    dplyr::filter(window == "seller") %>% dplyr::pull(team)
  expect_true(all(ft$current_team %in% sellers))
})

test_that("no buy-side target list is produced for reassess, seller, or hold teams", {
  ft <- readr::read_csv(proj_path("output", "fit_targets.csv"), show_col_types = FALSE)
  # only amplify / gap-fill / buy-judgment / adjust actions may carry rows
  expect_true(all(ft$action %in% c("amplify", "gap-fill", "buy-judgment", "adjust")))
  # concretely, the reassess buyer (LVA) and any seller must not appear
  expect_false("LVA" %in% ft$team)
  sellers <- readr::read_csv(proj_path("output", "standing.csv"), show_col_types = FALSE) %>%
    dplyr::filter(window == "seller") %>% dplyr::pull(team)
  expect_length(intersect(ft$team, sellers), 0)
})

test_that("every shortlisted candidate cleared the R/13 eligibility screen", {
  ft <- readr::read_csv(proj_path("output", "fit_targets.csv"), show_col_types = FALSE)
  elig <- readr::read_csv(proj_path("output", "player_value.csv"), show_col_types = FALSE) %>%
    dplyr::filter(eligible) %>% dplyr::pull(personId)
  expect_true(all(ft$personId %in% elig))
})
