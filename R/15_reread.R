# 15_reread.R
#
# Purpose: full-season re-read of v1 (PLAN.md "Scope"): trade flags (Block B), the
#   pre-registered hypothesis tests H-R1 to H-R4, H1, H2, H3 (Block C), the v1 read
#   scorecard and the playoffs descriptive table. Regular season only for all
#   hypotheses; playoffs are descriptive. No hypotheses are added here.
#
# Inputs:  window outputs from R/05, R/07, R/06 (first_half, second_half, full, playoffs)
#          under data/processed/full2026/windows/ and output/offseason/reread/;
#          v1 outputs in output/ (icc_table.csv, deadline_read.csv);
#          analysis tables (games, team_games, player_games).
# Outputs: output/offseason/reread/*.csv (trade_flags, test results, scorecard, playoffs table)
#
# Run from the repo root after the four windows have been built:
#   for w in first_half second_half full playoffs; do ... done  (see README)
#   Rscript R/15_reread.R

suppressMessages(library(tidyverse))
source(file.path(if (exists("PROJECT_ROOT")) PROJECT_ROOT else ".", "R", "00_config.R"))
source(file.path(PROJECT_ROOT, "R", "load_tables.R"))

REREAD_DIR <- file.path(OUTPUT_DIR, "reread")
BOOT_SEED <- 20261123L
N_BOOT <- 2000L
DEADLINE_DATE <- as.Date("2026-08-02")
# "Around the deadline" rule: the player's first game for the new team is within
# 2026-07-26 to 2026-08-09, or the gap between the last game for the old team and the
# first game for the new team contains the deadline date.
DEADLINE_BAND <- as.Date(c("2026-07-26", "2026-08-09"))
TRADE_FLAG_SHARE <- 0.10

window_dir <- function(w) file.path(PROCESSED_DIR, "windows", w)
window_out <- function(w) file.path(REREAD_DIR, w)

# Block B: trade flags -----------------------------------------------------

#' Player stints per team (regular season) in game_id order, with minutes by window
#'
#' @return tibble: person_id, player_name, team, first_game, last_game, first_date,
#'   last_date, games, minutes_first_half, minutes_second_half, stint_n, n_stints
build_stints <- function() {
  games <- load_table("games", "regular") %>% select(game_id, game_date)
  pg <- load_table("player_games", "regular") %>%
    left_join(games, by = "game_id") %>%
    mutate(half = if_else(game_id <= V1_LAST_GAME_ID, "first_half", "second_half"))
  stints <- pg %>%
    group_by(person_id, team) %>%
    summarise(player_name = last(player_name),
              first_game = min(game_id), last_game = max(game_id),
              first_date = min(game_date), last_date = max(game_date),
              n_games = n(),
              minutes_first_half = sum(minutes[half == "first_half"]),
              minutes_second_half = sum(minutes[half == "second_half"]),
              .groups = "drop") %>%
    group_by(person_id) %>%
    arrange(first_game, .by_group = TRUE) %>%
    mutate(stint_n = row_number(), n_stints = n()) %>%
    ungroup()
  stints
}

