# ==============================================================================
# 14_fit_targets.R -- fit-first target reads (the deliverable)
# ==============================================================================
#
# Purpose: the fit-first deliverable the R/13 value screen feeds. Per the
#   2026-07-22 design review (analytics-reviewer + gm-agent) and the handoff §5f
#   scope amendment, this shops in the order a front office actually works:
#     need (from R/08 / R/11)  ->  attainability (seller pool)  ->  affordability
#     (acquiring team's cap tier)  ->  value (R/13 production tier, as a filter).
#   Value is the LAST and least input, and it appears only as a coarse tier on
#   NAMED candidates. There is no league-wide value leaderboard here, no value/cost
#   ratio, no salary matching. Offense-scope only: a team whose deadline need is
#   defensive cannot be served by this layer.
#
# Verb obedience: the read for each team is conditioned on that team's own
#   deadline_read recommendation. Buy-side verbs (amplify / gap-fill, and a bubble
#   "lean buy") get a candidate shortlist; adjust gets a low-priority depth note;
#   reassess, seller, and hold/sell judgments get a deliberate no-list with the
#   reason. This keeps R/14 verb-for-verb consistent with output/deadline_read.md.
#
# Matching: candidates (eligible players on SELLER teams, for attainability) are
#   ranked by SHOT-PROFILE similarity to the acquiring team's own coarse profile
#   (rim / mid / three shares from the `area` field), i.e. "on-style depth that
#   protects the shot hierarchy," then by production tier. Coarse buckets only:
#   a 5-zone match would be noise at the player-claim FGA floor.
#
# Caveats (stated, not modeled):
#   - A candidate's shot profile reflects her CURRENT team's system; the assumption
#     that it travels to a new offense is a real assumption, disclosed not adjusted.
#   - Production tier is the offense-weighted, half-season box screen from R/13.
#   - Contract bands are hand-curated, attributed, tiers-not-dollars, named
#     candidates only (data/reference/candidate_contracts_2026.csv). This script
#     never fabricates them; it writes a template for hand-curation and gates
#     affordability only where a band has been filled.
#
# Inputs:  output/player_value.csv (R/13), output/standing.csv (R/12),
#            output/deadline_read.csv (R/08), data/processed/pbp_events.rds,
#            data/reference/candidate_contracts_2026.csv (hand-curated, optional).
# Outputs: output/fit_targets.md, output/fit_targets.csv, and (if missing) the
#            contract template data/reference/candidate_contracts_2026.csv.
#
# Guardrails: reproducible open data only; no Synergy; no dollars; language hygiene.
#   Exploratory layer, no hypothesis test (PLAN.md addendum).
# ==============================================================================

suppressMessages(library(tidyverse))

proj_path <- function(...) {
  here <- tryCatch(rprojroot::find_root(rprojroot::has_file("README.md")),
                   error = function(e) getwd())
  file.path(here, ...)
}

N_SHORTLIST <- 5   # candidates per buy-side team

# ---- load --------------------------------------------------------------------
pv       <- read_csv(proj_path("output", "player_value.csv"), show_col_types = FALSE)
standing <- read_csv(proj_path("output", "standing.csv"), show_col_types = FALSE)
dread    <- read_csv(proj_path("output", "deadline_read.csv"), show_col_types = FALSE)
pbp      <- readRDS(proj_path("data", "processed", "pbp_events.rds"))

