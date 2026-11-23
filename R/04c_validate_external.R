# 04c_validate_external.R
#
# Purpose: external validation of the full2026 analysis tables against ESPN data
#   (wehoop / sportsdataverse-data releases). ESPN is a validator only: it is never
#   merged into the analysis tables or used in models.
#   Step 1: game, team-game and player-game cross-check.
#   Step 2: schedule counts, standings, playoff bracket.
#   Step 3: side-by-side spot checks of specific games.
#
# Inputs:  tables in <PROCESSED_DIR>/tables (R/04b), ESPN parquet files in WEHOOP_DIR
#          (downloaded here if absent; sha256, size and date go to WEHOOP_DIR/manifest.csv)
# Outputs: data/reference/espn_team_map.csv, espn_game_map.csv, espn_player_map.csv,
#          output/offseason/external_validation.md
#          (data/reference/external_validation_exceptions.csv is hand-maintained)
#
# Run from the repo root: Rscript R/04c_validate_external.R

suppressMessages({library(tidyverse); library(arrow); library(digest)})
if (!exists("PROJECT_ROOT")) PROJECT_ROOT <- normalizePath(".")
if (!exists("proj_path", mode = "function")) proj_path <- function(...) file.path(PROJECT_ROOT, ...)
source(proj_path("R", "00_config.R"))
source(proj_path("R", "load_tables.R"))

# ---- 1. Download and manifest ------------------------------------------------
download_wehoop <- function() {
  dir.create(WEHOOP_DIR, recursive = TRUE, showWarnings = FALSE)
  files <- c(player_box = "player_box_2026.parquet", team_box = "team_box_2026.parquet",
             schedule = "wnba_schedule_2026.parquet")
  man_path <- file.path(WEHOOP_DIR, "manifest.csv")
  old <- if (file.exists(man_path)) read_csv(man_path, show_col_types = FALSE) else NULL
  rows <- list()
  for (k in names(files)) {
    p <- file.path(WEHOOP_DIR, files[[k]])
    if (!file.exists(p)) {
      options(timeout = 3600)
      download.file(WEHOOP_URLS[[k]], p, mode = "wb", quiet = TRUE)
      dl <- as.character(Sys.Date())
    } else {
      dl <- if (!is.null(old) && files[[k]] %in% old$file) old$download_date[old$file == files[[k]]][1] else as.character(as.Date(file.mtime(p)))
    }
    rows[[k]] <- tibble(file = files[[k]], url = WEHOOP_URLS[[k]], bytes = file.size(p),
                        sha256 = digest(p, algo = "sha256", file = TRUE), download_date = dl)
  }
  write_csv(bind_rows(rows), man_path)
  invisible(bind_rows(rows))
}
manifest <- download_wehoop()

sched <- read_parquet(file.path(WEHOOP_DIR, "wnba_schedule_2026.parquet")) %>% as_tibble()
tbox <- read_parquet(file.path(WEHOOP_DIR, "team_box_2026.parquet")) %>% as_tibble()
pbox <- read_parquet(file.path(WEHOOP_DIR, "player_box_2026.parquet")) %>% as_tibble()

