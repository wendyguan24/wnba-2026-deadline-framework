# 12_standing.R
#
# Purpose: Standing/window layer -- a data-driven proxy for each team's
#   competitive window (buyer / bubble / seller), computed from game results.
#   This is the standing/window layer added to the framework: it exists to
#   CONDITION THE RECOMMENDATION downstream (R/08_deadline_read.R,
#   R/11_generation_gap.R), never the diagnosis. Identity, generation,
#   making, and trajectory (R/05-R/07, R/11's gap decomposition) stay
#   record-independent by design -- that is what lets the framework claim it
#   reads beyond the record. Standing/window enters only at the
#   recommendation step, downstream of this script.
#
#   The window blends win-loss record AND scoring margin per game, equally
#   weighted (one more pass, accepted gm fix): win_pct alone can miscast a
#   team riding a lucky record (close wins, blown out in losses) or undersell
#   one that is winning big but has a middling record. point_diff_per_game
#   (point_diff / games) is z-scored across the 15 teams, win_pct is
#   z-scored the same way, and standing_score is their average -- see
#   build_standing() below. Window tier is assigned from the standing_score
#   rank, not win_pct rank alone. It remains a PROXY for front-office window,
#   not a front-office decision: a real front office overrides it with
#   private information this framework cannot see (ownership mandate, injury
#   outlook, timeline preference, a rebuild already underway despite a
#   mediocre record). Treat window as a data-driven default, not a verdict.
#
#     standing_score rank 1-5   -> "buyer"   comfortably in playoff position
#     standing_score rank 6-9   -> "bubble"  near the standing_score playoff line
#     standing_score rank 10-15 -> "seller"  out of the race
#
#   "Near the playoff line" is by standing_score (win_pct AND point differential),
#   NOT by win_pct alone -- do not read "bubble" as literally straddling the
#   8-seed. Because the blend rewards scoring margin, a sub-.500 team several
#   games back in the win_pct standings can still rank into the bubble band on a
#   strong point differential (the Toronto case: a bubble window on margin, not
#   on a .500-or-better record). games_back_from_8th (a pure win-loss statistic)
#   is the column to read for literal playoff-line distance; window is the
#   blended competitive-window proxy.
#
#   Playoff-line assumption (stated explicitly, not derived, and kept
#   separate from the window blend above): the WNBA takes 8 of 15 teams to
#   the playoffs, so the 8th-ranked team by win_pct (ties broken by season
#   point differential) is used as the playoff cut line for
#   games_back_from_8th, a standard games-back statistic that is always a
#   function of win-loss record, not scoring margin. The `rank` column below
#   is this win_pct rank, unchanged from before; it is what games_back_from_8th
#   is computed against. The window tier uses a separate standing_score rank
#   computed internally (see build_standing()) and is not the same ranking as
#   the `rank` column.
#
# Inputs:  data/processed/possessions.rds (possession_id, gameId, team,
#            opponent, points, ... -- see R/03_possessions.R). Summing
#            `points` by (gameId, team) gives each team's final game score;
#            this sums to the final box score exactly in all 364 team-games,
#            verified independently in tests/testthat/test-possession-invariants.R:10
#            ("summed possession points equal each team's final box score, for
#            all 182 games"), not re-derived tautologically here. Every gameId
#            has exactly two
#            teams (checked below); the team with more points in a game wins
#            -- there are no ties in basketball.
# Outputs: output/standing.csv (team, wins, losses, win_pct, point_diff,
#            point_diff_per_game, standing_score, rank, games_back_from_8th,
#            window); also printed to console.

library(tidyverse)