#' Trade flags per team, plus the list of moves
#'
#' A player is moved if he appears for 2+ teams in the regular season. For team T:
#' share_out = first-half minutes for T by players whose stint with T was followed by a
#' stint with another team, over T's first-half minutes; share_in = second-half minutes
#' for T by players whose stint with T was preceded by a stint with another team, over
#' T's second-half minutes. trade_flag = either share >= TRADE_FLAG_SHARE.
build_trade_flags <- function() {
  stints <- build_stints()
  teams <- load_table("team_games", "regular") %>% distinct(team) %>% pull(team) %>% sort()
  team_min <- stints %>% group_by(team) %>%
    summarise(team_min_first = sum(minutes_first_half),
              team_min_second = sum(minutes_second_half), .groups = "drop")
  moved <- stints %>% filter(n_stints > 1) %>%
    group_by(person_id) %>%
    mutate(left_team = stint_n < n_stints, arrived_team = stint_n > 1,
           prev_team = lag(team), prev_last_date = lag(last_date),
           next_team = lead(team)) %>%
    ungroup()

  flags <- tibble(team = teams) %>%
    left_join(team_min, by = "team") %>%
    left_join(moved %>% filter(left_team) %>% group_by(team) %>%
                summarise(min_out = sum(minutes_first_half),
                          n_out = n_distinct(person_id), .groups = "drop"), by = "team") %>%
    left_join(moved %>% filter(arrived_team) %>% group_by(team) %>%
                summarise(min_in = sum(minutes_second_half),
                          n_in = n_distinct(person_id), .groups = "drop"), by = "team") %>%
    mutate(across(c(min_out, n_out, min_in, n_in), ~ replace_na(.x, 0)),
           share_out = min_out / team_min_first,
           share_in = min_in / team_min_second,
           trade_flag = share_out >= TRADE_FLAG_SHARE | share_in >= TRADE_FLAG_SHARE)

  moves <- moved %>% filter(arrived_team) %>%
    transmute(person_id, player_name, from_team = prev_team, to_team = team,
              last_game_from = prev_last_date, first_game_to = first_date,
              games_with_to = n_games,
              minutes_to_first_half = minutes_first_half,
              minutes_to_second_half = minutes_second_half,
              around_deadline = (first_date >= DEADLINE_BAND[1] & first_date <= DEADLINE_BAND[2]) |
                (prev_last_date <= DEADLINE_DATE & first_date >= DEADLINE_DATE)) %>%
    arrange(first_game_to)

  names_out <- moved %>% filter(left_team) %>% group_by(team) %>%
    summarise(players_out = paste(player_name, collapse = "; "), .groups = "drop")
  names_in <- moved %>% filter(arrived_team) %>% group_by(team) %>%
    summarise(players_in = paste(player_name, collapse = "; "), .groups = "drop")
  flags <- flags %>% left_join(names_out, by = "team") %>% left_join(names_in, by = "team") %>%
    mutate(across(c(players_out, players_in), ~ replace_na(.x, ""))) %>%
    select(team, share_out, share_in, n_out, n_in, players_out, players_in, trade_flag)
  list(flags = flags, moves = moves)
}

run_block_b <- function() {
  tf <- build_trade_flags()
  dir.create(REREAD_DIR, recursive = TRUE, showWarnings = FALSE)
  write_csv(tf$flags %>% rename(minutes_share_out = share_out, minutes_share_in = share_in,
                                n_players_out = n_out, n_players_in = n_in),
            file.path(REREAD_DIR, "trade_flags.csv"))
  write_csv(tf$moves, file.path(REREAD_DIR, "player_moves.csv"))
  tf
}


# Shared helpers for block C ---------------------------------------------------

POPULATIONS <- c("all15", "no_trade13")

#' Teams in a population given the trade flags
pop_teams <- function(flags, pop) {
  if (pop == "all15") flags$team else flags$team[!flags$trade_flag]
}

#' Bootstrap resample index matrix (N_BOOT x n), same seed for every test
boot_index <- function(n) {
  set.seed(BOOT_SEED)
  matrix(sample.int(n, n * N_BOOT, replace = TRUE), nrow = N_BOOT, ncol = n)
}

#' Spearman rho for x, y with a team-bootstrap 95% percentile CI
spearman_boot <- function(x, y) {
  idx <- boot_index(length(x))
  rho <- suppressWarnings(cor(x, y, method = "spearman"))
  bs <- apply(idx, 1, function(i) suppressWarnings(cor(x[i], y[i], method = "spearman")))
  tibble(rho = rho, ci_low = unname(quantile(bs, 0.025, na.rm = TRUE)),
         ci_high = unname(quantile(bs, 0.975, na.rm = TRUE)), n_boot_valid = sum(!is.na(bs)))
}

