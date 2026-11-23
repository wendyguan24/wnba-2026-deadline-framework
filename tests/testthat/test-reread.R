# Tests: full-season re-read of v1 (R/05 to R/07 windows, R/15_reread.R).
# Skipped when the window outputs or analysis tables are absent.

library(testthat)

reread_dir <- file.path(OUTPUT_DIR, "reread")
fh_dir <- file.path(reread_dir, "first_half")
v1_files <- c("icc_table.csv", "team_generation_making.csv", "team_trajectories.csv",
              "trajectory_league_trends.csv", "team_rank_deltas.csv")
v1_keys <- list(icc_table.csv = "metric", team_generation_making.csv = "team",
                team_trajectories.csv = c("metric", "team"),
                trajectory_league_trends.csv = "metric",
                team_rank_deltas.csv = c("metric", "team"))

test_that("first_half window reproduces the committed v1 outputs within 1e-6", {
  skip_if_not(all(file.exists(file.path(fh_dir, v1_files))), "first_half window outputs absent")
  skip_if_not(all(file.exists(file.path(PROJECT_ROOT, "output", v1_files))), "v1 outputs absent")
  for (f in v1_files) {
    v1 <- readr::read_csv(file.path(PROJECT_ROOT, "output", f), show_col_types = FALSE)
    fh <- readr::read_csv(file.path(fh_dir, f), show_col_types = FALSE)
    expect_equal(nrow(fh), nrow(v1), info = f)
    m <- dplyr::inner_join(v1, fh, by = v1_keys[[f]], suffix = c(".v1", ".fh"))
    expect_equal(nrow(m), nrow(v1), info = f)
    for (cn in setdiff(names(v1), v1_keys[[f]])) {
      a <- m[[paste0(cn, ".v1")]]; b <- m[[paste0(cn, ".fh")]]
      if (is.numeric(a)) expect_lte(max(abs(a - b), na.rm = TRUE), 1e-6, label = paste(f, cn))
      else expect_identical(a, b, info = paste(f, cn))
    }
  }
})

test_that("scorecard has 15 teams and valid verdicts", {
  path <- file.path(reread_dir, "scorecard.csv")
  skip_if_not(file.exists(path), "scorecard not built")
  sc <- readr::read_csv(path, show_col_types = FALSE)
  expect_equal(nrow(sc), 15)
  expect_false(anyDuplicated(sc$team) > 0)
  expect_true(all(sc$verdict %in% c("held", "partly held", "failed")))
  expect_true(all(sc$trajectory_outcome %in% c("agree", "disagree", "tie")))
  expect_type(sc$boundary_sensitive, "logical")
  expect_true(all(c("v1_generation_pctile", "sh_generation_pctile", "generation_pctile_change",
                    "v1_making_pctile", "sh_making_pctile", "making_pctile_change",
                    "boundary_sensitive", "verdicts_possible", "roster_turnover_flag") %in% names(sc)))
  # the reported verdict is always one of the verdicts reachable under one-rank swaps
  expect_true(all(purrr::map2_lgl(sc$verdict, sc$verdicts_possible, ~ .x %in% strsplit(.y, " \\| ")[[1]])))
  # a team not adjacent to any boundary has exactly one possible verdict
  expect_true(all(lengths(strsplit(sc$verdicts_possible[!sc$boundary_sensitive], " \\| ")) == 1))
  # verdict rule: tier step sizes
  step <- abs(sc$sh_generation_tier - sc$v1_generation_tier) + abs(sc$sh_making_tier - sc$v1_making_tier)
  expect_true(all(sc$verdict[step == 0] == "held"))
  expect_false(any(step > 0 & sc$verdict == "held"))
  expect_true(all(sc$verdict[step == 1] == "partly held"))
})

test_that("analysis windows partition the regular season", {
  skip_if_not(file.exists(file.path(PROCESSED_DIR, "tables", "games.parquet")), "tables not built")
  source(file.path(PROJECT_ROOT, "R", "load_tables.R"), local = TRUE)
  games <- load_table("games", "all")
  fh <- window_game_ids(games, "first_half")
  sh <- window_game_ids(games, "second_half")
  full <- window_game_ids(games, "full")
  po <- window_game_ids(games, "playoffs")
  expect_equal(length(fh), 182)
  expect_equal(length(sh), 148)
  expect_equal(length(full), 330)
  expect_equal(sort(c(fh, sh)), full)
  expect_length(intersect(fh, sh), 0)
  expect_equal(length(po), 23)
  expect_length(intersect(full, po), 0)
})

test_that("advice outcome table has 15 teams and valid values", {
  path <- file.path(reread_dir, "advice_outcome.csv")
  skip_if_not(file.exists(path), "advice outcome not built")
  adv <- readr::read_csv(path, show_col_types = FALSE)
  expect_equal(nrow(adv), 15)
  expect_false(anyDuplicated(adv$team) > 0)
  expect_true(all(adv$advice_outcome %in% c("right", "wrong", "not scored")))
  expect_true(all(adv$v1_window %in% c("buyer", "bubble", "seller")))
  expect_true(all(adv$deadline_action %in% c("bought", "sold", "stood pat")))
  # roster-turnover-flagged teams are not scored; every other team is
  expect_true(all(adv$advice_outcome[adv$roster_turnover_flag] == "not scored"))
  expect_false(any(adv$advice_outcome[!adv$roster_turnover_flag] == "not scored"))
})

test_that("sensitivity, decomposition and paired LOO files exist with expected shape", {
  sens_path <- file.path(reread_dir, "sensitivity_full_baseline.csv")
  skip_if_not(file.exists(sens_path), "sensitivity file not built")
  sens <- readr::read_csv(sens_path, show_col_types = FALSE)
  expect_setequal(unique(sens$baseline), c("own_window (main)", "full_window"))
  expect_equal(nrow(sens), 4)
  main <- readr::read_csv(file.path(reread_dir, "hr2_generation_vs_making.csv"), show_col_types = FALSE)
  m <- sens[sens$baseline == "own_window (main)", ]
  expect_equal(m$rho_generation, main$rho_generation, tolerance = 1e-12)
  dec <- readr::read_csv(file.path(reread_dir, "hr2_decomposition.csv"), show_col_types = FALSE)
  expect_setequal(unique(dec$measure), c("diet", "volume", "generation", "making"))
  expect_true(all(dec$ci_low <= dec$rho & dec$rho <= dec$ci_high))
  pl <- readr::read_csv(file.path(reread_dir, "hr3_paired_loo.csv"), show_col_types = FALSE)
  expect_true(all(pl$ci_low <= pl$mean_sq_err_diff & pl$mean_sq_err_diff <= pl$ci_high))
})

test_that("scorecard summary and playoffs table follow the revision rules", {
  path <- file.path(reread_dir, "scorecard_summary.csv")
  skip_if_not(file.exists(path), "scorecard summary not built")
  ss <- readr::read_csv(path, show_col_types = FALSE)
  v <- function(i) ss$value[ss$item == i]
  expect_equal(v("main_count_held") + v("main_count_partly_held") + v("main_count_failed"), 15)
  expect_lte(v("range_min_held"), v("main_count_held")); expect_gte(v("range_max_held"), v("main_count_held"))
  expect_equal(v("chance_rate_held"), 1 / 9)
  po <- readr::read_csv(file.path(reread_dir, "playoffs_descriptive.csv"), show_col_types = FALSE)
  expect_false(any(c("diff_generation", "diff_making") %in% names(po)))
  expect_true(file.exists(file.path(reread_dir, "session_info.txt")))
})
