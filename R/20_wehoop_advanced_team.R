# 20_wehoop_advanced_team.R
#
# Purpose: New analysis layer with no CDN-pipeline equivalent. Builds a
#   team-level advanced-stats profile (four factors, ratings, hustle) from
#   the wehoop leaguedash cubes, with z-scored ranks and per-team strength/
#   weakness and primary-four-factor reads.
#
# Inputs:  data/wehoop/leaguedash_team_stats_advanced.csv
#          data/wehoop/leaguedash_team_stats_fourfactors.csv
#          data/wehoop/live/hustle_team.csv
#          data/wehoop/leaguedash_team_stats_base.csv (context only)
#          data/wehoop/team_lookup.rds (from 17_wehoop_scaffold.R)
# Outputs: output/wehoop/team_advanced_profile.csv
#          output/wehoop/team_advanced_profile.md

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
})

DATA_DIR <- file.path("data", "wehoop")
LIVE_DIR <- file.path(DATA_DIR, "live")
OUT_DIR  <- file.path("output", "wehoop")

# metric direction: TRUE = higher is better
RATING_METRICS <- c(
  off_rating = TRUE, def_rating = FALSE, net_rating = TRUE,
  pace = TRUE, pie = TRUE
)
FOUR_FACTOR_METRICS <- c(
  efg_pct = TRUE, tm_tov_pct = FALSE, oreb_pct = TRUE, fta_rate = TRUE
)
HUSTLE_METRICS <- c(
  contested_shots_pg = TRUE, deflections_pg = TRUE, loose_balls_pg = TRUE,
  screen_assists_pg = TRUE, box_outs_pg = TRUE
)
ALL_METRICS <- c(RATING_METRICS, FOUR_FACTOR_METRICS, HUSTLE_METRICS)

#' Read a csv and lowercase its names so official-stats columns
#' (TEAM_ID, OFF_RATING) line up with live/ columns already snake_case.
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

#' Join the leaguedash cubes and hustle_team on team_id, attach tricode from
#' team_lookup, and compute hustle per-game rates.
#'
#' @return tibble, one row per team
build_team_table <- function(advanced, fourfactors, hustle, team_lookup) {
  advanced <- advanced %>% mutate(team_id = as.character(team_id))
  fourfactors <- fourfactors %>% mutate(team_id = as.character(team_id))
  hustle <- hustle %>% mutate(team_id = as.character(team_id))
  lookup <- team_lookup %>% mutate(team_id = as.character(team_id)) %>%
    select(team_id, tricode, team_name) %>% distinct()

  adv_cols <- c("team_id", "off_rating", "def_rating", "net_rating", "pace", "pie", "gp")
  missing_adv <- setdiff(adv_cols, names(advanced))
  if (length(missing_adv) > 0) {
    stop("build_team_table(): leaguedash_team_stats_advanced.csv missing columns: ",
         paste(missing_adv, collapse = ", "))
  }

  ff_cols <- c("team_id", "efg_pct", "fta_rate", "tm_tov_pct", "oreb_pct")
  missing_ff <- setdiff(ff_cols, names(fourfactors))
  if (length(missing_ff) > 0) {
    stop("build_team_table(): leaguedash_team_stats_fourfactors.csv missing columns: ",
         paste(missing_ff, collapse = ", "))
  }

  hustle_needed <- c("team_id", "contested_shots", "deflections",
                      "loose_balls_recovered", "screen_assists", "box_outs", "gp")
  missing_hustle <- setdiff(hustle_needed, names(hustle))
  if (length(missing_hustle) > 0) {
    stop("build_team_table(): hustle_team.csv missing columns: ",
         paste(missing_hustle, collapse = ", "))
  }

  adv_small <- advanced %>% select(all_of(adv_cols))
  ff_small  <- fourfactors %>% select(all_of(ff_cols))
  hustle_rates <- hustle %>%
    transmute(
      team_id,
      contested_shots_pg = contested_shots / gp,
      deflections_pg = deflections / gp,
      loose_balls_pg = loose_balls_recovered / gp,
      screen_assists_pg = screen_assists / gp,
      box_outs_pg = box_outs / gp
    )

  tab <- adv_small %>%
    left_join(ff_small, by = "team_id") %>%
    left_join(hustle_rates, by = "team_id") %>%
    left_join(lookup, by = "team_id")

  unresolved <- tab %>% filter(is.na(tricode)) %>% pull(team_id)
  if (length(unresolved) > 0) {
    message("  WARN: team_id(s) not resolved to a tricode via team_lookup.rds: ",
            paste(unresolved, collapse = ", "))
  }

  tab
}