#' Percentile and tier exactly as v1 (R/08): ntile(x, 3) and round(100 * (rank - 1) / (n - 1))
pctile <- function(x) round(100 * (rank(x) - 1) / (length(x) - 1))

read_gm <- function(w) read_csv(file.path(window_out(w), "team_generation_making.csv"), show_col_types = FALSE)
read_blups <- function(w) readRDS(file.path(window_dir(w), "team_blups.rds"))
read_traj <- function(w) read_csv(file.path(window_out(w), "team_trajectories.csv"), show_col_types = FALSE)
read_trends <- function(w) read_csv(file.path(window_out(w), "trajectory_league_trends.csv"), show_col_types = FALSE)

#' Team-game results by window (regular season): record and point differential
window_record <- function(w) {
  ids <- window_game_ids(load_table("games", "all"), w)
  load_table("team_games", "regular") %>% filter(game_id %in% ids) %>%
    group_by(team) %>%
    summarise(games = n(), wins = sum(win), win_pct = mean(win),
              point_diff = sum(pts - opp_pts), pd_per_game = mean(pts - opp_pts), .groups = "drop")
}

# H-R1 -----------------------------------------------------------------------

#' Anchor metrics: ICC >= 0.15 in the v1 icc_table
anchor_metrics <- function() {
  read_csv(file.path(PROJECT_ROOT, "output", "icc_table.csv"), show_col_types = FALSE) %>%
    filter(icc >= 0.15) %>% arrange(desc(icc))
}

test_hr1 <- function(flags) {
  anchors <- anchor_metrics()
  b1 <- read_blups("first_half"); b2 <- read_blups("second_half")
  map_dfr(POPULATIONS, function(pop) {
    tm <- pop_teams(flags, pop)
    map_dfr(seq_len(nrow(anchors)), function(k) {
      m <- anchors$metric[k]
      a <- b1 %>% filter(metric == m, team %in% tm) %>% arrange(team)
      b <- b2 %>% filter(metric == m, team %in% tm) %>% arrange(team)
      stopifnot(identical(a$team, b$team))
      spearman_boot(a$adjusted_value, b$adjusted_value) %>%
        mutate(population = pop, metric = m, v1_icc = anchors$icc[k], n_teams = length(tm))
    })
  }) %>% select(population, metric, v1_icc, n_teams, rho, ci_low, ci_high, n_boot_valid)
}

verdict_hr1 <- function(hr1) {
  hr1 %>% group_by(population) %>%
    summarise(n_anchor = n(), n_rho_ge_0.7 = sum(rho >= 0.7),
              median_rho = median(rho),
              verdict = if_else(sum(rho >= 0.7) > n() / 2, "supported", "not supported"),
              .groups = "drop")
}

# H-R2 -----------------------------------------------------------------------

test_hr2 <- function(flags) {
  g1 <- read_gm("first_half"); g2 <- read_gm("second_half")
  map_dfr(POPULATIONS, function(pop) {
    tm <- pop_teams(flags, pop)
    a <- g1 %>% filter(team %in% tm) %>% arrange(team)
    b <- g2 %>% filter(team %in% tm) %>% arrange(team)
    idx <- boot_index(length(tm))
    rho_f <- function(x, y, i = seq_along(x)) suppressWarnings(cor(x[i], y[i], method = "spearman"))
    rg <- rho_f(a$shot_generation_per100, b$shot_generation_per100)
    rm <- rho_f(a$shot_making_per100, b$shot_making_per100)
    bg <- apply(idx, 1, function(i) rho_f(a$shot_generation_per100, b$shot_generation_per100, i))
    bm <- apply(idx, 1, function(i) rho_f(a$shot_making_per100, b$shot_making_per100, i))
    d <- bg - bm
    ci <- unname(quantile(d, c(0.025, 0.975), na.rm = TRUE))
    verdict <- case_when(
      rg > rm & ci[1] > 0 ~ "supported",
      rg > rm ~ "directionally consistent",
      TRUE ~ "not supported")
    tibble(population = pop, n_teams = length(tm), rho_generation = rg, rho_making = rm,
           diff = rg - rm, diff_ci_low = ci[1], diff_ci_high = ci[2],
           gen_ci_low = unname(quantile(bg, 0.025, na.rm = TRUE)),
           gen_ci_high = unname(quantile(bg, 0.975, na.rm = TRUE)),
           mk_ci_low = unname(quantile(bm, 0.025, na.rm = TRUE)),
           mk_ci_high = unname(quantile(bm, 0.975, na.rm = TRUE)), verdict = verdict)
  })
}

