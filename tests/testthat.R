# Standard R testthat entry point. Run via:
#   & "C:\Program Files\R\R-4.3.1\bin\Rscript.exe" tests/testthat.R
# from the project root. tests/testthat/setup.R (auto-sourced by testthat)
# handles sourcing the pipeline scripts and defines proj_path() for
# root-relative data paths -- see that file for why.

library(testthat)

test_dir("tests/testthat", reporter = "summary")
