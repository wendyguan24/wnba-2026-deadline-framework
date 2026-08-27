# 21_wehoop_player_value.R
#
# Purpose: Player value screen using official wehoop leaguedash stats plus
#   RAPM and hustle data. Upgrades R/13_player_value.R (PBP-reconstructed
#   Game Score only) by using official minutes/box stats, adding a real
#   defensive-impact signal (RAPM), and a hustle-activity tier.
#
# Same scope caveat as 13: this is a box-score/impact SCREEN, not a
#   deliverable ranking. Game Score weights are NBA-derived and unvalidated
#   for the WNBA. RAPM on a partial season is noisy below the possession
#   floor applied here; treat rapm_tier as directional, not precise.
#
# Inputs:  data/wehoop/leaguedash_player_stats_base.csv
#          data/wehoop/leaguedash_player_stats_advanced.csv
#          data/wehoop/leaguedash_player_stats_scoring.csv (context only)
#          data/wehoop/live/rapm.csv
#          data/wehoop/live/hustle_player.csv
#          data/wehoop/espn_player_core.csv
#          data/wehoop/espn_rosters.csv
#          data/wehoop/team_lookup.rds (from 17_wehoop_scaffold.R)
# Outputs: output/wehoop/player_value.csv
#          output/wehoop/player_value.md

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

DATA_DIR <- file.path("data", "wehoop")
LIVE_DIR <- file.path(DATA_DIR, "live")
OUT_DIR  <- file.path("output", "wehoop")

MIN_MINUTES  <- 200   # same eligibility floor as 13_player_value.R
MIN_FGA      <- 100
MIN_RAPM_POSS <- 500  # off_poss + def_poss floor for rapm_tier

TIER_LABELS <- c("fringe", "rotation", "upper rotation", "top")

#' Read a csv and lowercase its names so official-stats columns
#' (PLAYER_ID, TEAM_ID) line up with live/ and espn_ columns already
#' snake_case.
read_lower <- function(path, required = TRUE) {
  if (!file.exists(path)) {
    if (required) stop(sprintf("read_lower(): required file not found: %s", path))
    message(sprintf("  WARN: optional file not found, skipping: %s", path))
    return(NULL)
  }
  df <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
  names(df) <- tolower(names(df))
  df
}

#' First column name present in `df` from a list of candidate names, or
#' NA if none match.
first_present <- function(df, candidates) {
  hit <- intersect(candidates, names(df))
  if (length(hit) == 0) NA_character_ else hit[1]
}

#' Quartile-tier a numeric vector into TIER_LABELS (fringe < rotation <
#' upper rotation < top), NA where x is NA. Ties at a break go to the
#' lower tier (breaks are inclusive on the upper end, per 13_player_value.R).
quartile_tier <- function(x) {
  ok <- !is.na(x)
  if (sum(ok) < 4) return(rep(NA_character_, length(x)))
  breaks <- quantile(x[ok], c(0, .25, .5, .75, 1), na.rm = TRUE)
  out <- rep(NA_character_, length(x))
  out[ok] <- case_when(
    x[ok] >= breaks[4] ~ TIER_LABELS[4],
    x[ok] >= breaks[3] ~ TIER_LABELS[3],
    x[ok] >= breaks[2] ~ TIER_LABELS[2],
    TRUE               ~ TIER_LABELS[1]
  )
  out
}

#' Hollinger Game Score from official season-total box counts, then
#' per-game and per-40 rates. GmSc_per40 = (GmSc/GP) / (MIN/GP) * 40.
#'
#' @param base tibble from leaguedash_player_stats_base.csv (lowercased)
#' @return base with game_score, gmsc_per_game, gmsc_per40 columns added
add_game_score <- function(base) {
  needed <- c("player_id", "player_name", "team_id", "gp", "min",
              "fgm", "fga", "ftm", "fta", "oreb", "dreb", "stl", "ast",
              "blk", "pf", "tov", "pts")
  missing_cols <- setdiff(needed, names(base))
  if (length(missing_cols) > 0) {
    stop("add_game_score(): leaguedash_player_stats_base.csv missing columns: ",
         paste(missing_cols, collapse = ", "))
  }

  base %>%
    mutate(
      game_score = pts + 0.4 * fgm - 0.7 * fga - 0.4 * (fta - ftm) +
        0.7 * oreb + 0.3 * dreb + stl + 0.7 * ast + 0.7 * blk - 0.4 * pf - tov,
      minutes_per_game = if_else(gp > 0, min / gp, NA_real_),
      gmsc_per_game = if_else(gp > 0, game_score / gp, NA_real_),
      gmsc_per40 = if_else(minutes_per_game > 0,
                            gmsc_per_game / minutes_per_game * 40, NA_real_)
    )
}

