# load_tables.R
#
# Purpose: one entry point for the analysis-ready tables built by
#   R/04b_analysis_tables.R. Start offseason questions here, not from raw files.
#   See docs/data_dictionary.md.
#
# Usage (from the repo root):
#   source("R/00_config.R"); source("R/load_tables.R")
#   list_tables()
#   load_table("player_games", "regular")

if (!exists("PROCESSED_DIR")) source(file.path("R", "00_config.R"))

#' Names of the available analysis tables
list_tables <- function() {
  f <- list.files(file.path(PROCESSED_DIR, "tables"), pattern = "\\.parquet$")
  sub("\\.parquet$", "", f)
}

#' Load one analysis table as a tibble
#'
#' @param name table name, see list_tables()
#' @param season_type "regular", "playoffs" or "all". Regular season and playoffs
#'   are separate populations: choose one explicitly; "all" returns both
#'   stacked, which you should only use with a season_type flag in the model.
#'   The `players` table has one row per person with per-type minute columns and
#'   season_type "both", so the filter does not apply to it.
load_table <- function(name, season_type = c("regular", "playoffs", "all")) {
  season_type <- match.arg(season_type)
  path <- file.path(PROCESSED_DIR, "tables", paste0(name, ".parquet"))
  if (!file.exists(path)) {
    stop("No table '", name, "'. Available: ", paste(list_tables(), collapse = ", "),
         ". Run Rscript R/04b_analysis_tables.R first if empty.")
  }
  df <- dplyr::as_tibble(arrow::read_parquet(path))
  if (name != "players" && season_type != "all") {
    df <- df[df$season_type == season_type, ]
  }
  df
}
