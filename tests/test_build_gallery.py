from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


def _load_module():
    module_path = Path(__file__).resolve().parents[1] / "scripts" / "build_gallery.py"
    spec = importlib.util.spec_from_file_location("build_gallery", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load module from {module_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


build_gallery = _load_module()


class BuildGalleryTest(unittest.TestCase):
    def test_collect_gallery_items_returns_sorted_cards(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            category = root / "02_Differential_Analysis"
            category.mkdir()
            (category / "zebra_demo.png").write_text("", encoding="utf-8")
            (category / "zebra.R").write_text("# script", encoding="utf-8")
            (category / "zebra_data.csv").write_text("x,y\n1,2\n", encoding="utf-8")
            (category / "alpha_demo.png").write_text("", encoding="utf-8")
            (category / "alpha.py").write_text("print('ok')\n", encoding="utf-8")
            (category / "alpha.csv").write_text("x,y\n1,2\n", encoding="utf-8")

            items = build_gallery.collect_gallery_items(root)

        self.assertEqual([item.chart_name for item in items], ["Alpha", "Zebra"])
        self.assertEqual(items[0].image_path, "02_Differential_Analysis/alpha_demo.png")
        self.assertEqual(items[0].code_path, "02_Differential_Analysis/alpha.py")
        self.assertEqual(items[0].data_path, "02_Differential_Analysis/alpha.csv")

    def test_collect_validation_issues_reports_missing_assets(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            category = root / "05_Correlation_Network"
            category.mkdir()
            (category / "pairwise_demo.png").write_text("", encoding="utf-8")
            (category / "pairwise.R").write_text("# script", encoding="utf-8")

            issues = build_gallery.collect_validation_issues(root)

        self.assertEqual(
            issues,
            ["05_Correlation_Network/pairwise_demo.png: missing matching .csv data template"],
        )

    def test_collect_validation_issues_requires_preview_image(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            category = root / "06_Clinical_Phenotypes"
            category.mkdir()
            (category / "clinical_trend_ribbon.R").write_text("# script", encoding="utf-8")
            (category / "clinical_trend_ribbon_data.csv").write_text("x,y\n1,2\n", encoding="utf-8")

            issues = build_gallery.collect_validation_issues(root)

        self.assertEqual(
            issues,
            ["06_Clinical_Phenotypes: no preview image matched '*_demo.(png|jpg|jpeg)'"],
        )


if __name__ == "__main__":
    unittest.main()
