# testthat auto-sources setup*.R files before running tests, in the same
# environment the tests themselves execute in -- this is how R/02-04's
# functions become available to test files. (Sourcing them from a separate
# driver script before calling test_dir() does not reliably work: test_dir()
# runs each test file in its own environment and also changes the working
# directory to tests/testthat/, so both the function bindings and any
# relative data/ paths break if set up outside this file.)

PROJECT_ROOT <- normalizePath(file.path(getwd(), "..", ".."))

source(file.path(PROJECT_ROOT, "R", "02_parse_pbp.R"))
source(file.path(PROJECT_ROOT, "R", "03_possessions.R"))
source(file.path(PROJECT_ROOT, "R", "04_reconcile.R"))

#' Build an absolute path from the project root. Use this in test files
#' instead of bare relative paths ("data/..."), since testthat changes the
#' working directory to tests/testthat/ during test execution.
proj_path <- function(...) file.path(PROJECT_ROOT, ...)
