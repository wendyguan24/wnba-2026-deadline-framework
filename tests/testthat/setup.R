# testthat auto-sources setup*.R files before running tests, in the same
# environment the tests themselves execute in -- this is how R/02-04's
# functions become available to test files. (test_dir() runs each test file in
# its own environment and changes the working directory to tests/testthat/, so
# sourcing outside this file does not work.)

PROJECT_ROOT <- normalizePath(file.path(getwd(), "..", ".."))

#' Build an absolute path from the project root. Use this in test files
#' instead of bare relative paths, since testthat changes the working
#' directory to tests/testthat/ during test execution.
proj_path <- function(...) file.path(PROJECT_ROOT, ...)

# Pin, season, RAW_DIR, PROCESSED_DIR, OUTPUT_DIR, raw_csv() (R/00_config.R).
# PROJECT_ROOT and proj_path are already defined above, so config keeps them.
source(file.path(PROJECT_ROOT, "R", "00_config.R"), local = TRUE)

source(file.path(PROJECT_ROOT, "R", "02_parse_pbp.R"))
source(file.path(PROJECT_ROOT, "R", "03_possessions.R"))
source(file.path(PROJECT_ROOT, "R", "04_reconcile.R"))
