# Figurability

Figurability is a flat-structured, automation-friendly gallery for bioinformatics and data science visualization templates.

Author: Zephyr

## 1) Initialize Project Structure

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

Target structure:

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

## 2) Build Gallery Data

Generate gallery metadata:

```bash
python scripts/build_gallery.py
```

The script scans folders that start with numbers, finds files ending with `_demo.png/.jpg/.jpeg`, maps matching code and data files, then writes `gallery_data.json`.

## 3) Publish Locally (Optional)

Open `index.html` with a local static server to ensure `fetch()` works:

```bash
python -m http.server 8000
```

Then visit `http://localhost:8000`.

## 4) SOP: Add a New Chart

1. Pick a category folder with numeric prefix (or create one), for example `07_Pathway_Enrichment`.
2. Add files using consistent base naming:
	- `my_plot.R` or `my_plot.py`
	- `my_plot_data.csv` (or `my_plot.csv`)
	- `my_plot_demo.png` (or `.jpg/.jpeg`)
3. Run:
	- `python scripts/build_gallery.py`
4. Confirm that `gallery_data.json` is updated.
5. Preview `index.html` locally.
6. Commit and push changes to GitHub.

This workflow keeps the gallery synchronized automatically whenever new plots are added.
