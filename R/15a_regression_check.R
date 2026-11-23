# 15a_regression_check.R
# Purpose: regression check of the first_half window against the committed v1 outputs in
#   output/ (identical up to 1e-6 expected). Writes output/offseason/reread/regression_check_v1.md.
suppressMessages(library(tidyverse))
source(file.path(if (exists("PROJECT_ROOT")) PROJECT_ROOT else ".", "R", "00_config.R"))

FILES <- list(
  icc_table.csv = c("metric"),
  team_generation_making.csv = c("team"),
  team_trajectories.csv = c("metric", "team"),
  trajectory_league_trends.csv = c("metric"),
  team_rank_deltas.csv = c("metric", "team")
)
TOL <- 1e-6

compare_one <- function(fname, keys) {
  v1 <- read_csv(file.path(PROJECT_ROOT, "output", fname), show_col_types = FALSE)
  fh <- read_csv(file.path(PROJECT_ROOT, "output", "offseason", "reread", "first_half", fname),
                 show_col_types = FALSE)
  m <- inner_join(v1, fh, by = keys, suffix = c(".v1", ".fh"))
  num <- setdiff(names(v1)[map_lgl(v1, is.numeric)], keys)
  per_col <- map_dfr(num, function(cn) {
    d <- abs(m[[paste0(cn, ".v1")]] - m[[paste0(cn, ".fh")]])
    tibble(file = fname, column = cn, max_abs_diff = max(d, na.rm = TRUE),
           n_na_mismatch = sum(is.na(m[[paste0(cn, ".v1")]]) != is.na(m[[paste0(cn, ".fh")]])))
  })
  chr <- setdiff(names(v1)[map_lgl(v1, ~ is.character(.x) || is.logical(.x))], keys)
  per_chr <- map_dfr(chr, function(cn) {
    tibble(file = fname, column = cn,
           max_abs_diff = NA_real_,
           n_na_mismatch = sum(m[[paste0(cn, ".v1")]] != m[[paste0(cn, ".fh")]] |
                                 is.na(m[[paste0(cn, ".v1")]]) != is.na(m[[paste0(cn, ".fh")]]), na.rm = TRUE))
  })
  list(cols = bind_rows(per_col, per_chr), n_v1 = nrow(v1), n_fh = nrow(fh), n_join = nrow(m))
}

main <- function() {
  res <- imap(FILES, ~ compare_one(.y, .x))
  tab <- map_dfr(res, "cols")
  summ <- tab %>% group_by(file) %>%
    summarise(max_abs_diff = max(max_abs_diff, na.rm = TRUE), label_mismatches = sum(n_na_mismatch),
              .groups = "drop") %>%
    mutate(rows_v1 = map_int(res[file], "n_v1"), rows_first_half = map_int(res[file], "n_fh"),
           rows_joined = map_int(res[file], "n_join"),
           pass = max_abs_diff <= TOL & label_mismatches == 0 & rows_v1 == rows_first_half &
                  rows_v1 == rows_joined)
  lines <- c("# Regression check: first_half window vs committed v1 outputs", "",
    paste0("Tolerance: max abs diff <= ", format(TOL), "; character/logical columns must match exactly; row counts must match."), "",
    "| file | rows v1 | rows first_half | rows joined | max abs diff | label mismatches | pass |",
    "|---|---|---|---|---|---|---|",
    pmap_chr(summ, function(file, max_abs_diff, label_mismatches, rows_v1, rows_first_half, rows_joined, pass)
      sprintf("| %s | %d | %d | %d | %.3g | %d | %s |", file, rows_v1, rows_first_half, rows_joined,
              max_abs_diff, label_mismatches, pass)),
    "", paste0("Overall: ", if (all(summ$pass)) "PASS" else "FAIL"), "",
    "## Per column", "", "| file | column | max abs diff | label mismatches |", "|---|---|---|---|",
    pmap_chr(tab, function(file, column, max_abs_diff, n_na_mismatch)
      sprintf("| %s | %s | %s | %d |", file, column,
              ifelse(is.na(max_abs_diff), "n/a", sprintf("%.3g", max_abs_diff)), n_na_mismatch)))
  dir.create(file.path(OUTPUT_DIR, "reread"), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, file.path(OUTPUT_DIR, "reread", "regression_check_v1.md"))
  print(summ)
  invisible(summ)
}
if (sys.nframe() == 0) main()
