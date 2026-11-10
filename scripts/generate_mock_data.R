#!/usr/bin/env Rscript
# Analysis purpose: Generate deterministic synthetic data and figures for the
# reusable interactive cluster-review report template.
# Inputs: none. Outputs: transparent CSV files in data/ and PNG files in figures/.
# Reproducibility: fixed seed 1263; no project expression or DE results are read.

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
  library(ggrepel)
})

set.seed(1263)
data_dir <- "data"
figure_dir <- "figures"
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

cluster_ids <- 0:7
cluster_names <- c(
  "State alpha", "State beta", "State gamma", "State delta",
  "State epsilon", "State zeta", "State eta", "State theta"
)
sample_names <- c("Control", "Variant A", "Variant B")
sample_colors <- c("Control" = "#009E73", "Variant A" = "#D55E00", "Variant B" = "#0072B2")
cluster_centers <- data.frame(
  cluster = cluster_ids,
  x = c(-5.2, -2.0, 1.5, 4.8, -4.1, -0.8, 3.0, 5.2),
  y = c(3.6, 4.9, 4.0, 2.8, -1.8, -3.6, -2.4, -1.0)
)
cluster_sizes <- c(330, 285, 360, 270, 315, 245, 310, 285)
sample_probabilities <- list(
  c(.45, .30, .25), c(.34, .37, .29), c(.25, .48, .27), c(.38, .24, .38),
  c(.31, .32, .37), c(.50, .22, .28), c(.28, .34, .38), c(.36, .41, .23)
)

cells <- bind_rows(lapply(seq_along(cluster_ids), function(i) {
  n <- cluster_sizes[i]
  angle <- (i - 1) * pi / 8
  z1 <- rnorm(n, sd = .86)
  z2 <- rnorm(n, sd = .55)
  data.frame(
    cluster = cluster_ids[i],
    UMAP_1 = cluster_centers$x[i] + cos(angle) * z1 - sin(angle) * z2,
    UMAP_2 = cluster_centers$y[i] + sin(angle) * z1 + cos(angle) * z2,
    sample = sample(sample_names, n, replace = TRUE, prob = sample_probabilities[[i]])
  )
}))
cells$cell_id <- sprintf("mock_cell_%05d", seq_len(nrow(cells)))
cells$batch <- ifelse(cells$sample == "Control", "Batch 1",
                      ifelse(cells$sample == "Variant A", "Batch 2", "Batch 3"))
cells <- cells[, c("cell_id", "UMAP_1", "UMAP_2", "cluster", "sample", "batch")]
write.csv(cells, gzfile(file.path(data_dir, "mock_cells.csv.gz")), row.names = FALSE)

# Use limits with the same aspect ratio as the PNG so normalized centroids align
# exactly with HTML circles laid over the raster image.
image_width <- 8
image_height <- 5.2
target_aspect <- image_width / image_height
xl <- range(cells$UMAP_1)
yl <- range(cells$UMAP_2)
xl <- mean(xl) + (xl - mean(xl)) * 1.05
yl <- mean(yl) + (yl - mean(yl)) * 1.05
if (diff(xl) / diff(yl) > target_aspect) {
  wanted_y <- diff(xl) / target_aspect
  yl <- mean(yl) + c(-.5, .5) * wanted_y
} else {
  wanted_x <- diff(yl) * target_aspect
  xl <- mean(xl) + c(-.5, .5) * wanted_x
}

cluster_colors <- setNames(hue_pal(l = 58, c = 95)(length(cluster_ids)), cluster_ids)
p_umap <- ggplot(cells, aes(UMAP_1, UMAP_2, color = factor(cluster))) +
  geom_point(size = .42, alpha = .72, stroke = 0) +
  scale_color_manual(values = cluster_colors) +
  coord_cartesian(xlim = xl, ylim = yl, expand = FALSE) +
  theme_void() +
  theme(legend.position = "none", plot.margin = margin(0, 0, 0, 0))
ggsave(file.path(figure_dir, "mock_umap.png"), p_umap, width = image_width,
       height = image_height, dpi = 220, bg = "white")

hotspots <- cells |>
  group_by(cluster) |>
  summarise(UMAP_1 = median(UMAP_1), UMAP_2 = median(UMAP_2), cells = n(), .groups = "drop") |>
  mutate(
    pos_x = (UMAP_1 - xl[1]) / diff(xl),
    pos_y = 1 - (UMAP_2 - yl[1]) / diff(yl)
  )
write.csv(hotspots, file.path(data_dir, "cluster_hotspots.csv"), row.names = FALSE)