# ------------------------------------------------------------------------------
# 1. coarse shot profiles (rim / mid / three) for players and teams
# ------------------------------------------------------------------------------
#' Coarse shot-bucket shares from the `area` field.
#' rim = Restricted Area; mid = In The Paint (Non-RA) + Mid-Range; three = any 3.
#' @param df tibble of shot events (actionType 2pt/3pt with `area`)
#' @return tibble grouped by `key` with rim_share/mid_share/three_share, n_shots
coarse_profile <- function(df, key) {
  df %>%
    filter(actionType %in% c("2pt", "3pt")) %>%
    mutate(bucket = case_when(
      actionType == "3pt" ~ "three",              # three defined by shot type, not area
      area == "Restricted Area" ~ "rim",
      area %in% c("In The Paint (Non-RA)", "Mid-Range") ~ "mid",
      TRUE ~ NA_character_                          # unexpected/NA-area 2pt: drop, do not mislabel
    )) %>%
    filter(!is.na(bucket)) %>%
    group_by(across(all_of(key)), bucket) %>%
    summarise(n = n(), .groups = "drop") %>%
    group_by(across(all_of(key))) %>%
    mutate(share = n / sum(n), n_shots = sum(n)) %>%
    ungroup() %>%
    select(all_of(key), bucket, share, n_shots) %>%
    pivot_wider(names_from = bucket, values_from = share, values_fill = 0,
                names_glue = "{bucket}_share")
}

pev <- pbp %>% filter(!is.na(personId), personId != 0, !is.na(playerName))

player_profile <- coarse_profile(pev, "personId")
team_profile   <- coarse_profile(pbp %>% filter(!is.na(teamTricode)), "teamTricode") %>%
  rename(team = teamTricode)

# ------------------------------------------------------------------------------
# 2. candidate pool: eligible players on seller teams (attainability)
# ------------------------------------------------------------------------------
seller_teams <- standing %>% filter(window == "seller") %>% pull(team)

candidates <- pv %>%
  filter(eligible, team %in% seller_teams) %>%
  left_join(player_profile, by = "personId") %>%
  select(personId, playerName, current_team = team, production_tier, vor,
         games, minutes, rim_share, mid_share, three_share)

# ------------------------------------------------------------------------------
# 3. per-team action category from the deadline_read recommendation verb
# ------------------------------------------------------------------------------
#' Map a recommendation string to an action category and whether it gets a list.
classify_action <- function(rec) {
  case_when(
    str_starts(rec, "amplify")            ~ "amplify",
    str_starts(rec, "gap-fill")           ~ "gap-fill",
    str_starts(rec, "reassess")           ~ "reassess",
    str_starts(rec, "adjust")             ~ "adjust",
    str_starts(rec, "sell")               ~ "seller",
    str_detect(rec, "judgment \\(lean buy") ~ "buy-judgment",
    TRUE                                  ~ "hold-judgment"
  )
}

teams <- dread %>%
  transmute(team, window, recommendation,
            action = classify_action(recommendation)) %>%
  left_join(team_profile, by = "team")

# buy-side verbs get a shortlist; adjust is low-priority depth; the rest get none
gets_list  <- c("amplify", "gap-fill", "buy-judgment", "adjust")
tier_order <- c(top = 4, `upper rotation` = 3, rotation = 2, fringe = 1)

#' Rank the candidate pool for one acquiring team: on-style as a GATE (fit first),
#' then production tier and value WITHIN the on-style set (value as the within-fit
#' ranker, not the driver). At coarse rim/mid/three granularity style_match barely
#' discriminates, so leading with it would surface the single closest-style fringe
#' player over a top producer who also fits; gating on it and ranking by tier
#' inside the gate is what "on-style depth that protects the hierarchy" means.
rank_for_team <- function(t_rim, t_mid, t_three, action) {
  scored <- candidates %>%
    mutate(
      style_match = 1 - 0.5 * (abs(rim_share - t_rim) + abs(mid_share - t_mid) +
                                 abs(three_share - t_three)),
      tier_rank = tier_order[production_tier]
    )
  # adjust teams (offense is not the lever) get on-style DEPTH, not another star:
  # cap at upper rotation so the "low-priority depth" label stays honest (Wendy,
  # 2026-07-23). Amplify / buy-judgment keep top-tier candidates.
  if (identical(action, "adjust")) {
    scored <- scored %>% filter(production_tier != "top")
  }
  # on-style gate: keep the more on-style half of the pool for this team
  gate <- quantile(scored$style_match, 0.5, na.rm = TRUE)
  scored %>%
    filter(style_match >= gate) %>%
    arrange(desc(tier_rank), desc(vor), desc(style_match)) %>%
    slice_head(n = N_SHORTLIST)
}