#' LVA making (all windows; descriptive, one team; LVA is not trade-flagged)
lva_making <- function() {
  map_dfr(c("first_half", "second_half", "full"), function(w) {
    g <- read_gm(w) %>% mutate(making_pctile = pctile(shot_making_per100),
                               generation_pctile = pctile(shot_generation_per100))
    g %>% filter(team == "LVA") %>%
      transmute(window = w, shot_generation_per100, generation_pctile,
                shot_making_per100, making_pctile)
  })
}

# H-R3 -----------------------------------------------------------------------

loo_rmse <- function(formula, data, y) {
  err <- map_dbl(seq_len(nrow(data)), function(i) {
    fit <- lm(formula, data = data[-i, ])
    data[[y]][i] - predict(fit, newdata = data[i, , drop = FALSE])
  })
  sqrt(mean(err^2))
}

hr3_data <- function() {
  r1 <- window_record("first_half") %>% select(team, fh_win_pct = win_pct, fh_pd = pd_per_game)
  r2 <- window_record("second_half") %>% select(team, sh_win_pct = win_pct, sh_pd = pd_per_game)
  g1 <- read_gm("first_half") %>% select(team, generation = shot_generation_per100,
                                         making = shot_making_per100)
  r1 %>% left_join(r2, by = "team") %>% left_join(g1, by = "team")
}

test_hr3 <- function(flags) {
  d_all <- hr3_data()
  map_dfr(POPULATIONS, function(pop) {
    d <- d_all %>% filter(team %in% pop_teams(flags, pop))
    outcomes <- c("sh_pd", "sh_win_pct")
    map_dfr(outcomes, function(y) {
      fA <- as.formula(paste(y, "~ fh_win_pct"))
      fA2 <- as.formula(paste(y, "~ fh_pd"))
      fB <- as.formula(paste(y, "~ fh_win_pct + generation + making"))
      rA <- loo_rmse(fA, d, y); rA2 <- loo_rmse(fA2, d, y); rB <- loo_rmse(fB, d, y)
      rNull <- sqrt(mean(map_dbl(seq_len(nrow(d)), function(i) d[[y]][i] - mean(d[[y]][-i]))^2))
      tibble(population = pop, outcome = y, n_teams = nrow(d),
             loo_rmse_A_record = rA, loo_rmse_Aprime_pd = rA2, loo_rmse_B_record_gen_mk = rB,
             loo_rmse_mean_only = rNull,
             B_beats_A = rB < rA, B_beats_Aprime = rB < rA2)
    })
  })
}

coef_hr3 <- function(flags) {
  d_all <- hr3_data()
  map_dfr(POPULATIONS, function(pop) {
    d <- d_all %>% filter(team %in% pop_teams(flags, pop))
    map_dfr(c("sh_pd", "sh_win_pct"), function(y) {
      forms <- list(A = paste(y, "~ fh_win_pct"), Aprime = paste(y, "~ fh_pd"),
                    B = paste(y, "~ fh_win_pct + generation + making"))
      imap_dfr(forms, function(f, nm) {
        fit <- lm(as.formula(f), data = d)
        cf <- summary(fit)$coefficients
        tibble(population = pop, outcome = y, model = nm, term = rownames(cf),
               estimate = cf[, 1], se = cf[, 2], p = cf[, 4], n_teams = nrow(d),
               r_squared = summary(fit)$r.squared)
      })
    })
  })
}

# H-R4 -----------------------------------------------------------------------

