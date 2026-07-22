# Tests for R/13_player_value.R outputs (the reproducible production screen).
# These validate the minutes reconstruction invariant and the exhibit's shape.
# They read output/player_value.csv, so R/13 must have run first.

test_that("player_value.csv exists and has one row per player", {
  f <- proj_path("output", "player_value.csv")
  expect_true(file.exists(f))
  pv <- readr::read_csv(f, show_col_types = FALSE)
  expect_gt(nrow(pv), 0)
  expect_equal(nrow(pv), dplyr::n_distinct(pv$personId))
})

test_that("reconstructed player-minutes sum to 5 on court per team-period", {
  pv  <- readr::read_csv(proj_path("output", "player_value.csv"), show_col_types = FALSE)
  skip_if_not(all(pv$minutes_method == "reconstructed"),
              "minutes fell back to per-game rate; invariant does not apply")

  pbp <- readRDS(proj_path("data", "processed", "pbp_events.rds"))

  # expected total on-court minutes = 5 players * period length, summed over every
  # (game, period, team) that actually occurred
  expected <- pbp %>%
    dplyr::filter(!is.na(personId), personId != 0, !is.na(playerName)) %>%
    dplyr::distinct(gameId, period, teamTricode) %>%
    dplyr::mutate(period_min = dplyr::if_else(period <= 4, 10, 5)) %>%
    dplyr::summarise(total = sum(5 * period_min)) %>%
    dplyr::pull(total)

  reconstructed <- sum(pv$minutes)
  # allow 1 percent slack for the rare team-period the 5-on-court gate misses
  expect_lt(abs(reconstructed - expected) / expected, 0.01)
})

test_that("eligibility floors are enforced and replacement is anchored below them", {
  pv <- readr::read_csv(proj_path("output", "player_value.csv"), show_col_types = FALSE)
  elig <- pv %>% dplyr::filter(eligible)

  # every eligible player clears the handoff Section 5g floor AND the minutes floor
  expect_true(all((elig$FGA >= 100 | elig$poss_used >= 150) & elig$minutes >= 200))

  # replacement rate is a single constant and sits below the eligible median rate
  expect_equal(dplyr::n_distinct(round(pv$replacement_rate, 6)), 1)
  expect_lt(pv$replacement_rate[1], median(elig$gs_rate, na.rm = TRUE))

  # production tiers only assigned to eligible players
  expect_true(all(pv$production_tier[!pv$eligible] == "below threshold"))
  expect_true(all(pv$production_tier[pv$eligible] != "below threshold"))
})