shortlists <- teams %>%
  filter(action %in% gets_list) %>%
  rowwise() %>%
  mutate(picks = list(rank_for_team(rim_share, mid_share, three_share, action))) %>%
  ungroup()

# ------------------------------------------------------------------------------
# 4. contract-band template (hand-curated, named candidates only)
# ------------------------------------------------------------------------------
ref_path <- proj_path("data", "reference", "candidate_contracts_2026.csv")
shortlisted_ids <- shortlists %>% pull(picks) %>% bind_rows() %>%
  distinct(personId, playerName, current_team)

# Template carries contract_band AND movability (expiring / core / untouchable), both
# hand-curated with source + as_of_date. Movability screens the attainability gap the
# gm-agent flagged: a top player on an expansion seller is not actually available.
if (!file.exists(ref_path)) {
  shortlisted_ids %>%
    mutate(contract_band = NA_character_, movability = NA_character_,
           source = NA_character_, as_of_date = NA_character_) %>%
    arrange(current_team, playerName) %>%
    write_csv(ref_path)
  contracts <- tibble(personId = numeric(), contract_band = character(),
                      movability = character(), source = character(),
                      as_of_date = character())
  ref_created <- TRUE
} else {
  ref_cols <- read_csv(ref_path, show_col_types = FALSE)
  if (!"movability" %in% names(ref_cols)) ref_cols$movability <- NA_character_
  contracts <- ref_cols %>%
    select(personId, contract_band, movability, source, as_of_date)
  ref_created <- FALSE
}

# acquiring-team flexibility tier from cap_context; only min/depth bands are
# affordable for capped/tight teams (gate applied only where a band is filled)
cap_tier <- dread %>% transmute(team, flex = cap_context)
affordable_bands_for <- function(flex) {
  if (identical(flex, "room")) return(c("min", "mid", "max"))
  if (identical(flex, "tight")) return(c("min", "mid"))
  c("min")  # capped
}

# ------------------------------------------------------------------------------
# 5. assemble long table + markdown
# ------------------------------------------------------------------------------
long <- shortlists %>%
  select(team, window, action, recommendation, picks) %>%
  unnest(picks) %>%
  left_join(contracts, by = "personId") %>%
  left_join(cap_tier, by = "team") %>%
  rowwise() %>%
  mutate(
    affordability = if (is.na(contract_band)) "band: hand-curate"
      else if (contract_band %in% affordable_bands_for(flex)) paste0("affordable (", flex, ")")
      else paste0("over-tier (", flex, " cannot absorb ", contract_band, ")"),
    movability_disp = if (is.na(movability)) "movability: hand-curate" else movability,
    profile = sprintf("rim %.0f / mid %.0f / three %.0f",
                      100 * rim_share, 100 * mid_share, 100 * three_share)
  ) %>%
  ungroup()

write_csv(
  long %>% select(team, window, action, personId, playerName, current_team,
                  production_tier, games, minutes, vor, style_match, profile,
                  contract_band, movability, affordability),
  proj_path("output", "fit_targets.csv")
)

# markdown, one block per acquiring team (all 15, in a sensible order)
action_order <- c(amplify = 1, `gap-fill` = 2, `buy-judgment` = 3, adjust = 4,
                  `hold-judgment` = 5, reassess = 6, seller = 7)
