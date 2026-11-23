# Tests: starter inference in build_minutes() (R/lib_player_box.R).

library(testthat)
source(file.path(PROJECT_ROOT, "R", "lib_player_box.R"), local = TRUE)

mk <- function(order, period, pid, type = "2pt", sub = NA_character_, clock = 300) {
  tibble::tibble(gameId = 1, orderNumber = order, period = period, personId = pid,
                 teamTricode = "AAA", actionType = type, subType = sub,
                 parsed_clock_seconds = clock, playerName = paste0("P", pid))
}

test_that("a player with zero events all period is credited the full period from the prior on-court set", {
  ev <- dplyr::bind_rows(
    purrr::map_dfr(1:5, ~ mk(.x, 1, .x)),                 # period 1: players 1-5 all have events
    purrr::map_dfr(1:4, ~ mk(100 + .x, 2, .x))            # period 2: player 5 has no events at all
  )
  m <- build_minutes(ev)
  expect_equal(m$gate_pass_rate, 1)
  p5 <- m$minutes$minutes[m$minutes$personId == 5]
  expect_equal(p5, 20)   # 10 minutes in each of two periods
  expect_equal(sum(m$minutes$minutes), 100)   # 5 players x 20 minutes
})

test_that("a technical foul by a bench player does not make them a starter", {
  ev <- dplyr::bind_rows(
    purrr::map_dfr(1:5, ~ mk(.x, 1, .x)),
    mk(50, 1, 6, type = "foul", sub = "technical", clock = 400)
  )
  m <- build_minutes(ev)
  expect_equal(m$starter_counts$n_starters, 5)
  expect_false(6 %in% m$minutes$personId[m$minutes$minutes > 0])
})

test_that("an event at the same clock as the player's own sub-in does not make them a starter", {
  ev <- dplyr::bind_rows(
    purrr::map_dfr(1:5, ~ mk(.x, 1, .x, clock = 500)),
    mk(60, 1, 5, type = "substitution", sub = "out", clock = 300),
    mk(61, 1, 6, type = "substitution", sub = "in", clock = 300),
    mk(62, 1, 6, type = "2pt", clock = 300)
  )
  m <- build_minutes(ev)
  expect_equal(m$starter_counts$n_starters, 5)
  expect_equal(m$minutes$minutes[m$minutes$personId == 6], 5)  # 300 seconds
})