# Sample-colored companion to the cluster UMAP. Cluster numbers are drawn into
# this image because the interactive HTML circles are hidden outside the
# Clusters tab, matching the production report's orientation aid.
p_umap_sample <- ggplot(cells, aes(UMAP_1, UMAP_2, color = sample)) +
  geom_point(size = .72, alpha = .95, stroke = 0) +
  geom_label(
    data = hotspots,
    aes(x = UMAP_1, y = UMAP_2, label = cluster),
    inherit.aes = FALSE, colour = "black", fill = "white", alpha = .55,
    label.size = .18, label.padding = grid::unit(.12, "lines"),
    fontface = "bold", size = 2.7, show.legend = FALSE
  ) +
  scale_color_manual(values = sample_colors) +
  ggtitle("Synthetic UMAP · sample") +
  labs(
    subtitle = "Larger, higher-contrast cells; translucent numbers show final clusters",
    colour = NULL
  ) +
  theme_void(base_size = 10) +
  theme(
    plot.title = element_text(face = "bold", hjust = .5, size = 12),
    plot.subtitle = element_text(hjust = .5, colour = "grey30", size = 8.5),
    legend.position = "right", legend.text = element_text(size = 8),
    plot.margin = margin(8, 8, 8, 8)
  )
ggsave(
  file.path(figure_dir, "mock_umap_by_sample.png"), p_umap_sample,
  width = 10, height = 6.2, dpi = 200, bg = "white"
)

genes <- sprintf("GENE_%02d", 1:16)
marker_summary <- expand_grid(cluster = cluster_ids, gene = genes) |>
  mutate(
    gene_index = as.integer(sub("GENE_", "", gene)),
    preferred_cluster = (gene_index - 1L) %% length(cluster_ids),
    mean_expression = pmax(0, rlnorm(n(), -1.0, .45) +
      ifelse(cluster == preferred_cluster, runif(n(), 1.2, 2.7), 0)),
    percent_expressing = pmin(100, pmax(1, 8 + 24 * mean_expression + rnorm(n(), 0, 8)))
  ) |>
  group_by(gene) |>
  mutate(
    scaled_mean_expression = as.numeric(scale(mean_expression)),
    scaled_mean_expression = pmax(-2.5, pmin(2.5, scaled_mean_expression))
  ) |>
  ungroup() |>
  select(cluster, gene, mean_expression, scaled_mean_expression, percent_expressing)
write.csv(marker_summary, file.path(data_dir, "marker_summary.csv"), row.names = FALSE)

composition <- cells |>
  count(cluster, sample, name = "cells") |>
  group_by(cluster) |>
  mutate(proportion = cells / sum(cells)) |>
  ungroup()
write.csv(composition, file.path(data_dir, "sample_composition.csv"), row.names = FALSE)

source_colors <- c(
  "Canonical marker" = "#1B7837",
  "Top cluster marker" = "#762A83",
  "Canonical + marker" = "#D95F02",
  "Lineage marker (expected absent)" = "#2166AC"
)
plot_theme <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))