test_hr4 <- function(flags) {
  v1 <- read_csv(file.path(PROJECT_ROOT, "output", "deadline_read.csv"), show_col_types = FALSE) %>%
    select(team, trajectory, interval_spans_zero)
  g1 <- read_gm("first_half") %>% select(team, mk1 = shot_making_per100)
  g2 <- read_gm("second_half") %>% select(team, mk2 = shot_making_per100)
  d <- v1 %>% left_join(g1, by = "team") %>% left_join(g2, by = "team") %>%
    mutate(making_change = mk2 - mk1,
           outcome_direction = if_else(making_change > 0, "improving", "declining"),
           agree = trajectory == outcome_direction)
  detail <- d
  res <- map_dfr(POPULATIONS, function(pop) {
    map_dfr(c("all_labels", "interval_excludes_zero"), function(sub) {
      x <- d %>% filter(team %in% pop_teams(flags, pop))
      if (sub == "interval_excludes_zero") x <- x %>% filter(!interval_spans_zero)
      k <- sum(x$agree); n <- nrow(x)
      if (n == 0) return(tibble(population = pop, subset = sub, n_teams = 0L, n_agree = 0L,
                                agreement = NA_real_, p_two_sided = NA_real_,
                                ci_low = NA_real_, ci_high = NA_real_, verdict = "no labels"))
      bt <- binom.test(k, n, 0.5)
      tibble(population = pop, subset = sub, n_teams = n, n_agree = k, agreement = k / n,
             p_two_sided = bt$p.value, ci_low = bt$conf.int[1], ci_high = bt$conf.int[2],
             verdict = if_else(k / n > 0.5 & bt$p.value < 0.05, "not supported", "supported (null)"))
    })
  })
  list(summary = res, detail = detail)
}

# H1, H2 (full season) ---------------------------------------------------------

#' Refit the five trajectory metrics on a team subset, using R/06's own functions
#' (rows where `team` is in the subset; opponent random effects keep all opponents)
refit_trends_subset <- function(w, teams_keep) {
  suppressMessages(suppressWarnings({
    if (!exists("fit_all_trajectory_models")) source(file.path(PROJECT_ROOT, "R", "06_models.R"))
    feat <- readRDS(file.path(window_dir(w), "team_game_features.rds"))
    mk <- readRDS(file.path(window_dir(w), "team_game_shot_making.rds"))
    feat <- feat %>% left_join(select(mk, gameId, team, shot_making_residual), by = c("gameId", "team")) %>%
      filter(team %in% teams_keep)
    fit_all_trajectory_models(feat)
  }))
}

test_h1h2 <- function(flags) {
  keep13 <- pop_teams(flags, "no_trade13")
  t_full <- read_trends("full") %>% mutate(window = "full", population = "all15")
  t_fh <- read_trends("first_half") %>% mutate(window = "first_half (v1 sample)", population = "all15")
  sub <- refit_trends_subset("full", keep13)
  t_sub <- sub$league_trends %>% mutate(window = "full", population = "no_trade13")
  team_sub <- sub$team_trajectories %>% mutate(window = "full", population = "no_trade13")
  trends <- bind_rows(t_fh, t_full, t_sub) %>%
    filter(metric %in% c("transition_share", "transition_pts_per_poss", "assisted_rate",
                         "live_ball_tov_rate")) %>%
    select(population, window, metric, league_trend, league_trend_p, fallback_used)
  teams <- bind_rows(
    read_traj("first_half") %>% mutate(window = "first_half (v1 sample)", population = "all15"),
    read_traj("full") %>% mutate(window = "full", population = "all15"),
    team_sub) %>%
    filter(team %in% c("TOR", "PDX"), metric %in% c("assisted_rate", "live_ball_tov_rate")) %>%
    select(population, window, metric, team, slope, ci_low, ci_high, trajectory, interval_spans_zero)
  list(trends = trends, teams = teams)
}

# H3 -----------------------------------------------------------------------------

