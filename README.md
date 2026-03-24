# Figurability

Figurability is a flat-structured, automation-friendly chart gallery for bioinformatics and data science visualization assets.

Author: Zephyr

## Project Structure

```text
Figurability/
├── 02_Differential_Analysis/
│   ├── sankey_feature_flow.R
│   ├── sankey_feature_flow_data.csv
│   └── sankey_feature_flow_demo.png
├── 05_Correlation_Network/
│   ├── pairwise_correlation.R
│   ├── pairwise_correlation_data.csv
│   └── pairwise_correlation_demo.png
├── 06_Clinical_Phenotypes/
│   ├── clinical_trend_ribbon.R
│   ├── clinical_trend_ribbon_data.csv
│   └── clinical_trend_ribbon_demo.png
├── Utils/
│   └── themes.R
├── scripts/
│   └── build_gallery.py
├── index.html
└── gallery_data.json
```

## Initialize The Scaffold

Run the following commands from the parent directory:

```bash
mkdir -p Figurability/{02_Differential_Analysis,05_Correlation_Network,06_Clinical_Phenotypes,Utils,scripts}

touch Figurability/02_Differential_Analysis/sankey_feature_flow.R
touch Figurability/02_Differential_Analysis/sankey_feature_flow_data.csv
touch Figurability/02_Differential_Analysis/sankey_feature_flow_demo.png

touch Figurability/05_Correlation_Network/pairwise_correlation.R
touch Figurability/05_Correlation_Network/pairwise_correlation_data.csv
touch Figurability/05_Correlation_Network/pairwise_correlation_demo.png

touch Figurability/06_Clinical_Phenotypes/clinical_trend_ribbon.R
touch Figurability/06_Clinical_Phenotypes/clinical_trend_ribbon_data.csv
touch Figurability/06_Clinical_Phenotypes/clinical_trend_ribbon_demo.png

touch Figurability/Utils/themes.R
touch Figurability/scripts/build_gallery.py
touch Figurability/index.html
touch Figurability/gallery_data.json
```

## Build The Gallery Data

Generate or refresh the front-end catalog:

```bash
python3 scripts/build_gallery.py
```

The script will:

- scan every top-level folder whose name starts with digits
- infer the display category from the folder name
- find preview images ending with `_demo.png`, `_demo.jpg`, or `_demo.jpeg`
- infer chart names from the preview filenames
- match same-basename code files (`.R` or `.py`)
- match same-basename data files (`_data.csv` or `.csv`)
- write all collected metadata into `gallery_data.json`

## Preview Locally

Because the gallery uses `fetch()` to load `gallery_data.json`, preview it with a local static server:

```bash
python3 -m http.server 8000
```

Then open:

```text
http://localhost:8000
```

## SOP: Add A New Chart

1. Pick an existing numeric category folder, or create a new one such as `07_Pathway_Enrichment`.
2. Use one consistent basename for the chart asset group, for example `volcano_pathway`.
3. Add files using this pattern:
   - `volcano_pathway.R` or `volcano_pathway.py`
   - `volcano_pathway_data.csv` or `volcano_pathway.csv`
   - `volcano_pathway_demo.png` or `.jpg`
4. Run:
   - `python3 scripts/build_gallery.py`
5. Open the site locally and confirm the new card appears with the correct category, image, code button, and data button.
6. Commit and push the updated files to GitHub.

This keeps the gallery page synchronized automatically whenever new charts are added.