#' Attach RAPM (live/rapm.csv), joined on player_id. Players below
#' MIN_RAPM_POSS total possessions get rapm_tier = NA (rapm value itself
#' is still reported, undiluted).
add_rapm <- function(tab, rapm) {
  if (is.null(rapm)) {
    return(tab %>% mutate(rapm = NA_real_, o_rapm = NA_real_, d_rapm = NA_real_,
                           rapm_poss = NA_real_, rapm_tier = NA_character_))
  }
  id_col <- first_present(rapm, c("player_id", "athlete_id"))
  if (is.na(id_col)) {
    stop("add_rapm(): rapm.csv has no recognizable player id column")
  }
  needed <- c("o_rapm", "d_rapm", "rapm", "off_poss", "def_poss")
  missing_cols <- setdiff(needed, names(rapm))
  if (length(missing_cols) > 0) {
    stop("add_rapm(): rapm.csv missing columns: ", paste(missing_cols, collapse = ", "))
  }
  rapm_small <- rapm %>%
    transmute(player_id = .data[[id_col]], o_rapm, d_rapm, rapm,
              rapm_poss = off_poss + def_poss)

  tab <- tab %>% left_join(rapm_small, by = "player_id")
  rapm_eligible <- tab$rapm_poss >= MIN_RAPM_POSS & !is.na(tab$rapm_poss)
  tier_vals <- rep(NA_real_, nrow(tab))
  tier_vals[rapm_eligible] <- tab$rapm[rapm_eligible]
  tab$rapm_tier <- quartile_tier(tier_vals)
  tab
}

#' Per-game hustle rates (live/hustle_player.csv) and a composite hustle
#' tier from the sum of z-scored rates (different units, so z-score first
#' rather than summing raw counts).
add_hustle <- function(tab, hustle) {
  if (is.null(hustle)) {
    return(tab %>% mutate(contested_shots_pg = NA_real_, deflections_pg = NA_real_,
                           loose_balls_pg = NA_real_, charges_drawn_pg = NA_real_,
                           screen_assists_pg = NA_real_, hustle_tier = NA_character_))
  }
  id_col <- first_present(hustle, c("player_id", "athlete_id"))
  needed <- c("contested_shots", "deflections", "loose_balls_recovered",
              "charges_drawn", "screen_assists", "gp")
  missing_cols <- setdiff(needed, names(hustle))
  if (is.na(id_col) || length(missing_cols) > 0) {
    message("  WARN: hustle_player.csv missing id or columns (",
            paste(missing_cols, collapse = ", "), "), skipping hustle profile")
    return(tab %>% mutate(contested_shots_pg = NA_real_, deflections_pg = NA_real_,
                           loose_balls_pg = NA_real_, charges_drawn_pg = NA_real_,
                           screen_assists_pg = NA_real_, hustle_tier = NA_character_))
  }

  hustle_rates <- hustle %>%
    filter(gp > 0) %>%
    transmute(
      player_id = .data[[id_col]],
      contested_shots_pg = contested_shots / gp,
      deflections_pg = deflections / gp,
      loose_balls_pg = loose_balls_recovered / gp,
      charges_drawn_pg = charges_drawn / gp,
      screen_assists_pg = screen_assists / gp
    )

  rate_cols <- c("contested_shots_pg", "deflections_pg", "loose_balls_pg",
                 "charges_drawn_pg", "screen_assists_pg")
  z_sum <- rep(0, nrow(hustle_rates))
  for (col in rate_cols) {
    z_sum <- z_sum + as.numeric(scale(hustle_rates[[col]]))
  }
  hustle_rates$hustle_composite <- z_sum
  hustle_rates$hustle_tier <- quartile_tier(hustle_rates$hustle_composite)

  tab %>% left_join(hustle_rates %>% select(-hustle_composite), by = "player_id")
}