#' Compute each team's per-game score and win/loss from the possession-level
#' table.
#'
#' Sums `points` by (gameId, team) to get each team's final game score, then
#' derives each team's opponent score (the other team in the same gameId) and
#' win/loss. Asserts exactly two teams per gameId first.
#'
#' @param possessions tibble, data/processed/possessions.rds
#' @return tibble, one row per team-game: gameId, team, team_pts, opp_pts, win
build_game_scores <- function(possessions) {
  game_scores <- possessions %>%
    group_by(gameId, team) %>%
    summarise(team_pts = sum(points), .groups = "drop")

  teams_per_game <- game_scores %>% count(gameId)
  if (any(teams_per_game$n != 2)) {
    stop(
      "build_game_scores(): expected exactly 2 teams per gameId, found a ",
      "gameId with a different count -- check possessions.rds for a data issue."
    )
  }

  game_scores %>%
    group_by(gameId) %>%
    mutate(
      opp_pts = sum(team_pts) - team_pts,
      win = team_pts > opp_pts  # no ties in basketball
    ) %>%
    ungroup()
}

#' Build the per-team standing table: record, point differential,
#' standing_score, rank, games_back_from_8th, and window tier.
#'
#' games_back_from_8th = ((W_8th - L_8th) - (W_team - L_team)) / 2, where the
#' 8th-ranked team by `rank` (win_pct descending, ties broken by point_diff
#' descending -- see file header) is the playoff cut line. Negative values
#' mean a team sits ahead of the cut line, by the standard "games back"
#' convention. This is unchanged by the window blend below: games back is a
#' win-loss statistic, not a scoring-margin one.
#'
#' standing_score blends win_pct and point_diff_per_game (point_diff / games)
#' as equally-weighted z-scores across the 15 teams: standing_score =
#' (scale(win_pct) + scale(point_diff_per_game)) / 2. Window tier is assigned
#' from the standing_score rank (descending, ties broken by win_pct), not
#' from `rank` (see file header) -- so a team whose record overstates it
#' (a lucky win_pct riding a poor point differential) is not miscast as a
#' buyer or bubble team it is not.
#'
#' @param game_scores tibble, from build_game_scores()
#' @return tibble, team, wins, losses, win_pct, point_diff,
#'   point_diff_per_game, standing_score, rank, games_back_from_8th, window
build_standing <- function(game_scores) {
  standing <- game_scores %>%
    group_by(team) %>%
    summarise(
      wins = sum(win),
      losses = sum(!win),
      games = wins + losses,
      point_diff = sum(team_pts - opp_pts),
      .groups = "drop"
    ) %>%
    mutate(
      win_pct = wins / games,
      point_diff_per_game = point_diff / games
    ) %>%
    arrange(desc(win_pct), desc(point_diff)) %>%
    mutate(rank = row_number())

  eighth <- standing %>% filter(rank == 8)
  if (nrow(eighth) != 1) {
    stop("build_standing(): expected exactly one rank-8 team (the playoff cut line).")
  }
  w8 <- eighth$wins
  l8 <- eighth$losses

  standing <- standing %>%
    mutate(
      games_back_from_8th = ((w8 - l8) - (wins - losses)) / 2,
      standing_score = (as.numeric(scale(win_pct)) + as.numeric(scale(point_diff_per_game))) / 2
    )

  window_tbl <- standing %>%
    arrange(desc(standing_score), desc(win_pct)) %>%
    mutate(
      window_rank = row_number(),
      window = case_when(
        window_rank <= 5 ~ "buyer",    # comfortably in playoff position
        window_rank <= 9 ~ "bubble",   # straddling the 8-seed line
        TRUE              ~ "seller"   # out of the race
      )
    ) %>%
    select(team, window)

  standing %>%
    left_join(window_tbl, by = "team") %>%
    select(team, wins, losses, win_pct, point_diff, point_diff_per_game,
           standing_score, rank, games_back_from_8th, window)
}

main <- function() {
  possessions <- readRDS("data/processed/possessions.rds")

  game_scores <- build_game_scores(possessions)
  standing <- build_standing(game_scores)

  write_csv(standing, "output/standing.csv")

  message("Standing / window table (window from standing_score rank 1-5 buyer, 6-9 bubble, 10-15 seller; standing_score blends win_pct and point_diff_per_game, equally weighted):")
  print(standing, n = Inf)
  message("Window distribution:")
  print(table(standing$window))

  invisible(standing)
}

if (sys.nframe() == 0) {
  main()
}
