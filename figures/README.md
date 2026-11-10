# Generated template figures

The analytical demonstration figures in this directory are recreated by `scripts/generate_mock_data.R` during rendering. The three `report_template_*.png` files are manually captured interface previews for the GitHub README and are not overwritten by the generator.

- `mock_umap.png` is the unlabeled cluster-colored UMAP background used beneath interactive cluster circles.
- `mock_umap_by_sample.png` is the companion sample-colored UMAP with a sample legend and translucent final-cluster numbers.
- `cluster_XX_marker_dotplot.png` and `cluster_XX_sample_composition.png` populate the supporting-figure tabs. Marker dotplots use the production report's blue-white-red scaled-expression fill, percent-expressing dot size, colored evidence-source labels, and a pale-yellow rectangle around the focal cluster.
- `cluster_XX_standard_volcano.png`, `cluster_XX_prevalence_volcano.png`, and `cluster_XX_direct_contrast.png` populate the full-width DE section.
- `report_template_overview.png` shows the interactive UMAP and cluster cards.
- `report_template_marker_evidence.png` shows the focal-cluster marker dotplot and its caption.
- `report_template_de_review.png` shows the full-width DE figure and interpretation-card layout.

All values are synthetic. PNGs are used so the final HTML demonstrates the same zoom and tab interactions as the production report while remaining portable through Quarto's `embed-resources` option.