for (cl in cluster_ids) {
  focal_stats <- marker_summary |>
    filter(cluster == cl) |>
    arrange(desc(mean_expression))
  canonical_genes <- genes[((seq_along(genes) - 1L) %% length(cluster_ids)) == cl]
  top_genes <- focal_stats |>
    filter(!gene %in% canonical_genes) |>
    slice_head(n = 4) |>
    pull(gene)
  exclusion_genes <- genes[((seq_along(genes) - 1L) %% length(cluster_ids)) ==
                             ((cl + 4L) %% length(cluster_ids))]
  selected_genes <- unique(c(canonical_genes, top_genes, exclusion_genes))
  gene_labels <- tibble(
    gene = selected_genes,
    gene_source = case_when(
      gene == canonical_genes[1] ~ "Canonical + marker",
      gene %in% canonical_genes ~ "Canonical marker",
      gene %in% top_genes ~ "Top cluster marker",
      TRUE ~ "Lineage marker (expected absent)"
    ),
    x = seq_along(selected_genes),
    y = 0.15
  )
  marker_plot_data <- marker_summary |>
    filter(gene %in% selected_genes) |>
    mutate(
      x = match(gene, selected_genes),
      y = match(cluster, cluster_ids)
    )
  target_y <- match(cl, cluster_ids)
  p_marker <- ggplot(marker_plot_data, aes(x, y)) +
    annotate(
      "rect", xmin = 0.5, xmax = length(selected_genes) + 0.5,
      ymin = target_y - 0.45, ymax = target_y + 0.45,
      fill = "#FFF2AE", colour = "#B8860B", linewidth = 0.5
    ) +
    geom_point(
      aes(size = percent_expressing, fill = scaled_mean_expression),
      shape = 21, colour = "grey20", stroke = 0.2
    ) +
    geom_text(
      data = gene_labels,
      aes(x = x, y = y, label = gene, colour = gene_source),
      inherit.aes = FALSE, angle = 55, hjust = 1, vjust = 0.5,
      size = 3.2, fontface = "bold"
    ) +
    scale_x_continuous(
      breaks = seq_along(selected_genes), labels = NULL,
      expand = expansion(add = c(0.6, 0.6))
    ) +
    scale_y_continuous(
      breaks = seq_along(cluster_ids), labels = cluster_ids,
      limits = c(-1.2, length(cluster_ids) + 0.6), expand = c(0, 0)
    ) +
    scale_size_continuous(
      name = "Percent expressed", range = c(0, 7), limits = c(0, 100)
    ) +
    scale_fill_gradient2(
      name = "Scaled mean expression", low = "#2166AC", mid = "white",
      high = "#B2182B", midpoint = 0
    ) +
    scale_colour_manual(
      name = "Gene-label source", values = source_colors, drop = FALSE
    ) +
    labs(title = paste("Synthetic marker summary — cluster", cl),
         subtitle = paste(
           "Orange = canonical + marker; green = canonical only;",
           "purple = top marker only; blue = expected absent"
         ),
         x = NULL, y = "Synthetic cluster") +
    coord_cartesian(clip = "off") +
    plot_theme +
    theme(
      axis.ticks.x = element_blank(), panel.grid.major.x = element_blank(),
      plot.margin = margin(10, 10, 100, 10), legend.position = "right"
    )
  ggsave(file.path(figure_dir, sprintf("cluster_%02d_marker_dotplot.png", cl)),
         p_marker, width = 10, height = 6.6, dpi = 170, bg = "white")

  comp <- composition |> filter(cluster == cl)
  p_comp <- ggplot(comp, aes(sample, cells, fill = sample)) +
    geom_col(width = .68) +
    geom_text(aes(label = paste0(cells, "\n", percent(proportion, accuracy = .1))),
              vjust = -.25, size = 3.6) +
    scale_fill_manual(values = sample_colors, guide = "none") +
    expand_limits(y = max(comp$cells) * 1.18) +
    labs(title = paste("Synthetic sample composition — cluster", cl),
         subtitle = "Counts and within-cluster proportions", x = NULL, y = "Mock cells") +
    plot_theme
  ggsave(file.path(figure_dir, sprintf("cluster_%02d_sample_composition.png", cl)),
         p_comp, width = 8, height = 5.4, dpi = 170, bg = "white")
}

de_genes <- sprintf("MOCK_GENE_%03d", 1:700)
comparisons <- c("Variant A vs Control", "Variant B vs Control", "Variant A vs Variant B")
de_results <- bind_rows(lapply(cluster_ids, function(cl) {
  bind_rows(lapply(seq_along(comparisons), function(j) {
    n <- length(de_genes)
    signal <- rep(0, n)
    signal[seq(15 + 5 * j, 55 + 5 * j)] <- rnorm(41, 1.7 - .1 * j, .45)
    signal[seq(90 + 4 * cl, 125 + 4 * cl)] <- rnorm(36, -1.6 + .05 * j, .40)
    logfc <- rnorm(n, 0, .38) + signal
    pct_1 <- plogis(rnorm(n, -1.1 + .25 * abs(logfc), .9))
    pct_2 <- plogis(rnorm(n, -1.1, .9))
    raw_p <- pmin(1, 2 * pnorm(-abs(logfc) / runif(n, .18, .55)))
    padj <- p.adjust(raw_p, method = "BH")
    data.frame(
      cluster = cl, comparison = comparisons[j], gene = de_genes,
      avg_log2FC = logfc, p_val_adj = padj,
      pct_1 = pct_1, pct_2 = pct_2,
      pct_difference = pct_1 - pct_2
    )
  }))
}))
de_results <- de_results |>
  mutate(
    significant = p_val_adj < .01 & abs(avg_log2FC) >= 1,
    prevalence_significant = significant & abs(pct_difference) >= .15 &
      pmax(pct_1, pct_2) >= .10,
    direction = case_when(
      significant & avg_log2FC > 0 ~ "Higher in first group",
      significant & avg_log2FC < 0 ~ "Higher in second group",
      TRUE ~ "Below threshold"
    )
  )