#' Add rank_<metric> and z_<metric> columns for every metric in `metrics`
#' (a named vector, name = column, value = TRUE if higher is better).
#' Lower-is-better metrics get their z-score negated so positive always
#' means "better" across every dimension.
add_ranks_and_z <- function(df, metrics) {
  for (m in names(metrics)) {
    higher_better <- metrics[[m]]
    x <- df[[m]]
    rank_col <- paste0("rank_", m)
    z_col <- paste0("z_", m)
    df[[rank_col]] <- if (higher_better) rank(-x, ties.method = "min", na.last = "keep")
                       else rank(x, ties.method = "min", na.last = "keep")
    z <- as.numeric(scale(x))
    df[[z_col]] <- if (higher_better) z else -z
  }
  df
}

#' Two strongest and two weakest dimensions per team, by z-score, across
#' every metric in ALL_METRICS.
add_strength_weakness <- function(df) {
  z_cols <- paste0("z_", names(ALL_METRICS))
  z_cols <- intersect(z_cols, names(df))
  labels <- sub("^z_", "", z_cols)
  zmat <- as.matrix(df[z_cols])

  picks <- map_dfr(seq_len(nrow(zmat)), function(i) {
    ord <- order(zmat[i, ], decreasing = TRUE, na.last = NA)
    tibble(
      strength_1 = labels[ord[1]], strength_2 = labels[ord[2]],
      weakness_1 = labels[ord[length(ord)]], weakness_2 = labels[ord[length(ord) - 1]]
    )
  })
  bind_cols(df, picks)
}

#' Which of the four factors is most extreme (largest |z|) for each team,
#' as a simple proxy for "most explains offensive rating relative to
#' league average."
add_primary_factor <- function(df) {
  ff_z <- paste0("z_", names(FOUR_FACTOR_METRICS))
  ff_labels <- names(FOUR_FACTOR_METRICS)
  mat <- as.matrix(df[ff_z])
  idx <- apply(abs(mat), 1, which.max)
  df$primary_factor <- ff_labels[idx]
  df
}

fmt_num <- function(x, digits = 1) formatC(x, format = "f", digits = digits)

