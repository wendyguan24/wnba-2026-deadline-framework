# Tests: possession-table invariants. See HANDOFF §5a and R/03_possessions.R.

library(testthat)

test_that("summed possession points equal each team's final box score for a sample of games", {
  skip("Not yet implemented — see HANDOFF §5a, R/03_possessions.R")
})

test_that("possession_id is unique within a game and possessions do not overlap", {
  skip("Not yet implemented — see HANDOFF §5a, R/03_possessions.R")
})

test_that("and-one sequences (made FG + shooting foul + FTs) collapse to one possession", {
  skip("Not yet implemented — see HANDOFF §5a, R/03_possessions.R handle_and_ones()")
})

test_that("technical free throws do not end or start a possession", {
  skip("Not yet implemented — see HANDOFF §5a, R/03_possessions.R handle_technical_fts()")
})

test_that("every possession has exactly one team and one opponent", {
  skip("Not yet implemented — see HANDOFF §5a, R/03_possessions.R")
})