md <- c(
  "# Fit-first target reads (R/14)",
  "",
  "The value screen (R/13) is a filter here, not the driver. Reads shop in order:",
  "need, then attainability (candidate pool is the sellers only), then affordability",
  "(the acquiring team's cap tier), then production tier. Offense-scope only.",
  "",
  "Read the following before acting on any row:",
  "- style_match is a COARSE on-style gate (rim / mid / three shares), not a precise",
  "  ranker. It is used only to keep the more on-style half of the pool; do not read",
  "  the second decimal, and note it is not the deadline_read identity descriptor.",
  "- A candidate's shot profile reflects her CURRENT team's system; that it travels",
  "  to a new offense is an assumption, disclosed not modeled.",
  "- Affordability is PENDING until the contract bands are hand-curated (v1 ships with",
  "  them blank). Contract bands and movability are hand-curated, attributed, tiers",
  "  not dollars.",
  "- Movability is NOT yet screened: a top-tier player on an expansion or rebuilding",
  "  seller may not actually be available. Hand-curate the movability flag before use.",
  "- ASSET COST (what the acquiring team sends out) is entirely out of scope here; the",
  "  affordability column is salary tier only. A top-tier candidate at a min band still",
  "  costs real assets.",
  "- Rim-heavy sellers (centers) may be absent from perimeter teams' on-style lists by",
  "  construction; that is the style gate working, not a data gap.",
  "- Production tiers are the offense-weighted, half-season box screen from R/13; small",
  "  samples are flagged by the games count on each line.",
  "",
  paste0("Candidate pool (sellers): ", paste(sort(seller_teams), collapse = ", "), "."),
  ""
)

team_block <- function(row) {
  hdr <- sprintf("## %s (%s -- %s)", row$team, row$window, row$action)
  rec <- paste0("Recommendation: ", row$recommendation)
  if (!(row$action %in% gets_list)) {
    reason <- case_when(
      row$action == "reassess" ~ "No target list: address the shot diet / identity before spending an asset.",
      row$action == "seller" ~ "No target list: seller. This team is a source of candidates, not a buyer.",
      TRUE ~ "No target list: the World Cup break favors hold-and-reassess unless the trajectory is clearly improving."
    )
    return(c(hdr, "", rec, "", reason, ""))
  }
  note <- if (row$action == "adjust") {
    "Low-priority depth only: offense is roughly league-average and is not the primary lever."
  } else if (row$action == "buy-judgment") {
    "Tentative (bubble lean-buy): pursue only if the deal is clearly on-style and affordable."
  } else {
    "On-style depth that protects the shot hierarchy:"
  }
  picks <- long %>% filter(team == row$team) %>%
    mutate(line = sprintf("- %s (%s, %s, %d g / %d min) -- %s; on-style %.1f; %s; %s",
                          playerName, current_team, production_tier, games,
                          round(minutes), profile, style_match, affordability,
                          movability_disp))
  c(hdr, "", rec, "", note, "", picks$line, "")
}

ordered_teams <- teams %>% mutate(ord = action_order[action]) %>% arrange(ord, team)
for (i in seq_len(nrow(ordered_teams))) {
  md <- c(md, team_block(ordered_teams[i, ]))
}

writeLines(md, proj_path("output", "fit_targets.md"))

# ------------------------------------------------------------------------------
# 6. console summary
# ------------------------------------------------------------------------------
cat("=== R/14 fit-first target reads ===\n")
cat("seller candidate pool:", nrow(candidates), "eligible players on",
    length(seller_teams), "seller teams\n")
cat("teams with a shortlist:",
    paste(shortlists$team, collapse = ", "), "\n")
if (ref_created) {
  cat("WROTE contract template:", ref_path,
      "(", nrow(shortlisted_ids), "named candidates, bands blank -- hand-curate)\n")
} else {
  have_band <- contracts %>% filter(!is.na(contract_band)) %>% pull(personId)
  missing <- setdiff(shortlisted_ids$personId, have_band)
  cat("contract template exists;", length(missing), "of", nrow(shortlisted_ids),
      "shortlisted candidates still need a band\n")
}
cat("\nWrote output/fit_targets.md and output/fit_targets.csv\n")
cat("\n=== shortlists ===\n")
long %>% select(team, playerName, current_team, production_tier, style_match, affordability) %>%
  as.data.frame() %>% print(row.names = FALSE)
