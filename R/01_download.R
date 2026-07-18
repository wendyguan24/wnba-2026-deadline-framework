# 01_download.R
#
# Purpose: Download and extract the pinned WNBA 2026 open-data files from
#   shufinskiy/nba_data (commit 773ce29), and log a download manifest (commit
#   hash, timestamp, per-file row counts / game counts) so every downstream
#   result states exactly what data snapshot it used.
#   See HANDOFF §3 (Layer 1) and §7.
#
# Inputs:  none (pulls from GitHub over HTTPS)
# Outputs: data/raw/wnba_cdnnba_2026.csv
#          data/raw/wnba_shotdetail_2026.csv
#          data/raw/wnba_nbastats_2026.csv
#          data/raw/download_manifest.txt
#
# CLI flag: --latest swaps the pinned commit for `main` (HANDOFF §3, "Data
#   refresh" — check around July 23 for a newer commit; re-pin and re-run
#   01-04 if found, confirm reconciliation tests still pass).
#
# NOT RUN during the setup session. Run deliberately in session 2 so the
# download date is logged (HANDOFF CLAUDE.md "Do not" list).

library(readr)

PINNED_COMMIT <- "773ce29"
DATASETS <- c("wnba_cdnnba_2026", "wnba_shotdetail_2026", "wnba_nbastats_2026")

#' Resolve the commit ref to use for this run
#'
#' @param args character vector, e.g. commandArgs(trailingOnly = TRUE)
#' @return character, either PINNED_COMMIT or "main"
resolve_commit_ref <- function(args = commandArgs(trailingOnly = TRUE)) {
  stop("Not yet implemented — see HANDOFF §3, §6 (data refresh)")
}

#' Download and extract one pinned dataset file
#'
#' @param dataset_name character, e.g. "wnba_cdnnba_2026"
#' @param commit_ref character, git ref (commit hash or "main")
#' @param dest_dir character, destination directory
#' @return character, path to the extracted CSV
download_dataset <- function(dataset_name, commit_ref, dest_dir = "data/raw") {
  stop("Not yet implemented — see HANDOFF §3, §7")
}

#' Write a download manifest recording commit, timestamp, and row/game counts
#'
#' @param csv_paths named list of dataset_name -> csv path
#' @param commit_ref character
#' @param dest_dir character
write_manifest <- function(csv_paths, commit_ref, dest_dir = "data/raw") {
  stop("Not yet implemented — see HANDOFF §3, §7")
}

main <- function() {
  stop("Not yet implemented — see HANDOFF §3, §7. Run deliberately in session 2, not during setup.")
}

if (sys.nframe() == 0) {
  main()
}
