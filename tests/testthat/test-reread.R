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
  expect_true(all(sc$trajectory_outcome %in% c("agree", "disagree")))
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