#' Attach position from espn_player_core.csv, trying common column names
#' for both the player id and the position field.
add_position <- function(tab, espn_core) {
  if (is.null(espn_core)) return(tab %>% mutate(position = NA_character_))
  id_col  <- first_present(espn_core, c("player_id", "athlete_id"))
  pos_col <- first_present(espn_core, c("position", "athlete_position_name",
                                         "position_name", "pos"))
  if (is.na(id_col) || is.na(pos_col)) {
    message("  WARN: espn_player_core.csv missing a recognizable id/position column, skipping position")
    return(tab %>% mutate(position = NA_character_))
  }
  core_small <- espn_core %>%
    transmute(player_id = .data[[id_col]], position = .data[[pos_col]]) %>%
    distinct(player_id, .keep_all = TRUE)
  tab %>% left_join(core_small, by = "player_id")
}

#' Attach team tricode. Prefers espn_rosters.csv (current roster, catches
#' in-season trades); falls back to team_id already on the base stats
#' table, resolved via team_lookup.
add_team <- function(tab, espn_rosters, team_lookup) {
  lookup <- team_lookup %>% mutate(team_id = as.character(team_id)) %>%
    select(team_id, tricode) %>% distinct()

  if (!is.null(espn_rosters)) {
    id_col   <- first_present(espn_rosters, c("player_id", "athlete_id"))
    team_col <- first_present(espn_rosters, c("team_id", "team_abbreviation", "team", "tricode"))
    if (!is.na(id_col) && !is.na(team_col)) {
      roster_small <- espn_rosters %>%
        transmute(player_id = .data[[id_col]], roster_team = .data[[team_col]]) %>%
        distinct(player_id, .keep_all = TRUE)
      tab <- tab %>% left_join(roster_small, by = "player_id")
      # roster_team may already be a tricode, or a numeric team_id needing lookup
      tab <- tab %>%
        left_join(lookup, by = c("roster_team" = "team_id")) %>%
        mutate(team = coalesce(tricode, as.character(roster_team))) %>%
        select(-roster_team, -tricode)
      return(tab)
    }
    message("  WARN: espn_rosters.csv missing a recognizable id/team column, falling back to leaguedash team_id")
  }

  tab %>%
    mutate(team_id = as.character(team_id)) %>%
    left_join(lookup, by = "team_id") %>%
    mutate(team = tricode) %>%
    select(-tricode)
}

#' Optional per-game log for the split-half reliability diagnostic. wehoop's
#' season leaguedash cubes are totals, not per-game rows, so this needs a
#' separate gamelog export; tries a couple of likely filenames and returns
#' NULL (with a WARN) if none is found, in which case split-half is skipped.
find_gamelog <- function() {
  candidates <- c(
    file.path(DATA_DIR, "player_gamelogs.csv"),
    file.path(LIVE_DIR, "player_gamelogs.csv"),
    file.path(DATA_DIR, "wnba_player_box.csv")
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) return(NULL)
  hit[1]
}

#' Split-half (odd/even game) reliability of GmSc_per40, if a per-game log
#' is available. Returns list(r = NA, n = 0) with a WARN if not, so the
#' rest of the script does not depend on this file existing.
split_half_reliability <- function(eligible_ids) {
  path <- find_gamelog()
  if (is.null(path)) {
    message("  WARN: no per-game log file found (tried player_gamelogs.csv, ",
            "wnba_player_box.csv). Season leaguedash cubes are totals only, ",
            "so split-half reliability is skipped for this run.")
    return(list(r = NA_real_, n = 0L))
  }

  gl <- read_lower(path, required = FALSE)
  id_col <- first_present(gl, c("player_id", "athlete_id"))
  needed <- c("game_id", "min", "pts", "fgm", "fga", "ftm", "fta",
              "oreb", "dreb", "stl", "ast", "blk", "pf", "tov")
  missing_cols <- setdiff(needed, names(gl))
  if (is.na(id_col) || length(missing_cols) > 0) {
    message("  WARN: gamelog file found but missing id/box columns (",
            paste(missing_cols, collapse = ", "), "), skipping split-half")
    return(list(r = NA_real_, n = 0L))
  }

  pg <- gl %>%
    transmute(player_id = .data[[id_col]], game_id,
              minutes = min,
              gs = pts + 0.4 * fgm - 0.7 * fga - 0.4 * (fta - ftm) +
                0.7 * oreb + 0.3 * dreb + stl + 0.7 * ast + 0.7 * blk - 0.4 * pf - tov) %>%
    filter(player_id %in% eligible_ids, minutes >= 5) %>%
    mutate(rate = gs / (minutes / 40))

  halves <- pg %>%
    group_by(player_id) %>%
    arrange(game_id, .by_group = TRUE) %>%
    mutate(half = if_else(row_number() %% 2 == 1, "odd", "even")) %>%
    group_by(player_id, half) %>%
    summarise(rate_mean = mean(rate), n = n(), .groups = "drop")

  wide <- halves %>%
    pivot_wider(names_from = half, values_from = c(rate_mean, n)) %>%
    filter(!is.na(rate_mean_odd), !is.na(rate_mean_even), n_odd >= 3, n_even >= 3)

  if (nrow(wide) < 5) return(list(r = NA_real_, n = nrow(wide)))
  list(r = cor(wide$rate_mean_odd, wide$rate_mean_even), n = nrow(wide))
}