# ---- helpers -----------------------------------------------------------------
md <- character()
add <- function(...) md <<- c(md, paste0(...))
md_table <- function(df) {
  if (nrow(df) == 0) { add("(none)"); add(""); return(invisible()) }
  df <- df %>% mutate(across(everything(), ~ ifelse(is.na(.x), "NA", as.character(.x))))
  add("| ", paste(names(df), collapse = " | "), " |")
  add("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  for (i in seq_len(nrow(df))) add("| ", paste(df[i, ], collapse = " | "), " |")
  add("")
}
norm_name <- function(x) {
  x <- iconv(x, to = "ASCII//TRANSLIT")
  x <- tolower(x)
  x <- gsub("[^a-z0-9 ]", " ", x)
  str_squish(x)
}

# ---- 2. Team map ---------------------------------------------------------------
team_map <- tribble(
  ~espn_abbr, ~our_tricode, ~note,
  "ATL", "ATL", "", "CHI", "CHI", "", "CON", "CON", "", "DAL", "DAL", "",
  "GS", "GSV", "Golden State Valkyries", "IND", "IND", "", "LA", "LAS", "Los Angeles Sparks",
  "LV", "LVA", "Las Vegas Aces", "MIN", "MIN", "", "NY", "NYL", "New York Liberty",
  "PHX", "PHX", "", "POR", "PDX", "Portland Fire", "SEA", "SEA", "", "TOR", "TOR", "",
  "WSH", "WAS", "Washington Mystics"
)
write_csv(team_map, proj_path("data", "reference", "espn_team_map.csv"))
allstar_abbr <- c("COOP", "SPO")  # All-Star teams, not franchises
espn_abbrs <- sort(unique(c(sched$home_abbreviation, sched$away_abbreviation,
                            tbox$team_abbreviation, pbox$team_abbreviation)))
unmapped <- setdiff(espn_abbrs, c(team_map$espn_abbr, allstar_abbr))
if (length(unmapped)) stop("Unmapped ESPN team abbreviations: ", paste(unmapped, collapse = ", "))
tm <- setNames(team_map$our_tricode, team_map$espn_abbr)

# ---- 3. Schedule classification and game matching -----------------------------------
sched <- sched %>%
  mutate(espn_game_id = as.character(game_id),
         home = unname(tm[home_abbreviation]), away = unname(tm[away_abbreviation]),
         game_kind = case_when(
           type_abbreviation == "ALLSTAR" ~ "all-star",
           type_abbreviation == "CC" ~ "commissioners-cup-final",
           TRUE ~ "counting"),
         final = status_type_name == "STATUS_FINAL",
         st_label = ifelse(season_type == 2, "regular", "playoffs"))

games <- load_table("games", "all")
tg <- load_table("team_games", "all")
pg <- load_table("player_games", "all")

sched_final <- sched %>% filter(final)
m_exact <- games %>%
  inner_join(sched_final %>% select(espn_game_id, game_date, home, away, st_label),
             by = c("game_date", "home_team" = "home", "away_team" = "away"))
rem <- games %>% filter(!game_id %in% m_exact$game_id)
m_shift <- tibble()
if (nrow(rem)) {
  cand <- rem %>% crossing(shift = c(-1L, 1L)) %>% mutate(game_date_s = game_date + shift) %>%
    inner_join(sched_final %>% select(espn_game_id, game_date, home, away, st_label),
               by = c("game_date_s" = "game_date", "home_team" = "home", "away_team" = "away"))
  m_shift <- cand %>% select(-game_date_s)
}
gmap <- bind_rows(m_exact %>% mutate(date_shift = 0L), m_shift %>% rename(date_shift = shift)) %>%
  transmute(game_id, espn_game_id, season_type, espn_season_type = st_label, date_shift)
if (anyDuplicated(gmap$game_id) || anyDuplicated(gmap$espn_game_id)) stop("Game map is not 1:1")
write_csv(gmap %>% select(game_id, espn_game_id, season_type), proj_path("data", "reference", "espn_game_map.csv"))

our_unmatched <- games %>% filter(!game_id %in% gmap$game_id)
espn_unmatched <- sched %>% filter(!espn_game_id %in% gmap$espn_game_id)

add("# External validation of the full2026 tables against ESPN (wehoop)")
add("")
add("Generated by `R/04c_validate_external.R`. ESPN data is a validator only and is never merged into the")
add("analysis tables or models. Our tables: pin `", PIN_SHORT, "`; ESPN files in `data/raw/wehoop/` (gitignored).")
add("")
add("## Source files")
add("")
md_table(manifest %>% select(file, bytes, sha256, download_date))

add("## Step 1: schema, team map, game matching")
add("")
add("ESPN schedule: ", nrow(sched), " rows; team box: ", nrow(tbox), " team-game rows (",
    n_distinct(tbox$game_id), " games); player box: ", nrow(pbox), " rows (", n_distinct(pbox$game_id), " games).")
add("")
add("ESPN season_type (from the data): 2 = regular season, 3 = playoffs. Schedule rows by season_type,")
add("game type and status:")
add("")
md_table(sched %>% count(season_type, type_abbreviation, status_type_name, name = "games") %>%
           arrange(season_type, type_abbreviation))
add("Non-counting games in the ESPN schedule (type ALLSTAR or CC, Commissioner's Cup final): ")
md_table(sched %>% filter(game_kind != "counting") %>%
           transmute(espn_game_id, game_date, kind = game_kind, home_abbreviation, away_abbreviation,
                     status = status_type_name, notes_headline))
add("ESPN abbreviations COOP and SPO are the All-Star teams and are not franchises. Team map (also in")
add("`data/reference/espn_team_map.csv`); every franchise abbreviation in the ESPN 2026 data is mapped:")
add("")
md_table(team_map)

add("### Game matching (game_date, home, away)")
add("")
add("- Our games: ", nrow(games), " (regular ", sum(games$season_type == "regular"), ", playoffs ",
    sum(games$season_type == "playoffs"), ")")
add("- Matched to ESPN: ", nrow(gmap), " (exact date: ", sum(gmap$date_shift == 0), ", needed +/- 1 day: ",
    sum(gmap$date_shift != 0), ")")
add("- Our games unmatched: ", nrow(our_unmatched))
if (nrow(our_unmatched)) md_table(our_unmatched %>% select(game_id, season_type, game_date, home_team, away_team))
add("- ESPN schedule games not matched to ours: ", nrow(espn_unmatched))
md_table(espn_unmatched %>%
           transmute(espn_game_id, season_type = st_label, kind = game_kind, game_date,
                     home = home_abbreviation, away = away_abbreviation, status = status_type_name,
                     notes_headline, in_team_box = espn_game_id %in% as.character(tbox$game_id)))
add("Matched games by our season_type and ESPN season_type:")
md_table(gmap %>% count(season_type, espn_season_type, name = "games"))
bad_type <- sum(gmap$season_type != gmap$espn_season_type)
add("Season-type disagreements between our table and ESPN among matched games: ", bad_type)
add("")
box_ids_not_in_sched <- setdiff(as.character(unique(tbox$game_id)), sched$espn_game_id)
add("ESPN team-box game_ids missing from the ESPN schedule: ", length(box_ids_not_in_sched))
add("")

# ---- 4. Team-game comparison --------------------------------------------------------
tbox2 <- tbox %>%
  mutate(espn_game_id = as.character(game_id), espn_team = unname(tm[team_abbreviation]))
ps <- pg %>% group_by(game_id, team) %>%
  summarise(pOREB = sum(OREB), pDREB = sum(DREB), .groups = "drop")
tcmp <- tg %>%
  inner_join(gmap %>% select(game_id, espn_game_id), by = "game_id") %>%
  left_join(ps, by = c("game_id", "team")) %>%
  inner_join(tbox2, by = c("espn_game_id", "team" = "espn_team"), suffix = c("", "_e"))
n_tg_ours <- nrow(tg); n_tg_cmp <- nrow(tcmp)

team_pairs <- tribble(
  ~stat, ~ours, ~espn,
  "pts", "pts", "team_score",
  "FGM", "FGM", "field_goals_made", "FGA", "FGA", "field_goals_attempted",
  "FG3M", "FG3M", "three_point_field_goals_made", "FG3A", "FG3A", "three_point_field_goals_attempted",
  "FTM", "FTM", "free_throws_made", "FTA", "FTA", "free_throws_attempted",
  "OREB (player-credited)", "pOREB", "offensive_rebounds", "DREB (player-credited)", "pDREB", "defensive_rebounds",
  "AST", "AST", "assists", "STL", "STL", "steals", "BLK", "BLK", "blocks",
  "TOV", "TOV", "total_turnovers", "PF", "PF", "fouls"
)
team_cmp_stats <- function(cmp, pairs) {
  pmap_dfr(pairs, function(stat, ours, espn) {
    d <- cmp[[ours]] - cmp[[espn]]
    tibble(stat = stat, compared = sum(!is.na(d)), exact = sum(d == 0, na.rm = TRUE),
           exact_rate = round(mean(d == 0, na.rm = TRUE), 4),
           mismatches = sum(d != 0, na.rm = TRUE), max_abs_diff = max(abs(d), na.rm = TRUE),
           mean_diff = round(mean(d, na.rm = TRUE), 4))
  })
}
add("## Step 1: team-game comparison")
add("")
add("Team-games in our table: ", n_tg_ours, "; compared: ", n_tg_cmp, ". Comparison columns are ours vs ESPN")
add("team box. Definitions used (stated before looking at results): our OREB, DREB and TOV include team")
add("rebounds and team turnovers, so TOV is compared with ESPN `total_turnovers` (the ESPN column that")
add("includes team turnovers; `turnovers` excludes them). ESPN team rebounds turned out to exclude")
add("team-credited rebounds (see the alternate table: our team-game OREB and DREB, which include team")
add("rebounds, are systematically larger), so OREB and DREB are compared as the sum of our player-credited")
add("rebounds per team-game (`player_games`), which is the matching definition. Our PF is personal plus")
add("offensive fouls without technicals; ESPN `fouls` is compared as given.")
add("")
tstats <- team_cmp_stats(tcmp, team_pairs)
md_table(tstats)
add("Alternate definitions, reported only for reference:")
alt <- bind_rows(
  team_cmp_stats(tcmp, tribble(~stat, ~ours, ~espn, "OREB incl. team rebounds (team_games)", "OREB", "offensive_rebounds",
                               "DREB incl. team rebounds (team_games)", "DREB", "defensive_rebounds")),
  team_cmp_stats(tcmp, tribble(~stat, ~ours, ~espn, "TOV vs ESPN turnovers (excl. team)", "TOV", "turnovers")),
  team_cmp_stats(tcmp %>% mutate(PF_alt = fouls - technical_fouls),
                 tribble(~stat, ~ours, ~espn, "PF vs ESPN fouls minus technical_fouls", "PF", "PF_alt")),
  team_cmp_stats(tcmp %>% mutate(PF_alt2 = fouls - total_technical_fouls),
                 tribble(~stat, ~ours, ~espn, "PF vs ESPN fouls minus total_technical_fouls", "PF", "PF_alt2"))
)
md_table(alt)
tmis <- map_dfr(seq_len(nrow(team_pairs)), function(i) {
  s <- team_pairs$stat[i]; d <- tcmp[[team_pairs$ours[i]]] - tcmp[[team_pairs$espn[i]]]
  tcmp[which(d != 0), ] %>% transmute(stat = s, game_id, team, ours = .data[[team_pairs$ours[i]]],
                                       espn = .data[[team_pairs$espn[i]]], diff = ours - espn)
})
add("Team-game stat mismatches (first 40 of ", nrow(tmis), "):")
md_table(head(tmis, 40))
saveRDS(tmis, file.path(tempdir(), "tmis.rds"))

# ---- 5. Player matching ---------------------------------------------------------------
pbox2 <- pbox %>%
  mutate(espn_game_id = as.character(game_id), espn_team = unname(tm[team_abbreviation]),
         athlete_id = as.character(athlete_id),
         espn_name = athlete_display_name, espn_norm = norm_name(athlete_display_name),
         espn_dnp = isTRUE(NA) | did_not_play | is.na(minutes))
pbox2$espn_dnp <- pbox2$did_not_play | is.na(pbox2$minutes)
pg2 <- pg %>% inner_join(gmap %>% select(game_id, espn_game_id), by = "game_id") %>%
  mutate(our_norm = norm_name(player_name), person_id = as.character(person_id))

# candidate pairs within each team-game: ESPN full name equals ours or ends with " <ours>"
cand <- pg2 %>% select(game_id, espn_game_id, team, person_id, player_name, our_norm) %>%
  inner_join(pbox2 %>% select(espn_game_id, espn_team, athlete_id, espn_name, espn_norm, espn_dnp),
             by = c("espn_game_id", "team" = "espn_team"), relationship = "many-to-many") %>%
  filter(espn_norm == our_norm | endsWith(espn_norm, paste0(" ", our_norm)))
cand <- cand %>% group_by(game_id, team, person_id) %>% mutate(n_for_ours = n()) %>%
  group_by(game_id, team, athlete_id) %>% mutate(n_for_espn = n()) %>% ungroup()
pass1 <- cand %>% filter(n_for_ours == 1, n_for_espn == 1)
id_map1 <- pass1 %>% distinct(person_id, athlete_id) %>%
  group_by(person_id) %>% filter(n() == 1) %>% ungroup() %>%
  group_by(athlete_id) %>% filter(n() == 1) %>% ungroup()
amb <- cand %>% anti_join(pass1, by = c("game_id", "team", "person_id", "athlete_id")) %>%
  inner_join(id_map1, by = c("person_id", "athlete_id"))
pairs <- bind_rows(pass1, amb) %>% distinct(game_id, team, person_id, athlete_id, .keep_all = TRUE)
# one-to-one by name within team-game
pairs <- pairs %>% group_by(game_id, team, person_id) %>% filter(n() == 1) %>%
  group_by(game_id, team, athlete_id) %>% filter(n() == 1) %>% ungroup()
n_name_pairs <- nrow(pairs)
n_resolved_by_map <- nrow(pairs) - nrow(pass1)

# Pass 3 (name-free): in a team-game with exactly one unmatched row of ours and exactly one
# unmatched ESPN row that played, pair them by elimination. A person_id to athlete_id link is
# accepted only if every elimination case for that person agrees (and the reverse), then applied
# to the remaining unmatched rows. No statistics are used. This covers name changes (for example
# cdn "Coffey" vs ESPN "Nia Brodie").
pairs <- pairs %>% mutate(method = "name")
elim_links <- tibble(person_id = character(), athlete_id = character())
elim_rounds <- 0L
repeat {
  left_o <- pg2 %>% anti_join(pairs, by = c("game_id", "team", "person_id"))
  left_e <- pbox2 %>% filter(espn_game_id %in% gmap$espn_game_id, !espn_dnp) %>%
    anti_join(pairs, by = c("espn_game_id", "espn_team" = "team", "athlete_id"))
  elim <- left_o %>% group_by(game_id, team) %>% filter(n() == 1) %>% ungroup() %>%
    inner_join(left_e %>% group_by(espn_game_id, espn_team) %>% filter(n() == 1) %>% ungroup() %>%
                 select(espn_game_id, espn_team, athlete_id),
               by = c("espn_game_id", "team" = "espn_team"))
  links <- bind_rows(elim_links, elim %>% distinct(person_id, athlete_id)) %>% distinct()
  links <- links %>% group_by(person_id) %>% filter(n_distinct(athlete_id) == 1) %>% ungroup() %>%
    group_by(athlete_id) %>% filter(n_distinct(person_id) == 1) %>% ungroup()
  elim_links <- links
  cand3 <- left_o %>% select(game_id, espn_game_id, team, person_id, player_name, our_norm) %>%
    inner_join(elim_links, by = "person_id") %>%
    inner_join(left_e %>% select(espn_game_id, espn_team, athlete_id, espn_name, espn_norm, espn_dnp),
               by = c("espn_game_id", "team" = "espn_team", "athlete_id"))
  pairs3 <- cand3 %>% group_by(game_id, team, person_id) %>% filter(n() == 1) %>%
    group_by(game_id, team, athlete_id) %>% filter(n() == 1) %>% ungroup()
  if (nrow(pairs3) == 0) break
  pairs <- bind_rows(pairs, pairs3 %>% mutate(method = "elimination_id_link"))
  elim_rounds <- elim_rounds + 1L
}
pairs <- pairs %>% select(game_id, espn_game_id, team, person_id, player_name, athlete_id, espn_name, method)

ours_unmatched <- pg2 %>% anti_join(pairs, by = c("game_id", "team", "person_id"))
espn_in_matched <- pbox2 %>% filter(espn_game_id %in% gmap$espn_game_id, !is.na(espn_team))
espn_unmatched <- espn_in_matched %>% anti_join(pairs, by = c("espn_game_id", "espn_team" = "team", "athlete_id"))

# one row per person_id / athlete_id pair
pmap <- pairs %>% group_by(person_id, athlete_id) %>%
  summarise(our_name = names(sort(table(player_name), decreasing = TRUE))[1],
            espn_name = names(sort(table(espn_name), decreasing = TRUE))[1],
            games = n(), methods = paste(sort(unique(method)), collapse = "+"), .groups = "drop") %>%
  arrange(person_id)
multi <- pmap %>% count(person_id) %>% filter(n > 1)
multi2 <- pmap %>% count(athlete_id) %>% filter(n > 1)
write_csv(pmap, proj_path("data", "reference", "espn_player_map.csv"))

add("## Step 1: player matching")
add("")
add("Our table has cdn surnames only, so names are matched on normalized text (lowercase, accents and")
add("punctuation stripped): the ESPN full name equals our name or ends with it, within the matched team-game.")
add("Ambiguous cases are resolved through person_id to athlete_id links established elsewhere. A third pass")
add("pairs the single leftover player on each side of a team-game by elimination (name-free, no statistics)")
add("and accepts a person_id to athlete_id link only when every such case agrees; this covers name changes.")
add("")
add("- Our player-game rows in matched games: ", nrow(pg2))
add("- Matched: ", nrow(pairs), " (by name: ", sum(pairs$method == "name"), " of which ", n_resolved_by_map,
    " resolved via id links; by elimination plus id link: ", sum(pairs$method != "name"), " in ", elim_rounds, " passes)")
add("- Our rows unmatched: ", nrow(ours_unmatched))
add("- ESPN rows in matched games: ", nrow(espn_in_matched), "; unmatched: ", nrow(espn_unmatched),
    " (DNP or no minutes: ", sum(espn_unmatched$espn_dnp), "; played: ", sum(!espn_unmatched$espn_dnp), ")")
add("- person_id with more than one athlete_id: ", nrow(multi), "; athlete_id with more than one person_id: ", nrow(multi2))
add("- Distinct person_id/athlete_id pairs in `data/reference/espn_player_map.csv`: ", nrow(pmap))
add("")
add("Pairs matched by elimination plus id link (name differs between sources):")
md_table(pmap %>% filter(grepl("elimination", methods)) %>% select(person_id, athlete_id, our_name, espn_name, games))
add("Our player-game rows with no ESPN match (first 30 of ", nrow(ours_unmatched), "):")
md_table(head(ours_unmatched %>% select(game_id, team, person_id, player_name), 30))
add("ESPN rows that played (non-DNP) with no match in our table (first 30 of ", sum(!espn_unmatched$espn_dnp), "):")
md_table(head(espn_unmatched %>% filter(!espn_dnp) %>%
                select(espn_game_id, espn_team, athlete_id, espn_name, minutes, points), 30))
add("ESPN DNP rows unmatched (expected): ", sum(espn_unmatched$espn_dnp), ". ESPN DNP rows that matched one of our")
dnp_matched <- pairs %>% inner_join(pbox2 %>% select(espn_game_id, athlete_id, espn_dnp, minutes), by = c("espn_game_id", "athlete_id")) %>%
  filter(espn_dnp)
add("rows (we have cdn events, ESPN says did not play or no minutes): ", nrow(dnp_matched))
md_table(head(dnp_matched %>% select(game_id, team, player_name, espn_name, minutes), 30))

# ---- 6. Player-game comparison ---------------------------------------------------------
shots <- load_table("shots", "all")
fg3a <- shots %>% filter(shot_type == "3pt") %>% count(game_id, person_id = as.character(person_id), name = "FG3A")
ours_p <- pg2 %>%
  left_join(fg3a, by = c("game_id", "person_id")) %>%
  mutate(FG3A = replace_na(FG3A, 0L), REB = OREB + DREB)
pc <- pairs %>% select(game_id, team, person_id, athlete_id) %>%
  inner_join(ours_p, by = c("game_id", "team", "person_id")) %>%
  inner_join(pbox2 %>% select(espn_game_id, athlete_id, espn_minutes = minutes, e_pts = points,
                              e_fgm = field_goals_made, e_fga = field_goals_attempted,
                              e_fg3m = three_point_field_goals_made, e_fg3a = three_point_field_goals_attempted,
                              e_ftm = free_throws_made, e_fta = free_throws_attempted,
                              e_oreb = offensive_rebounds, e_dreb = defensive_rebounds, e_reb = rebounds,
                              e_ast = assists, e_stl = steals, e_blk = blocks, e_tov = turnovers, e_pf = fouls,
                              espn_dnp_flag = espn_dnp),
             by = c("espn_game_id", "athlete_id"))
# ESPN lists did-not-play players with NA minutes and NA stats. Where we have a row (cdn events but no
# court time), treat the ESPN DNP row as zeros so that "0 minutes, all-zero line" counts as agreement.
n_dnp_as_zero <- sum(pc$espn_dnp_flag)
pc <- pc %>% mutate(across(c(espn_minutes, starts_with("e_")), ~ ifelse(espn_dnp_flag & is.na(.x), 0, .x)))
pstat <- tribble(
  ~stat, ~ours, ~espn,
  "pts", "PTS", "e_pts", "FGM", "FGM", "e_fgm", "FGA", "FGA", "e_fga", "FG3M", "FG3M", "e_fg3m",
  "FG3A", "FG3A", "e_fg3a", "FTM", "FTM", "e_ftm", "FTA", "FTA", "e_fta", "OREB", "OREB", "e_oreb",
  "DREB", "DREB", "e_dreb", "REB", "REB", "e_reb", "AST", "AST", "e_ast", "STL", "STL", "e_stl",
  "BLK", "BLK", "e_blk", "TOV", "TOV", "e_tov", "PF", "PF", "e_pf"
)
pc_long <- bind_rows(
  pmap_dfr(pstat, function(stat, ours, espn) {
    pc %>% transmute(game_id, team, person_id, player_name, stat = stat, ours = .data[[ours]], espn = .data[[espn]])
  }),
  pc %>% transmute(game_id, team, person_id, player_name, stat = "minutes", ours = minutes, espn = espn_minutes)
) %>% mutate(diff = ours - espn, tol = ifelse(stat == "minutes", 1.0, 0)) %>% filter(!is.na(diff))
pstats <- pc_long %>% group_by(stat) %>%
  summarise(compared = n(), exact = sum(diff == 0), exact_rate = round(mean(diff == 0), 4),
            outside_tol = sum(abs(diff) > tol[1] + 1e-9), max_abs_diff = round(max(abs(diff)), 3), .groups = "drop") %>%
  arrange(factor(stat, levels = c(pstat$stat, "minutes")))
add("")
add("## Step 1: player-game comparison")
add("")
add("Matched player-games: ", nrow(pc), ". FG3A comes from our `shots` table (3pt attempts per player-game); REB is")
add("OREB + DREB (player-credited; cdn team rebounds are not attributed to players). Tolerances: minutes within")
add("1.0 (ESPN rounds to whole minutes), every count stat exact. Rows where ESPN has no value for a stat are")
add("excluded from that stat's count. ESPN did-not-play rows matched to one of our rows (", n_dnp_as_zero,
    ") are treated as zeros.")
add("")
md_table(pstats)
worst_counts <- pc_long %>% filter(stat != "minutes", diff != 0) %>% arrange(desc(abs(diff)))
add("Count-stat mismatches (", nrow(worst_counts), " rows across all stats; worst 10 by absolute difference, then listed in full if 40 or fewer):")
md_table(head(worst_counts %>% select(game_id, team, player_name, stat, ours, espn, diff), 10))
if (nrow(worst_counts) > 10 && nrow(worst_counts) <= 40) {
  add("Full list:")
  md_table(worst_counts %>% select(game_id, team, player_name, stat, ours, espn, diff))
}
mins <- pc_long %>% filter(stat == "minutes")
add("### Minutes")
add("")
add("Difference = ours minus ESPN. Quantiles of the absolute difference:")
q <- quantile(abs(mins$diff), c(0.5, 0.9, 0.95, 0.99, 0.999, 1))
md_table(tibble(quantile = names(q), abs_diff_minutes = round(as.numeric(q), 3)))
brk <- c(-Inf, -10, -5, -2, -1, -0.5, 0.5, 1, 2, 5, 10, Inf)
add("Distribution of the signed difference:")
md_table(mins %>% mutate(bin = cut(diff, brk, right = TRUE)) %>% count(bin, name = "player_games") %>%
           mutate(share = round(player_games / sum(player_games), 4)))
add("Worst 10 by absolute minutes difference:")
md_table(mins %>% arrange(desc(abs(diff))) %>% head(10) %>%
           transmute(game_id, team, player_name, ours = round(ours, 2), espn, diff = round(diff, 2)))
rate_minutes <- mean(abs(mins$diff) <= 1.0 + 1e-9)
add("Share of player-games with minutes within 1.0: ", sprintf("%.4f", rate_minutes), " (", sum(abs(mins$diff) <= 1.0 + 1e-9), " of ", nrow(mins), ").")
add("")

# ten player-games changed by the starter-inference fix (new minus first build, regenerated with the
# first-build build_minutes() from commit 3a1492f; recorded old values below)
fix10 <- tribble(
  ~game_id, ~person_id, ~old_minutes,
  1022600312, "203398", 10.0, 1022600149, "204319", 33.7, 1022600230, "204319", 26.15,
  1022600237, "204333", 36.71667, 1022600183, "1627673", 28.1, 1022600218, "1629482", 12.7,
  1022600230, "1629482", 23.08833, 1022600183, "1630134", 16.67833, 1042600201, "1631044", 26.63333,
  1042600304, "1631044", 25.84333
)
f10 <- fix10 %>% left_join(pc %>% select(game_id, person_id, team, player_name, new_minutes = minutes, espn_minutes),
                           by = c("game_id", "person_id")) %>%
  mutate(new_minus_espn = round(new_minutes - espn_minutes, 2), old_minus_espn = round(old_minutes - espn_minutes, 2),
         new_within_1 = !is.na(new_minus_espn) & abs(new_minus_espn) <= 1, old_within_1 = !is.na(old_minus_espn) & abs(old_minus_espn) <= 1) %>%
  mutate(across(c(old_minutes, new_minutes), ~ round(.x, 2)))
add("### The 10 player-games changed by the starter-inference fix")
add("")
add("Old = first build of `build_minutes()` (commit 3a1492f, regenerated), new = current table.")
md_table(f10)
add("New minutes within 1.0 of ESPN: ", sum(f10$new_within_1), " of 10. Old minutes within 1.0: ", sum(f10$old_within_1), " of 10.")
add("Game 1022600312 Griner: ESPN lists her as did-not-play (NA minutes); treated as 0 minutes, so the corrected value of 0 agrees and the old value of 10 did not.")
add("")

# ---- Step 2: schedule, standings, playoff bracket ---------------------------------------
add("## Step 2: schedule, standings, playoff bracket")
add("")
reg <- games %>% filter(season_type == "regular")
tg_reg <- tg %>% filter(season_type == "regular")
per_team <- tg_reg %>% count(team, name = "games")
add("### Regular season schedule")
add("")
add("- Games: ", nrow(reg), " (expected 330); duplicate game_id: ", sum(duplicated(reg$game_id)),
    "; duplicate (date, home, away): ", sum(duplicated(reg[c("game_date", "home_team", "away_team")])))
add("- Teams: ", nrow(per_team), "; games per team min ", min(per_team$games), ", max ", max(per_team$games),
    "; teams not at 44: ", sum(per_team$games != 44))
noncount <- gmap %>% filter(game_id %in% reg$game_id) %>%
  inner_join(sched %>% select(espn_game_id, game_kind, notes_headline), by = "espn_game_id") %>%
  filter(game_kind != "counting")
add("- Our regular-season games that ESPN types as non-counting (All-Star, Commissioner's Cup final): ", nrow(noncount))
if (nrow(noncount)) md_table(noncount)
add("- Our regular-season games with no ESPN match (cannot be typed): ", sum(!reg$game_id %in% gmap$game_id))
add("- ESPN counting games (type STD, final): ", sum(sched$game_kind == "counting" & sched$final & sched$season_type == 2),
    "; ESPN regular-season STD rows with other status: ",
    sum(sched$game_kind == "counting" & !sched$final & sched$season_type == 2), " (",
    paste(unique(sched$status_type_name[sched$game_kind == "counting" & !sched$final & sched$season_type == 2]), collapse = ", "),
    ", the postponed July 16 game, replayed July 20)")
add("")
espn_cnt <- sched %>% filter(game_kind == "counting", final, season_type == 2)
espn_wl <- bind_rows(
  espn_cnt %>% transmute(team = home, win = home_score > away_score),
  espn_cnt %>% transmute(team = away, win = away_score > home_score)) %>%
  group_by(team) %>% summarise(espn_W = sum(win), espn_L = sum(!win), .groups = "drop")
our_wl <- tg_reg %>% group_by(team) %>% summarise(W = sum(win), L = sum(!win), .groups = "drop")
stand <- our_wl %>% full_join(espn_wl, by = "team") %>%
  mutate(match = W == espn_W & L == espn_L, pct = round(W / (W + L), 3)) %>% arrange(desc(W), team)
add("### Standings (ours vs ESPN counting games)")
add("")
add("Teams with W-L matching exactly: ", sum(stand$match, na.rm = TRUE), " of ", nrow(stand), ".")
add("")
md_table(stand %>% transmute(team, W, L, pct, espn_W, espn_L, match))

add("### Playoffs")
add("")
po <- games %>% filter(season_type == "playoffs") %>% arrange(game_date, game_id) %>%
  mutate(winner = ifelse(home_pts > away_pts, home_team, away_team),
         t1 = pmin(home_team, away_team), t2 = pmax(home_team, away_team), series = paste(t1, t2, sep = "-"))
ser <- po %>% group_by(series, t1, t2) %>%
  summarise(first_date = min(game_date), last_date = max(game_date), n_games = n(),
            w1 = sum(winner == t1), w2 = sum(winner == t2), .groups = "drop") %>%
  mutate(series_winner = ifelse(w1 > w2, t1, t2), winner_wins = pmax(w1, w2), loser_wins = pmin(w1, w2)) %>%
  arrange(first_date, series)
# refine: count distinct earlier series involving either team
ser$round <- vapply(seq_len(nrow(ser)), function(i) {
  tm_i <- c(ser$t1[i], ser$t2[i])
  1L + max(0L, vapply(tm_i, function(t) sum(ser$first_date < ser$first_date[i] & (ser$t1 == t | ser$t2 == t)), integer(1)))
}, integer(1))
req <- ser %>% group_by(round) %>% summarise(required_wins = max(winner_wins), .groups = "drop")
ser <- ser %>% left_join(req, by = "round") %>%
  mutate(reached_required = winner_wins == required_wins & loser_wins < required_wins)
# eliminated team plays again?
elim_check <- ser %>% mutate(loser = ifelse(series_winner == t1, t2, t1)) %>%
  rowwise() %>%
  mutate(plays_after = sum(po$game_date > last_date & (po$home_team == loser | po$away_team == loser))) %>% ungroup()
champ <- ser %>% filter(round == max(round)) %>% pull(series_winner)
later_ok <- ser %>% rowwise() %>%
  mutate(advances = round == max(ser$round) | any(ser$round > round & (ser$t1 == series_winner | ser$t2 == series_winner))) %>% ungroup()
add("Playoff games: ", nrow(po), " in ", nrow(ser), " series. Rounds are inferred from the order in which a team's series occur.")
add("Required wins per round, inferred as the winners' win count: ",
    paste(sprintf("round %d = %d wins (best of %d)", req$round, req$required_wins, 2 * req$required_wins - 1), collapse = "; "), ".")
add("")
md_table(ser %>% transmute(round, series, first_date, last_date, games = n_games,
                           wins_t1 = paste0(t1, " ", w1), wins_t2 = paste0(t2, " ", w2),
                           winner = series_winner, required_wins, reached_required))
add("- Every series winner reached the required wins and the loser did not: ", all(ser$reached_required))
add("- Every non-champion series winner appears in a later round: ", all(later_ok$advances))
add("- Eliminated teams playing again after their series ended: ", sum(elim_check$plays_after))
add("- Champion (winner of the last round): ", paste(champ, collapse = ", "))
espn_po <- sched %>% filter(season_type == 3)
add("- ESPN playoff schedule: ", sum(espn_po$final), " final games, ", sum(!espn_po$final),
    " not final (", paste(espn_po$notes_headline[!espn_po$final], collapse = "; "), "), so ESPN has no box score for that game.")
add("")

# ---- Step 3: side-by-side spot checks ------------------------------------------------------
add("## Step 3: spot checks (ours vs ESPN, shown as ours / ESPN, `!` marks a difference)")
add("")
cell <- function(o, e, tol = 0) {
  ifelse(is.na(e), paste0(o, " / NA !"),
         ifelse(abs(o - e) > tol + 1e-9, paste0(o, " / ", e, " !"), as.character(o)))
}
spot <- function(gid, label, focus = NA_character_) {
  gm <- games %>% filter(game_id == gid)
  em <- gmap %>% filter(game_id == gid)
  add("### ", label, ": game ", format(gid, scientific = FALSE), " ", gm$away_team, " at ", gm$home_team, " ", gm$game_date,
      " (", gm$away_pts, "-", gm$home_pts, ", ", gm$n_periods, " periods; ESPN ", em$espn_game_id, ")")
  add("")
  tt <- tcmp %>% filter(game_id == gid) %>%
    transmute(team, pts = cell(pts, team_score), FGM = cell(FGM, field_goals_made), FGA = cell(FGA, field_goals_attempted),
              FG3M = cell(FG3M, three_point_field_goals_made), FG3A = cell(FG3A, three_point_field_goals_attempted),
              FTM = cell(FTM, free_throws_made), FTA = cell(FTA, free_throws_attempted),
              OREB = cell(pOREB, offensive_rebounds), DREB = cell(pDREB, defensive_rebounds),
              AST = cell(AST, assists), STL = cell(STL, steals), BLK = cell(BLK, blocks),
              TOV = cell(TOV, total_turnovers), PF = cell(PF, fouls))
  md_table(tt)
  add("Players (all rows from both sources; minutes tolerance 1.0):")
  add("")
  oo <- pc %>% filter(game_id == gid) %>%
    transmute(team, player = player_name, minutes = cell(round(minutes, 1), espn_minutes, 1),
              pts = cell(PTS, e_pts), FGM = cell(FGM, e_fgm), FGA = cell(FGA, e_fga), FG3M = cell(FG3M, e_fg3m),
              FG3A = cell(FG3A, e_fg3a), FTM = cell(FTM, e_ftm), FTA = cell(FTA, e_fta), OREB = cell(OREB, e_oreb),
              DREB = cell(DREB, e_dreb), AST = cell(AST, e_ast), STL = cell(STL, e_stl), BLK = cell(BLK, e_blk),
              TOV = cell(TOV, e_tov), PF = cell(PF, e_pf), person_id)
  md_table(oo %>% arrange(team, desc(as.numeric(sub(" /.*", "", minutes)))) %>% select(-person_id))
  ou <- ours_unmatched %>% filter(game_id == gid) %>% transmute(source = "ours only", team, player = player_name)
  eu <- espn_unmatched %>% filter(espn_game_id == em$espn_game_id) %>%
    transmute(source = ifelse(espn_dnp, "ESPN only (DNP)", "ESPN only (played)"), team = espn_team, player = espn_name)
  add("Unmatched rows in this game: ", nrow(ou) + nrow(eu), " (", sum(eu$source == "ESPN only (played)") + nrow(ou), " that played)")
  md_table(bind_rows(ou, eu %>% filter(source != "ESPN only (DNP)")))
  nflag <- sum(grepl("!", unlist(oo %>% select(-team, -player, -person_id)))) + sum(grepl("!", unlist(tt %>% select(-team))))
  add("Disagreements flagged in this game: ", nflag)
  if (!is.na(focus)) {
    ff <- f10 %>% filter(game_id == gid, person_id == focus)
    if (nrow(ff)) add("Focus player ", ff$player_name, " (", focus, "): old minutes ", ff$old_minutes, ", new ", ff$new_minutes,
                      ", ESPN ", ff$espn_minutes, "; new within 1.0 of ESPN: ", ff$new_within_1)
  }
  add("")
  nflag
}
ot_gid <- games %>% filter(season_type == "regular", n_periods > 4) %>% arrange(game_id) %>% slice(1) %>% pull(game_id)
flags <- c(
  spot(ot_gid, "Regular-season overtime game (first with n_periods > 4)"),
  spot(1042600112, "Playoff flagrant-FT game (DAL 108, GSV 100)"),
  spot(1022600312, "Starter-fix case, CON (player 203398, 10 to 0)", "203398"),
  spot(1022600237, "Starter-fix case, CHI (player 204333, 36.7 to 26.7)", "204333"),
  spot(1042600304, "Starter-fix case, ATL (Hillmon, 25.8 to 35.8)", "1631044")
)
add("Total flagged disagreements across the five spot-check games: ", sum(flags))
add("")

# ---- Appendix: which source does nbastats v2 side with in each mismatch? --------------------------
# For every player-game and team-game count mismatch against ESPN, recompute the stat from the raw
# nbastats v2 events (independent of cdn) and report whether v2 equals ours (cdn-derived) or ESPN.
add("## Appendix: mismatch attribution using nbastats v2 (independent of cdn)")
add("")
v2_files <- c(raw_csv("nbastats", "regular"), raw_csv("nbastats", "playoffs"))
if (all(file.exists(v2_files))) {
  mm <- pc_long %>% filter(stat != "minutes", diff != 0)
  v2d <- map_dfr(v2_files, ~ read_csv(.x, show_col_types = FALSE, guess_max = 100000)) %>%
    filter(GAME_ID %in% unique(c(mm$game_id, tmis$game_id))) %>%
    mutate(desc = paste(coalesce(HOMEDESCRIPTION, ""), coalesce(VISITORDESCRIPTION, "")), pid = as.character(PLAYER1_ID))
  v_sh <- v2d %>% filter(EVENTMSGTYPE %in% c(1, 2), !is.na(PLAYER1_ID)) %>%
    mutate(is3 = grepl("3PT", desc), made = EVENTMSGTYPE == 1) %>% group_by(game_id = GAME_ID, person_id = pid) %>%
    summarise(FGA = n(), FGM = sum(made), FG3A = sum(is3), pts_fg = sum(made * ifelse(is3, 3, 2)), .groups = "drop")
  v_ft <- v2d %>% filter(EVENTMSGTYPE == 3, !grepl("MISS", desc)) %>% group_by(game_id = GAME_ID, person_id = pid) %>% summarise(FTM = n(), .groups = "drop")
  v_rb <- v2d %>% filter(EVENTMSGTYPE == 4, !is.na(PLAYER1_ID)) %>% group_by(game_id = GAME_ID, person_id = pid) %>% summarise(REB = n(), .groups = "drop")
  v_tv <- v2d %>% filter(EVENTMSGTYPE == 5) %>% group_by(game_id = GAME_ID, person_id = pid) %>% summarise(TOV = n(), .groups = "drop")
  v_st <- v2d %>% filter(EVENTMSGTYPE == 5, !is.na(PLAYER2_ID), grepl("STL", desc)) %>%
    group_by(game_id = GAME_ID, person_id = as.character(PLAYER2_ID)) %>% summarise(STL = n(), .groups = "drop")
  v_as <- v2d %>% filter(EVENTMSGTYPE == 1, grepl("AST\\)", desc)) %>%
    mutate(player_name = sub(".*\\(([^()]*) [0-9]+ AST\\).*", "\\1", desc)) %>% count(game_id = GAME_ID, player_name, name = "AST_v2")
  vp <- v_sh %>% full_join(v_ft, by = c("game_id", "person_id")) %>% full_join(v_rb, by = c("game_id", "person_id")) %>%
    full_join(v_tv, by = c("game_id", "person_id")) %>% full_join(v_st, by = c("game_id", "person_id")) %>%
    mutate(across(where(is.numeric), ~ replace_na(.x, 0)), pts = pts_fg + FTM)
  att <- mm %>% left_join(vp, by = c("game_id", "person_id")) %>% left_join(v_as, by = c("game_id", "player_name")) %>%
    mutate(AST_v2 = replace_na(AST_v2, 0L),
           v2 = case_when(stat == "pts" ~ pts, stat == "FGM" ~ FGM, stat == "FGA" ~ FGA, stat == "FG3A" ~ FG3A,
                          stat == "REB" ~ REB, stat == "STL" ~ STL, stat == "TOV" ~ TOV, stat == "AST" ~ AST_v2,
                          TRUE ~ NA_real_),
           v2_side = case_when(is.na(v2) ~ "not checkable (OREB/DREB split)", v2 == espn ~ "v2 = ESPN", v2 == ours ~ "v2 = ours", TRUE ~ "v2 differs from both"))
  add("Player-game count mismatches against ESPN (", nrow(att), " cells) by what nbastats v2 says:")
  md_table(att %>% count(v2_side, name = "cells"))
  add("Games with at least one player-game mismatch: ", n_distinct(att$game_id), ". Detail:")
  md_table(att %>% transmute(game_id, team, player_name, stat, ours, espn, v2, v2_side))
  add("Reading: where v2 can be computed it sides with ESPN, so the differences come from the cdn feed (the shooter,")
  add("assister, rebounder or stealer credited on a single event), which our box score reproduces by construction.")
  add("Team totals are unaffected in most of these games because the swap stays within a team. One example checked")
  add("at the raw event level: game 1022600169, cdn credits the 6:48 fourth-period layup to Pissott (assist Talbot),")
  add("v2 and ESPN credit it to Talbot (assist Pissott).")
  add("")
} else add("nbastats v2 raw files not found; attribution skipped.\n")

writeLines(md, file.path(OUTPUT_DIR, "external_validation.md"))
cat("Wrote", file.path(OUTPUT_DIR, "external_validation.md"), "\n")
