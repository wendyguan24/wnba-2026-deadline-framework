# Tests: cdn vs nbastats v2 per-game FGA/FGM/AST/3PA counts reconcile within
# a documented tolerance (mirrors the NCAA project's wehoop reconciliation
# and its documented 2.5-FGM gap — deltas must be reported, not hidden).
# See HANDOFF §4 ("nbastats v2 — reconciliation only") and R/04_reconcile.R.

library(testthat)

test_that("per-game FGA reconciles between cdn and nbastats v2", {
  skip("Not yet implemented — see HANDOFF §4, R/04_reconcile.R reconcile_cdn_v2()")
})

test_that("per-game FGM reconciles between cdn and nbastats v2", {
  skip("Not yet implemented — see HANDOFF §4, R/04_reconcile.R reconcile_cdn_v2()")
})

test_that("per-game AST reconciles between cdn and nbastats v2", {
  skip("Not yet implemented — see HANDOFF §4, R/04_reconcile.R reconcile_cdn_v2()")
})

test_that("per-game 3PA reconciles between cdn and nbastats v2", {
  skip("Not yet implemented — see HANDOFF §4, R/04_reconcile.R reconcile_cdn_v2()")
})

test_that("cdn and v2 agree on 182 total games and 15 teams", {
  skip("Not yet implemented — see HANDOFF §4, R/04_reconcile.R")
})