#' Flag box-score vs RAPM disagreement: high production tier with negative
#' RAPM is a red flag; low production tier with positive RAPM may be
#' undervalued. Only set where rapm_tier is non-missing (possession floor met).
add_box_rapm_flag <- function(tab) {
  tab %>%
    mutate(box_rapm_flag = case_when(
      is.na(rapm_tier) ~ NA_character_,
      production_tier %in% c("top", "upper rotation") & rapm < 0 ~
        "red flag: high box production, negative RAPM",
      production_tier %in% c("rotation", "fringe", "below threshold") & rapm > 0 ~
        "possible undervalue: modest box production, positive RAPM",
      TRUE ~ "consistent"
    ))
}

write_player_md <- function(tab, sh, path) {
  tier_order <- c("top", "upper rotation", "rotation", "fringe")

  section_for_tier <- function(tier) {
    rows <- tab %>%
      filter(production_tier == tier) %>%
      arrange(desc(gmsc_per40)) %>%
      transmute(player_name, team, position,
                gmsc_per40 = round(gmsc_per40, 2),
                rapm = round(rapm, 2), rapm_tier,
                box_rapm_flag)
    if (nrow(rows) == 0) return(character(0))
    c(
      sprintf("### %s (n=%d)", tier, nrow(rows)),
      "",
      paste0("| ", paste(names(rows), collapse = " | "), " |"),
      paste0("| ", paste(rep("---", ncol(rows)), collapse = " | "), " |"),
      apply(rows, 1, function(r) paste0("| ", paste(replace(r, is.na(r), ""), collapse = " | "), " |")),
      ""
    )
  }

  lines <- c(
    "# Player value screen (wehoop)",
    "",
    sprintf("Generated: %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    "Box-score production (Game Score per 40) is the SCREEN, not a ranking.",
    "Game Score weights are NBA-derived and unvalidated for the WNBA. RAPM is",
    "reported only where a player clears the 500-possession floor; below that",
    "rapm_tier is blank and the raw rapm number should be read with caution.",
    "",
    sprintf("Eligibility: minutes >= %d and FGA >= %d.", MIN_MINUTES, MIN_FGA),
    sprintf("Split-half reliability of gmsc_per40: r = %s (n = %d players)%s",
            ifelse(is.na(sh$r), "NA", round(sh$r, 2)), sh$n,
            ifelse(sh$n == 0, " -- no per-game log available for this run", "")),
    "",
    "A player who is 'top' or 'upper rotation' by box score but negative RAPM",
    "is a red flag worth a second look. A player who is 'rotation' or 'fringe'",
    "by box score but positive RAPM may be undervalued by the box-score screen.",
    ""
  )
  for (t in tier_order) lines <- c(lines, section_for_tier(t))

  writeLines(lines, path)
}

main <- function() {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

  lookup_path <- file.path(DATA_DIR, "team_lookup.rds")
  if (!file.exists(lookup_path)) {
    stop(sprintf("team_lookup.rds not found at %s. Run 17_wehoop_scaffold.R first.", lookup_path))
  }
  team_lookup <- readRDS(lookup_path)

  message("=== Loading player stats ===")
  base     <- read_lower(file.path(DATA_DIR, "leaguedash_player_stats_base.csv"))
  advanced <- read_lower(file.path(DATA_DIR, "leaguedash_player_stats_advanced.csv"))
  scoring  <- read_lower(file.path(DATA_DIR, "leaguedash_player_stats_scoring.csv"), required = FALSE)
  rapm     <- read_lower(file.path(LIVE_DIR, "rapm.csv"), required = FALSE)
  hustle   <- read_lower(file.path(LIVE_DIR, "hustle_player.csv"), required = FALSE)
  espn_core    <- read_lower(file.path(DATA_DIR, "espn_player_core.csv"), required = FALSE)
  espn_rosters <- read_lower(file.path(DATA_DIR, "espn_rosters.csv"), required = FALSE)

  message("=== Game Score ===")
  base <- base %>% mutate(player_id = as.character(player_id), team_id = as.character(team_id))
  tab <- add_game_score(base)
  message(sprintf("  %d players in base stats", nrow(tab)))

  message("=== Eligibility and production tiers ===")
  tab <- tab %>% mutate(eligible = min >= MIN_MINUTES & fga >= MIN_FGA)
  elig_rate <- rep(NA_real_, nrow(tab))
  elig_rate[tab$eligible] <- tab$gmsc_per40[tab$eligible]
  tab$production_tier <- quartile_tier(elig_rate)
  tab$production_tier[!tab$eligible] <- "below threshold"
  message(sprintf("  eligible players: %d (minutes>=%d, FGA>=%d)",
                   sum(tab$eligible), MIN_MINUTES, MIN_FGA))

  message("=== Advanced stats (ratings, TS%, USG%) ===")
  adv_cols <- c("player_id", "off_rating", "def_rating", "net_rating", "ts_pct", "usg_pct")
  missing_adv <- setdiff(adv_cols, names(advanced))
  if (length(missing_adv) > 0) {
    stop("leaguedash_player_stats_advanced.csv missing columns: ", paste(missing_adv, collapse = ", "))
  }
  adv_small <- advanced %>% mutate(player_id = as.character(player_id)) %>% select(all_of(adv_cols))
  tab <- tab %>% left_join(adv_small, by = "player_id")

  if (!is.null(scoring)) {
    message("  loaded leaguedash_player_stats_scoring.csv (context only, not in output columns)")
  }

  message("=== RAPM ===")
  tab <- add_rapm(tab, rapm)
  message(sprintf("  rapm_tier assigned to %d players (poss>=%d)",
                   sum(!is.na(tab$rapm_tier)), MIN_RAPM_POSS))

  message("=== Hustle profile ===")
  tab <- add_hustle(tab, hustle)

  message("=== Position ===")
  tab <- add_position(tab, espn_core)

  message("=== Team assignment ===")
  tab <- add_team(tab, espn_rosters, team_lookup)

  message("=== Split-half reliability ===")
  sh <- split_half_reliability(tab$player_id[tab$eligible])

  tab <- add_box_rapm_flag(tab)

  out <- tab %>%
    transmute(
      player_id, player_name, team, position,
      gp, minutes = min, gmsc_per40 = round(gmsc_per40, 3), production_tier,
      rapm = round(rapm, 3), o_rapm = round(o_rapm, 3), d_rapm = round(d_rapm, 3),
      rapm_tier,
      contested_shots_pg = round(contested_shots_pg, 2),
      deflections_pg = round(deflections_pg, 2),
      hustle_tier,
      off_rating, def_rating, net_rating, ts_pct, usg_pct
    ) %>%
    arrange(desc(gmsc_per40))

  write_csv(out, file.path(OUT_DIR, "player_value.csv"))
  write_player_md(tab %>% arrange(desc(gmsc_per40)), sh, file.path(OUT_DIR, "player_value.md"))

  message(sprintf(
    "\nWrote %s and %s",
    file.path(OUT_DIR, "player_value.csv"), file.path(OUT_DIR, "player_value.md")
  ))
  message("\nProduction tier counts:")
  print(table(out$production_tier, useNA = "ifany"))
  message("\nTop 15 eligible by gmsc_per40:")
  print(out %>% filter(production_tier != "below threshold") %>% slice_head(n = 15) %>%
          select(player_name, team, gmsc_per40, production_tier, rapm, rapm_tier),
        n = Inf)

  invisible(out)
}

if (sys.nframe() == 0) {
  main()
}