test_h3 <- function() {
  gm <- map_dfr(c("first_half", "second_half", "full", "playoffs"), function(w) {
    g <- read_gm(w) %>% mutate(making_pctile = pctile(shot_making_per100),
                               generation_pctile = pctile(shot_generation_per100),
                               n_teams = n())
    g %>% filter(team == "GSV") %>% mutate(window = w) %>%
      select(window, n_teams, fga, poss_count, shot_generation_per100, generation_pctile,
             shot_making_per100, making_pctile)
  })
  traj <- read_traj("full") %>% filter(team == "GSV", metric == "shot_making_residual") %>%
    mutate(window = "full") %>%
    select(window, slope, ci_low, ci_high, trajectory, interval_spans_zero)
  traj_v1 <- read_traj("first_half") %>% filter(team == "GSV", metric == "shot_making_residual") %>%
    mutate(window = "first_half (v1 sample)") %>%
    select(window, slope, ci_low, ci_high, trajectory, interval_spans_zero)
  list(making = gm, trajectory = bind_rows(traj_v1, traj))
}

# Scorecard ----------------------------------------------------------------------

build_scorecard <- function(flags, hr4_detail) {
  v1 <- read_csv(file.path(PROJECT_ROOT, "output", "deadline_read.csv"), show_col_types = FALSE) %>%
    select(team, v1_generation_tier = generation_tier, v1_making_tier = making_tier,
           v1_trajectory = trajectory, v1_interval_spans_zero = interval_spans_zero,
           v1_lever = lever, v1_recommendation = recommendation)
  g2 <- read_gm("second_half") %>%
    mutate(sh_generation_pctile = pctile(shot_generation_per100),
           sh_making_pctile = pctile(shot_making_per100),
           sh_generation_tier = ntile(shot_generation_per100, 3),
           sh_making_tier = ntile(shot_making_per100, 3)) %>%
    select(team, sh_generation_pctile, sh_making_pctile, sh_generation_tier, sh_making_tier)
  rec2 <- window_record("second_half") %>%
    transmute(team, sh_record = paste0(wins, "-", games - wins), sh_win_pct = win_pct,
              sh_pd_per_game = pd_per_game)
  fin <- window_record("full") %>% arrange(desc(win_pct), desc(point_diff)) %>%
    mutate(final_rank = row_number()) %>%
    transmute(team, final_record = paste0(wins, "-", games - wins), final_rank)
  v1 %>% left_join(g2, by = "team") %>%
    left_join(hr4_detail %>% select(team, making_change, outcome_direction, agree), by = "team") %>%
    left_join(flags %>% select(team, trade_flag), by = "team") %>%
    left_join(rec2, by = "team") %>% left_join(fin, by = "team") %>%
    mutate(gen_step = abs(sh_generation_tier - v1_generation_tier),
           mk_step = abs(sh_making_tier - v1_making_tier),
           verdict = case_when(
             gen_step == 0 & mk_step == 0 ~ "held",
             (gen_step == 1 & mk_step == 0) | (gen_step == 0 & mk_step == 1) ~ "partly held",
             TRUE ~ "failed"),
           trajectory_outcome = if_else(agree, "agree", "disagree")) %>%
    select(team, v1_generation_tier, sh_generation_tier, sh_generation_pctile,
           v1_making_tier, sh_making_tier, sh_making_pctile, verdict,
           v1_trajectory, v1_interval_spans_zero, making_change, outcome_direction,
           trajectory_outcome, v1_lever, v1_recommendation, trade_flag,
           sh_record, sh_win_pct, sh_pd_per_game, final_record, final_rank) %>%
    arrange(factor(verdict, levels = c("held", "partly held", "failed")), team)
}

# Playoffs descriptive ---------------------------------------------------------