write.csv(de_results, gzfile(file.path(data_dir, "de_results.csv.gz")), row.names = FALSE)

de_colors <- c("Higher in first group" = "#D55E00",
               "Higher in second group" = "#0072B2",
               "Below threshold" = "#C4C7CC")
volcano_theme <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"),
        legend.position = "top")

label_top <- function(dat, flag, n = 10) {
  dat |> filter(.data[[flag]]) |>
    arrange(p_val_adj, desc(abs(avg_log2FC))) |>
    slice_head(n = n)
}

for (cl in cluster_ids) {
  standard <- de_results |> filter(cluster == cl, comparison == comparisons[1])
  labels <- label_top(standard, "significant")
  p_standard <- ggplot(standard, aes(avg_log2FC, -log10(pmax(p_val_adj, 1e-300)))) +
    geom_point(aes(color = direction), size = 1.45, alpha = .78) +
    geom_text_repel(data = labels, aes(label = gene), size = 3, max.overlaps = Inf) +
    scale_color_manual(values = de_colors) +
    geom_vline(xintercept = c(-1, 1), linetype = 2, color = "grey45") +
    geom_hline(yintercept = 2, linetype = 2, color = "grey45") +
    labs(title = paste("Standard volcano — cluster", cl),
         subtitle = comparisons[1], x = "Synthetic log2 fold change",
         y = "-log10 adjusted p-value", color = NULL) + volcano_theme
  ggsave(file.path(figure_dir, sprintf("cluster_%02d_standard_volcano.png", cl)),
         p_standard, width = 9, height = 6, dpi = 180, bg = "white")

  prevalence <- standard |>
    mutate(prevalence_class = case_when(
      prevalence_significant & avg_log2FC > 0 ~ "Higher in first group",
      prevalence_significant & avg_log2FC < 0 ~ "Higher in second group",
      TRUE ~ "Below prevalence threshold"
    ))
  prevalence_labels <- label_top(prevalence, "prevalence_significant")
  p_prevalence <- ggplot() +
    geom_point(data = filter(prevalence, !prevalence_significant),
               aes(avg_log2FC, -log10(pmax(p_val_adj, 1e-300))),
               color = "#C9CCD2", size = .65, alpha = .48) +
    geom_point(data = filter(prevalence, prevalence_significant),
               aes(avg_log2FC, -log10(pmax(p_val_adj, 1e-300)),
                   color = prevalence_class, size = abs(pct_difference)), alpha = .88) +
    geom_text_repel(data = prevalence_labels,
                    aes(avg_log2FC, -log10(pmax(p_val_adj, 1e-300)), label = gene),
                    size = 3, max.overlaps = Inf) +
    scale_color_manual(values = de_colors[1:2]) +
    scale_size(range = c(1.5, 5.5), name = "|Detection-fraction difference|") +
    labs(title = paste("Prevalence-aware volcano — cluster", cl),
         subtitle = "Grey points are fixed-size background; highlighted points also pass prevalence filters",
         x = "Synthetic log2 fold change", y = "-log10 adjusted p-value", color = NULL) +
    volcano_theme
  ggsave(file.path(figure_dir, sprintf("cluster_%02d_prevalence_volcano.png", cl)),
         p_prevalence, width = 9, height = 6, dpi = 180, bg = "white")

  direct <- de_results |> filter(cluster == cl, comparison == comparisons[3])
  direct_labels <- label_top(direct, "significant")
  p_direct <- ggplot(direct, aes(avg_log2FC, -log10(pmax(p_val_adj, 1e-300)))) +
    geom_point(aes(color = direction), size = 1.5, alpha = .80) +
    geom_text_repel(data = direct_labels, aes(label = gene), size = 3, max.overlaps = Inf) +
    scale_color_manual(values = de_colors) +
    geom_vline(xintercept = c(-1, 1), linetype = 2, color = "grey45") +
    geom_hline(yintercept = 2, linetype = 2, color = "grey45") +
    labs(title = paste("Direct variant contrast — cluster", cl),
         subtitle = comparisons[3], x = "Synthetic log2 fold change",
         y = "-log10 adjusted p-value", color = NULL) + volcano_theme
  ggsave(file.path(figure_dir, sprintf("cluster_%02d_direct_contrast.png", cl)),
         p_direct, width = 9, height = 6, dpi = 180, bg = "white")
}

message("Synthetic template data and figures generated")
