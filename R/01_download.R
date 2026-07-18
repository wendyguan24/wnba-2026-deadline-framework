# 01_download.R
#
# Purpose: Download and extract the pinned WNBA 2026 open-data files from
#   shufinskiy/nba_data, and log a download manifest (commit hash, timestamp,
#   per-file row counts / game counts) so every downstream result states
#   exactly what data snapshot it used.
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
# Requires system `tar` on PATH (bsdtar or GNU tar; used to extract .tar.xz
# via system2() rather than relying on R's internal untar()'s xz support).

library(readr)

REPO <- "shufinskiy/nba_data"

# Pinned commit hash: resolves the short hash "773ce29" cited throughout the
# handoff. Verified 2026-07-17 via GitHub API: full SHA
# 773ce292bb2cd9bc6ec98d70de95176607ccbaeb, message "add wnba 2026 data (ID 1
# to 182)". Hardcoded (not resolved dynamically) because commit hashes are
# immutable and pinning removes a network dependency from every other run.
PINNED_COMMIT <- "773ce292bb2cd9bc6ec98d70de95176607ccbaeb"

# v3 (wnba_nbastatsv3_2026) is deliberately excluded — handoff §4c: "ignore
# nbastatsv3," it adds nothing cdn lacks for this project.
DATASETS <- c("wnba_cdnnba_2026", "wnba_shotdetail_2026", "wnba_nbastats_2026")

# Column used to count distinct games per file, for the manifest.
GAME_ID_COL <- c(
  wnba_cdnnba_2026 = "gameId",
  wnba_shotdetail_2026 = "GAME_ID",
  wnba_nbastats_2026 = "GAME_ID"
)

#' Resolve the commit ref to use for this run
#'
#' @param args character vector, e.g. commandArgs(trailingOnly = TRUE)
#' @return character, either PINNED_COMMIT or "main"
resolve_commit_ref <- function(args = commandArgs(trailingOnly = TRUE)) {
  if ("--latest" %in% args) "main" else PINNED_COMMIT
}

#' Download and extract one pinned dataset file
#'
#' @param dataset_name character, e.g. "wnba_cdnnba_2026"
#' @param commit_ref character, git ref (commit hash or "main")
#' @param dest_dir character, destination directory
#' @return character, path to the extracted CSV
download_dataset <- function(dataset_name, commit_ref, dest_dir = "data/raw") {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  url <- sprintf(
    "https://github.com/%s/raw/%s/datasets/%s.tar.xz",
    REPO, commit_ref, dataset_name
  )
  tar_path <- file.path(dest_dir, paste0(dataset_name, ".tar.xz"))
  csv_path <- file.path(dest_dir, paste0(dataset_name, ".csv"))

  message("Downloading ", dataset_name, " from ", url)
  download.file(url, tar_path, mode = "wb", quiet = FALSE)

  status <- system2("tar", c("-xJf", tar_path, "-C", dest_dir))
  if (status != 0) {
    stop("tar extraction failed for ", tar_path, " (exit status ", status, ")")
  }
  if (!file.exists(csv_path)) {
    stop("Expected extracted file not found: ", csv_path)
  }

  csv_path
}

#' Write a download manifest recording commit, timestamp, and row/game counts
#'
#' @param csv_paths named list of dataset_name -> csv path
#' @param commit_ref character
#' @param dest_dir character
write_manifest <- function(csv_paths, commit_ref, dest_dir = "data/raw") {
  lines <- c(
    "WNBA 2026 data download manifest",
    sprintf("Commit ref used: %s", commit_ref),
    sprintf("Downloaded (UTC): %s", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    ""
  )

  for (name in names(csv_paths)) {
    path <- csv_paths[[name]]
    df <- suppressMessages(read_csv(path, show_col_types = FALSE, guess_max = 100000))
    n_rows <- nrow(df)
    game_col <- GAME_ID_COL[[name]]
    n_games <- if (!is.null(game_col) && game_col %in% colnames(df)) {
      length(unique(df[[game_col]]))
    } else {
      NA_integer_
    }
    lines <- c(
      lines,
      sprintf(
        "%s: %d rows, %s distinct games",
        name, n_rows,
        if (is.na(n_games)) "NA" else as.character(n_games)
      )
    )
  }

  manifest_path <- file.path(dest_dir, "download_manifest.txt")
  writeLines(lines, manifest_path)
  message("Manifest written to ", manifest_path)
  invisible(manifest_path)
}

main <- function() {
  commit_ref <- resolve_commit_ref()
  message("Using commit ref: ", commit_ref)

  csv_paths <- setNames(
    lapply(DATASETS, download_dataset, commit_ref = commit_ref),
    DATASETS
  )

  write_manifest(csv_paths, commit_ref)
  message("Download complete. See data/raw/download_manifest.txt")
  invisible(csv_paths)
}

if (sys.nframe() == 0) {
  main()
}
