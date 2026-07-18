# Tests: clock-parsing round-trip. See HANDOFF §4 and R/02_parse_pbp.R
# parse_clock().

library(testthat)

test_that("parse_clock converts PT09M57.00S to 597 seconds", {
  skip("Not yet implemented — see HANDOFF §4, R/02_parse_pbp.R parse_clock()")
})

test_that("parse_clock handles period boundaries PT12M00.00S and PT00M00.00S", {
  skip("Not yet implemented — see HANDOFF §4, R/02_parse_pbp.R parse_clock()")
})

test_that("parse_clock handles fractional seconds correctly", {
  skip("Not yet implemented — see HANDOFF §4, R/02_parse_pbp.R parse_clock()")
})

test_that("parsed clock values are monotonically non-increasing within a period, ordered by orderNumber", {
  skip("Not yet implemented — see HANDOFF §4, R/02_parse_pbp.R")
})