#' Formatted markdown report: offensive ratings, defensive ratings, four
#' factors, hustle profile, each with interpretive notes.
write_team_md <- function(df, path) {
  df <- df %>% arrange(rank_net_rating)

  ratings_tab <- df %>%
    transmute(tricode, off_rating = fmt_num(off_rating),
              rank_off = rank_off_rating,
              def_rating = fmt_num(def_rating), rank_def = rank_def_rating,
              net_rating = fmt_num(net_rating), rank_net = rank_net_rating,
              pace = fmt_num(pace)) %>%
    select(tricode, off_rating, rank_off, def_rating, rank_def, net_rating, rank_net, pace)

  ff_tab <- df %>%
    transmute(tricode, efg_pct = fmt_num(efg_pct, 3), fta_rate = fmt_num(fta_rate, 3),
              tm_tov_pct = fmt_num(tm_tov_pct, 3), oreb_pct = fmt_num(oreb_pct, 3),
              primary_factor)

  hustle_tab <- df %>%
    transmute(tricode, contested_shots_pg = fmt_num(contested_shots_pg),
              deflections_pg = fmt_num(deflections_pg),
              loose_balls_pg = fmt_num(loose_balls_pg),
              screen_assists_pg = fmt_num(screen_assists_pg),
              box_outs_pg = fmt_num(box_outs_pg))

  sw_tab <- df %>% select(tricode, strength_1, strength_2, weakness_1, weakness_2)

  lines <- c(
    "# Team advanced profile (wehoop)",
    "",
    sprintf("Generated: %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    "## Offensive and defensive ratings",
    "",
    "OFF_RATING / DEF_RATING are points scored / allowed per 100 possessions;",
    "NET_RATING is the difference. PACE is possessions per 48 minutes.",
    "Rank 1 is best in each column.",
    "",
    paste0("| ", paste(names(ratings_tab), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(ratings_tab)), collapse = " | "), " |"),
    apply(ratings_tab, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")),
    "",
    "## Four factors",
    "",
    "EFG_PCT (shooting efficiency), TM_TOV_PCT (turnover rate, lower is better),",
    "OREB_PCT (offensive rebound rate), FTA_RATE (free-throw rate). primary_factor",
    "is the factor with the most extreme z-score for that team, a rough read on",
    "what is driving its offensive profile relative to the league.",
    "",
    paste0("| ", paste(names(ff_tab), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(ff_tab)), collapse = " | "), " |"),
    apply(ff_tab, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")),
    "",
    "## Hustle profile",
    "",
    "Per-game rates from hustle_team.csv: contested shots, deflections, loose",
    "balls recovered, screen assists, box outs. These are activity-level, not",
    "outcome, stats -- useful for reading effort and role fit, not efficiency.",
    "",
    paste0("| ", paste(names(hustle_tab), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(hustle_tab)), collapse = " | "), " |"),
    apply(hustle_tab, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")),
    "",
    "## Strengths and weaknesses",
    "",
    "Two highest and two lowest z-scored dimensions per team, across ratings,",
    "four factors, and hustle rates (14 dimensions total). Lower-is-better",
    "metrics (DEF_RATING, TM_TOV_PCT) are sign-flipped so positive always",
    "means better. A team whose weaknesses cluster in hustle dimensions reads",
    "differently for playoff readiness than one whose weaknesses are on",
    "efficiency (EFG_PCT, TS_PCT-adjacent) or turnover control.",
    "",
    paste0("| ", paste(names(sw_tab), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(sw_tab)), collapse = " | "), " |"),
    apply(sw_tab, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  )

  writeLines(unlist(lines), path)
}

main <- function() {
  dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

  lookup_path <- file.path(DATA_DIR, "team_lookup.rds")
  if (!file.exists(lookup_path)) {
    stop(sprintf("team_lookup.rds not found at %s. Run 17_wehoop_scaffold.R first.", lookup_path))
  }
  team_lookup <- readRDS(lookup_path)

  message("=== Loading team cubes ===")
  advanced    <- read_lower(file.path(DATA_DIR, "leaguedash_team_stats_advanced.csv"))
  fourfactors <- read_lower(file.path(DATA_DIR, "leaguedash_team_stats_fourfactors.csv"))
  hustle      <- read_lower(file.path(LIVE_DIR, "hustle_team.csv"))
  base_box    <- read_lower(file.path(DATA_DIR, "leaguedash_team_stats_base.csv"), required = FALSE)

  message("=== Joining and computing hustle rates ===")
  tab <- build_team_table(advanced, fourfactors, hustle, team_lookup)
  message(sprintf("  %d teams in profile", nrow(tab)))

  if (!is.null(base_box)) {
    base_cols <- intersect(c("team_id", "pts", "reb", "ast"), names(base_box))
    if (length(base_cols) > 1 && "gp" %in% names(base_box)) {
      base_pg <- base_box %>%
        mutate(team_id = as.character(team_id)) %>%
        transmute(team_id,
                  pts_pg = if ("pts" %in% names(base_box)) pts / gp else NA_real_,
                  reb_pg = if ("reb" %in% names(base_box)) reb / gp else NA_real_,
                  ast_pg = if ("ast" %in% names(base_box)) ast / gp else NA_real_)
      tab <- tab %>% left_join(base_pg, by = "team_id")
      message("  attached pts_pg/reb_pg/ast_pg context from leaguedash_team_stats_base.csv")
    }
  }

  message("=== Ranking and z-scoring ===")
  tab <- add_ranks_and_z(tab, ALL_METRICS)
  tab <- add_strength_weakness(tab)
  tab <- add_primary_factor(tab)

  out <- tab %>% arrange(rank_net_rating)

  write_csv(out, file.path(OUT_DIR, "team_advanced_profile.csv"))
  write_team_md(out, file.path(OUT_DIR, "team_advanced_profile.md"))

  message(sprintf(
    "\nWrote %s and %s",
    file.path(OUT_DIR, "team_advanced_profile.csv"),
    file.path(OUT_DIR, "team_advanced_profile.md")
  ))

  message("\nNet rating leaders:")
  print(out %>% select(tricode, off_rating, def_rating, net_rating, rank_net_rating) %>%
          arrange(rank_net_rating), n = Inf)

  invisible(out)
}

if (sys.nframe() == 0) {
  main()
}
