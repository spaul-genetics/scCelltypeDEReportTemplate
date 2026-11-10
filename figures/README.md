# Generated template figures

This directory is recreated by `scripts/generate_mock_data.R` during rendering.

- `mock_umap.png` is the unlabeled cluster-colored UMAP background used beneath interactive cluster circles.
- `mock_umap_by_sample.png` is the companion sample-colored UMAP with a sample legend and translucent final-cluster numbers.
- `cluster_XX_marker_dotplot.png` and `cluster_XX_sample_composition.png` populate the supporting-figure tabs. Marker dotplots use the production report's blue-white-red scaled-expression fill, percent-expressing dot size, colored evidence-source labels, and a pale-yellow rectangle around the focal cluster.
- `cluster_XX_standard_volcano.png`, `cluster_XX_prevalence_volcano.png`, and `cluster_XX_direct_contrast.png` populate the full-width DE section.

All values are synthetic. PNGs are used so the final HTML demonstrates the same zoom and tab interactions as the production report while remaining portable through Quarto's `embed-resources` option.
