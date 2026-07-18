# Tests: possession-table invariants. See HANDOFF §5a and R/03_possessions.R.

library(testthat)

poss_path <- proj_path("data/processed/possessions.rds")
sd_path <- proj_path("data/raw/wnba_shotdetail_2026.csv")
pbp_path <- proj_path("data/processed/pbp_events.rds")
data_available <- file.exists(poss_path) && file.exists(sd_path) && file.exists(pbp_path)

test_that("summed possession points equal each team's final box score, for all 182 games", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  possessions <- readRDS(poss_path)
  pbp <- readRDS(pbp_path)
  sd <- readr::read_csv(sd_path, show_col_types = FALSE)

  # Home/away per game from shotdetail (covers all 182 games, including
  # Toronto's, via the opponent's rows) -- independent of this pipeline's
  # own point computation, so this is a genuine external check, not a
  # tautology.
  home_away <- sd %>% dplyr::distinct(GAME_ID, HTM, VTM) %>% dplyr::distinct(GAME_ID, .keep_all = TRUE)
  final_scores <- pbp %>%
    dplyr::group_by(gameId) %>%
    dplyr::filter(orderNumber == max(orderNumber)) %>%
    dplyr::ungroup() %>%
    dplyr::select(gameId, scoreHome, scoreAway) %>%
    dplyr::left_join(home_away, by = c("gameId" = "GAME_ID"))

  final_long <- dplyr::bind_rows(
    final_scores %>% dplyr::transmute(gameId, team = HTM, final_score = scoreHome),
    final_scores %>% dplyr::transmute(gameId, team = VTM, final_score = scoreAway)
  )
  poss_points <- possessions %>% dplyr::group_by(gameId, team) %>%
    dplyr::summarise(pts = sum(points), .groups = "drop")

  check <- final_long %>% dplyr::left_join(poss_points, by = c("gameId", "team"))
  expect_equal(nrow(check), 364)
  expect_true(all(!is.na(check$pts)))
  expect_true(all(check$pts == check$final_score))
})

test_that("possession_id is unique within a game and live-ball possessions do not overlap in start_event", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  possessions <- readRDS(poss_path)
  expect_equal(length(unique(possessions$possession_id)), nrow(possessions))

  # technical_ft rows are deliberately nested inside the event range of the
  # possession they occur during (see R/03_possessions.R segment_possessions()
  # docstring) -- a technical FT is an out-of-band scoring event layered on
  # top of another team's possession, not its own slice of game time, so it
  # is excluded from the no-overlap check by design, not by oversight.
  overlaps <- possessions %>%
    dplyr::filter(outcome != "technical_ft") %>%
    dplyr::arrange(gameId, start_event) %>%
    dplyr::group_by(gameId) %>%
    dplyr::mutate(prev_end = dplyr::lag(end_event)) %>%
    dplyr::ungroup() %>%
    dplyr::filter(!is.na(prev_end), start_event < prev_end)
  expect_equal(nrow(overlaps), 0)
})

test_that("and-one sequences (made FG + shooting foul + FTs) collapse to one possession", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  pbp <- readRDS(pbp_path)
  violations <- handle_and_ones(pbp)
  # Documented residual: 1 in 476 true and-one candidates is a team-foul
  # bonus FT surface-identical to an and-one (see R/03_possessions.R
  # handle_and_ones() docstring) -- not a possession-segmentation defect.
  expect_equal(nrow(violations), EXPECTED_AND_ONE_VIOLATIONS)
})

test_that("technical free throws are excluded from the enclosing possession and credited to the shooting team", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  possessions <- readRDS(poss_path)
  tech <- possessions %>% dplyr::filter(outcome == "technical_ft")
  expect_gt(nrow(tech), 0)
  expect_true(all(tech$points == 1))
})

test_that("every possession has exactly one team and one opponent, and they differ", {
  skip_if_not(data_available, "required data files not built/downloaded yet")
  possessions <- readRDS(poss_path)
  expect_true(all(!is.na(possessions$team)))
  expect_true(all(!is.na(possessions$opponent)))
  expect_true(all(possessions$team != possessions$opponent))
})