playoff_series <- function() {
  g <- load_table("games", "playoffs") %>% arrange(game_id) %>%
    mutate(winner = if_else(home_pts > away_pts, home_team, away_team),
           a = pmin(home_team, away_team), b = pmax(home_team, away_team))
  s <- g %>% group_by(a, b) %>%
    summarise(first_game = min(game_id), games = n(),
              wins_a = sum(winner == a), wins_b = sum(winner == b), .groups = "drop") %>%
    arrange(first_game) %>%
    mutate(series_winner = if_else(wins_a > wins_b, a, b),
           series_loser = if_else(wins_a > wins_b, b, a),
           series_score = paste0(pmax(wins_a, wins_b), "-", pmin(wins_a, wins_b)))
  s
}

build_playoff_table <- function() {
  series <- playoff_series()
  reg <- read_gm("full") %>% select(team, rs_generation = shot_generation_per100,
                                    rs_making = shot_making_per100)
  po <- read_gm("playoffs") %>% select(team, po_generation = shot_generation_per100,
                                       po_making = shot_making_per100, po_fga = fga)
  gp <- load_table("team_games", "playoffs") %>% count(team, name = "po_games")
  res <- bind_rows(
    series %>% transmute(team = series_winner, series_n = row_number(),
                         result = paste0("won ", series_score, " vs ", series_loser)),
    series %>% transmute(team = series_loser, series_n = row_number(),
                         result = paste0("lost ", series_score, " vs ", series_winner))) %>%
    arrange(team, series_n) %>% group_by(team) %>%
    summarise(series_result = paste(result, collapse = "; "), .groups = "drop")
  po %>% left_join(reg, by = "team") %>% left_join(gp, by = "team") %>%
    left_join(res, by = "team") %>%
    mutate(diff_generation = po_generation - rs_generation, diff_making = po_making - rs_making) %>%
    select(team, po_games, series_result, rs_generation, po_generation, diff_generation,
           rs_making, po_making, diff_making, po_fga) %>%
    arrange(desc(po_games))
}

# Run ----------------------------------------------------------------------------

run_block_c <- function(flags) {
  out <- list()
  out$hr1 <- test_hr1(flags);              out$hr1_verdict <- verdict_hr1(out$hr1)
  out$hr2 <- test_hr2(flags);              out$hr2_lva <- lva_making()
  out$hr3 <- test_hr3(flags);              out$hr3_coef <- coef_hr3(flags)
  h4 <- test_hr4(flags);                   out$hr4 <- h4$summary; out$hr4_detail <- h4$detail
  h12 <- test_h1h2(flags);                 out$h1h2_trends <- h12$trends; out$h1h2_teams <- h12$teams
  h3 <- test_h3();                         out$h3_making <- h3$making; out$h3_traj <- h3$trajectory
  out$scorecard <- build_scorecard(flags, h4$detail)
  out$playoffs <- build_playoff_table()
  out$playoff_series <- playoff_series()
  dir.create(REREAD_DIR, recursive = TRUE, showWarnings = FALSE)
  nm <- c(hr1 = "hr1_spearman", hr1_verdict = "hr1_verdict", hr2 = "hr2_generation_vs_making",
          hr2_lva = "hr2_lva_making", hr3 = "hr3_loo_rmse", hr3_coef = "hr3_coefficients",
          hr4 = "hr4_trajectory_labels", hr4_detail = "hr4_detail", h1h2_trends = "h1h2_league_trends",
          h1h2_teams = "h1h2_tor_pdx", h3_making = "h3_gsv_making", h3_traj = "h3_gsv_trajectory",
          scorecard = "scorecard", playoffs = "playoffs_descriptive", playoff_series = "playoff_series")
  iwalk(nm, function(f, k) write_csv(out[[k]], file.path(REREAD_DIR, paste0(f, ".csv"))))
  out
}

if (sys.nframe() == 0) {
  tf <- run_block_b()
  print(tf$flags %>% select(-players_out, -players_in), n = 20)
  res <- run_block_c(tf$flags)
  options(width = 200, pillar.sigfig = 4)
  iwalk(res, function(x, k) { cat("\n====", k, "\n"); print(x, n = 60) })
}
