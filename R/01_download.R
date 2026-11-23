# 01_download.R
#
# Purpose: Download and extract the pinned WNBA 2026 open-data files from
#   shufinskiy/nba_data (regular season and playoffs, three sources each), and
#   log a download manifest (commit hash, timestamp, per-file row counts, game
#   counts, sha256) so every downstream result states which data snapshot it used.
#   Pin and paths come from R/00_config.R.
#
# Inputs:  none (pulls from GitHub over HTTPS)
# Outputs: data/raw/<pin>/wnba_{cdnnba,nbastats,shotdetail}[_po]_2026.csv
#          data/raw/<pin>/download_manifest.txt
#
# CLI flag: --latest swaps the pinned commit for `main` (check for newer
#   commits before the final write-up; re-pin and re-run 01-04 if found).
#
# Requires system `tar` on PATH (used to extract .tar.xz via system2()).

library(readr)

if (!exists("PINNED_COMMIT")) source(file.path("R", "00_config.R"))

REPO <- "shufinskiy/nba_data"

# nbastatsv3 is deliberately excluded (handoff 4c): it adds nothing cdn lacks.
GAME_ID_COL <- c(cdnnba = "gameId", nbastats = "GAME_ID", shotdetail = "GAME_ID")

#' Resolve the commit ref to use for this run
resolve_commit_ref <- function(args = commandArgs(trailingOnly = TRUE)) {
  if ("--latest" %in% args) "main" else PINNED_COMMIT
}

#' Download and extract one pinned dataset file into RAW_DIR
download_dataset <- function(dataset_name, commit_ref, dest_dir = RAW_DIR) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  # raw.githubusercontent.com directly: reachable from the cloud sandbox,
  # whereas github.com/.../raw/ is gated per-repo by the proxy.
  url <- sprintf(
    "https://raw.githubusercontent.com/%s/%s/datasets/%s.tar.xz",
    REPO, commit_ref, dataset_name
  )
  tar_path <- file.path(dest_dir, paste0(dataset_name, ".tar.xz"))
  csv_path <- file.path(dest_dir, paste0(dataset_name, ".csv"))

  message("Downloading ", dataset_name, " from ", url)
  download.file(url, tar_path, mode = "wb", quiet = FALSE)

  status <- system2("tar", c("-xJf", tar_path, "-C", dest_dir))
  if (status != 0) stop("tar extraction failed for ", tar_path, " (exit status ", status, ")")
  if (!file.exists(csv_path)) stop("Expected extracted file not found: ", csv_path)
  csv_path
}

#' Write a manifest with commit, timestamp, rows, games, sha256 per file
#'
#' @param files tibble with columns source, season_type, dataset, path
write_manifest <- function(files, commit_ref, dest_dir = RAW_DIR) {
  lines <- c(
    "WNBA 2026 data download manifest",
    sprintf("Commit ref used: %s", commit_ref),
    sprintf("Downloaded (UTC): %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    "",
    "dataset | season_type | rows | distinct_games | sha256 | commit"
  )
  for (k in seq_len(nrow(files))) {
    df <- suppressMessages(read_csv(files$path[k], show_col_types = FALSE, guess_max = 100000))
    game_col <- GAME_ID_COL[[files$source[k]]]
    n_games <- if (game_col %in% colnames(df)) length(unique(df[[game_col]])) else NA_integer_
    sha <- digest::digest(file = files$path[k], algo = "sha256")
    lines <- c(lines, sprintf("%s | %s | %d | %s | %s | %s", files$dataset[k], files$season_type[k],
                              nrow(df), if (is.na(n_games)) "NA" else n_games, sha, commit_ref))
  }
  manifest_path <- file.path(dest_dir, "download_manifest.txt")
  writeLines(lines, manifest_path)
  message("Manifest written to ", manifest_path)
  invisible(manifest_path)
}

main <- function() {
  commit_ref <- resolve_commit_ref()
  message("Using commit ref: ", commit_ref)

  files <- tidyr::crossing(source = SOURCES, season_type = names(SEASON_TYPES))
  files$dataset <- mapply(dataset_name, files$source, files$season_type)
  files$path <- vapply(files$dataset, download_dataset, character(1), commit_ref = commit_ref)

  write_manifest(files, commit_ref)
  message("Download complete. See ", file.path(RAW_DIR, "download_manifest.txt"))
  invisible(files)
}

if (sys.nframe() == 0) {
  main()
}
