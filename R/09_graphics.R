# 09_graphics.R
#
# Purpose: Publication charts for the writeup: schedule-adjusted identity
#   map (raw vs. adjusted rank), shot generation vs. shot making scatter
#   (the GSV outlier storyline), and the fitted trajectory small multiples.
#   See HANDOFF §5c, §5d, §5e; AMENDMENT_01 §1 (trajectory column).
#
# Inputs:  output/team_rank_deltas.csv,
#          output/icc_table.csv,
#          data/processed/team_generation_making.rds,
#          data/processed/team_trajectories.rds
# Outputs: output/identity_map.png,
#          output/generation_vs_making.png,
#          output/trajectory_small_multiples.png

library(tidyverse)

# Expansion / case-study teams highlighted across all plots.
EXPANSION_TEAMS <- c("GSV", "TOR", "PDX")

#' Shared WHoopsLab plotting theme
#'
#' @return a ggplot2 theme object
theme_whoopslab <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.title.position = "plot",
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

#' Raw-rank vs. adjusted-rank identity map for the top ICC identity metrics
#'
#' @param rank_deltas tibble from output/team_rank_deltas.csv
#' @param icc_table tibble from output/icc_table.csv
#' @return a ggplot object
plot_identity_map <- function(rank_deltas, icc_table) {
  top_metrics <- icc_table %>%
    arrange(desc(icc)) %>%
    slice_head(n = 4) %>%
    pull(metric)

  plot_data <- rank_deltas %>%
    filter(metric %in% top_metrics) %>%
    mutate(is_expansion = team %in% EXPANSION_TEAMS)

  ggplot(plot_data, aes(x = raw_rank, y = adjusted_rank)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey50") +
    geom_point(aes(color = is_expansion, size = is_expansion)) +
    geom_text(
      data = filter(plot_data, is_expansion),
      aes(label = team),
      nudge_x = 0.5, nudge_y = 0.5, size = 3, show.legend = FALSE
    ) +
    scale_color_manual(values = c(`TRUE` = "#d95f02", `FALSE` = "grey60"), guide = "none") +
    scale_size_manual(values = c(`TRUE` = 2.5, `FALSE` = 1.5), guide = "none") +
    scale_x_reverse(breaks = 1:15) +
    scale_y_reverse(breaks = 1:15) +
    facet_wrap(~ metric) +
    labs(
      title = "Schedule-adjusted identity: raw rank vs adjusted rank",
      subtitle = str_wrap(
        "Top 4 identity metrics by ICC. Points off the dashed line moved under schedule adjustment. Expansion teams highlighted.",
        width = 100
      ),
      x = "Raw rank (1 = best)",
      y = "Adjusted rank (1 = best)"
    ) +
    theme_whoopslab()
}

#' Shot generation vs. shot making scatter, teams labeled, GSV highlighted
#'
#' @param team_generation_making tibble
#' @return a ggplot object
plot_generation_vs_making <- function(team_generation_making) {
  plot_data <- team_generation_making %>%
    mutate(is_gsv = team == "GSV")

  med_gen <- median(plot_data$shot_generation_per100)
  med_mak <- median(plot_data$shot_making_per100)

  ggplot(plot_data, aes(x = shot_generation_per100, y = shot_making_per100)) +
    geom_vline(xintercept = med_gen, linetype = "dotted", color = "grey50") +
    geom_hline(yintercept = med_mak, linetype = "dotted", color = "grey50") +
    geom_point(aes(color = is_gsv, size = is_gsv)) +
    geom_text(aes(label = team), nudge_y = 0.3, size = 3, show.legend = FALSE) +
    scale_color_manual(values = c(`TRUE` = "#d95f02", `FALSE` = "grey40"), guide = "none") +
    scale_size_manual(values = c(`TRUE` = 3.5, `FALSE` = 2), guide = "none") +
    labs(
      title = "Shot generation vs shot making (per 100 possessions)",
      subtitle = str_wrap(
        "Generation = expected points per 100 given shot diet (stratified expected-points baseline). Making = actual minus expected. GSV highlighted.",
        width = 90
      ),
      x = "Shot generation (expected pts / 100)",
      y = "Shot making (actual minus expected / 100)"
    ) +
    theme_whoopslab()
}

#' Small multiples of fitted per-team trajectory slopes (coefficient plot)
#'
#' @param team_trajectories tibble
#' @return a ggplot object
plot_trajectory_small_multiples <- function(team_trajectories) {
  plot_data <- team_trajectories %>%
    mutate(is_expansion = team %in% EXPANSION_TEAMS)

  ggplot(plot_data, aes(x = slope, y = reorder(team, slope), color = is_expansion)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
    geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.2) +
    geom_point(size = 2) +
    scale_color_manual(values = c(`TRUE` = "#d95f02", `FALSE` = "grey40"), guide = "none") +
    facet_wrap(~ metric, scales = "free_x") +
    labs(
      title = "Trajectory: fitted per-team slopes by metric",
      subtitle = str_wrap(
        "Per-team trajectory slopes with 95% intervals. Most intervals span zero, so per-team labels are directional, not standalone claims. Expansion teams highlighted.",
        width = 100
      ),
      x = "Slope (metric change per game)",
      y = NULL
    ) +
    theme_whoopslab()
}

main <- function() {
  rank_deltas <- read_csv("output/team_rank_deltas.csv", show_col_types = FALSE)
  icc_table <- read_csv("output/icc_table.csv", show_col_types = FALSE)
  team_generation_making <- readRDS("data/processed/team_generation_making.rds")
  team_trajectories <- readRDS("data/processed/team_trajectories.rds")

  p_identity <- plot_identity_map(rank_deltas, icc_table)
  p_generation <- plot_generation_vs_making(team_generation_making)
  p_trajectory <- plot_trajectory_small_multiples(team_trajectories)

  ggsave("output/identity_map.png", p_identity, width = 9, height = 7, dpi = 150)
  ggsave("output/generation_vs_making.png", p_generation, width = 8, height = 6, dpi = 150)
  ggsave("output/trajectory_small_multiples.png", p_trajectory, width = 9, height = 7, dpi = 150)

  message("Wrote output/identity_map.png")
  message("Wrote output/generation_vs_making.png")
  message("Wrote output/trajectory_small_multiples.png")
}

if (sys.nframe() == 0) {
  main()
}
