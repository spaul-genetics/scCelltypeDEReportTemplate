# Template data and figure generation

`generate_mock_data.R` creates deterministic demonstration data and plots for the report template. It generates synthetic UMAP coordinates from Gaussian cluster clouds, assigns generic sample and batch metadata, constructs invented marker-expression summaries, and simulates differential-expression statistics under three generic contrasts.

The script writes transparent CSV inputs under `data/` and PNG figures under `figures/`. Fixed seed 1263 makes repeated renders identical. No NIAID-1263 expression, marker, annotation, or DE result is read.

The UMAP plotting limits are expanded to match the saved image aspect ratio. Cluster centroids are converted to normalized image coordinates using those exact limits, which is why the circular HTML buttons remain aligned with the rasterized UMAP.

Two upper-left UMAP images are generated from the same synthetic coordinates. `mock_umap.png` is cluster-colored, edge-to-edge, and aligned to interactive HTML circles. `mock_umap_by_sample.png` uses the production report's green/orange/blue sample palette, larger high-opacity points, a legend, and semi-transparent final-cluster labels drawn at median cluster coordinates. The HTML circles are intentionally hidden on the Sample tab.

The marker-dotplot design matches the production report. Mean expression is standardized within each synthetic gene across clusters and clipped to -2.5 to 2.5 for a blue-white-red diverging fill. Dot area represents percent expressing, and each dot has a thin dark outline. A pale-yellow rectangle with a dark-gold border marks the focal cluster. Synthetic gene labels are colored orange for canonical-plus-marker, green for canonical-only, purple for top-marker-only, and blue for an expected-absent lineage example. These categories demonstrate styling only; they are not inferred biological marker calls.
