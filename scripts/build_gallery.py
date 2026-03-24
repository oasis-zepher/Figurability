#!/usr/bin/env python3
"""Build gallery_data.json by scanning Figurability asset folders.

This script walks through top-level category directories whose names start
with digits (e.g. 02_Differential_Analysis), discovers preview images,
maps related code/data files, and writes a JSON catalog consumed by index.html.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg"}
CODE_SUFFIX_PREFERENCE = (".R", ".py")


@dataclass
class GalleryItem:
	"""Structured record for a single chart card on the gallery page."""

	category: str
	chart_name: str
	image_path: str
	code_path: str | None
	data_path: str | None


def pretty_text(raw: str) -> str:
	"""Convert snake/camel-ish labels into human-readable title case.

	Examples:
	- "Differential_Analysis" -> "Differential Analysis"
	- "sankey_feature_flow" -> "Sankey Feature Flow"
	"""
	text = raw.replace("_", " ").replace("-", " ").strip()
	text = re.sub(r"\s+", " ", text)
	return text.title()


def category_from_dirname(dirname: str) -> str:
	"""Extract a display category from numeric-prefixed folder names.

	Example:
	- "02_Differential_Analysis" -> "Differential Analysis"
	"""
	cleaned = re.sub(r"^\d+[\s._-]*", "", dirname)
	return pretty_text(cleaned or dirname)


def find_code_file(folder: Path, base_name: str) -> Path | None:
	"""Find matching code file using preferred extension order."""
	for suffix in CODE_SUFFIX_PREFERENCE:
		candidate = folder / f"{base_name}{suffix}"
		if candidate.exists():
			return candidate
	return None


def find_data_file(folder: Path, base_name: str) -> Path | None:
	"""Find matching CSV data file.

	Supports both common styles:
	- <name>_data.csv
	- <name>.csv
	"""
	candidates = (
		folder / f"{base_name}_data.csv",
		folder / f"{base_name}.csv",
	)
	for candidate in candidates:
		if candidate.exists():
			return candidate
	return None


def iter_category_dirs(root: Path) -> Iterable[Path]:
	"""Yield top-level folders with names that start with digits."""
	for child in sorted(root.iterdir()):
		if child.is_dir() and re.match(r"^\d+", child.name):
			yield child


def build_gallery_items(root: Path) -> list[GalleryItem]:
	"""Collect all gallery items from the project structure."""
	items: list[GalleryItem] = []

	for category_dir in iter_category_dirs(root):
		category = category_from_dirname(category_dir.name)

		for image in sorted(category_dir.iterdir()):
			if not image.is_file():
				continue
			if image.suffix.lower() not in IMAGE_SUFFIXES:
				continue
			if "_demo" not in image.stem:
				continue

			# Strip the demo suffix to recover the logical chart base name.
			base_name = re.sub(r"_demo$", "", image.stem, flags=re.IGNORECASE)
			chart_name = pretty_text(base_name)

			code_file = find_code_file(category_dir, base_name)
			data_file = find_data_file(category_dir, base_name)

			items.append(
				GalleryItem(
					category=category,
					chart_name=chart_name,
					image_path=image.relative_to(root).as_posix(),
					code_path=code_file.relative_to(root).as_posix() if code_file else None,
					data_path=data_file.relative_to(root).as_posix() if data_file else None,
				)
			)

	return sorted(items, key=lambda item: (item.category, item.chart_name))


def write_gallery_json(items: list[GalleryItem], output_path: Path) -> None:
	"""Write catalog as UTF-8 JSON with stable formatting for Git diffs."""
	payload = [asdict(item) for item in items]
	output_path.write_text(
		json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
		encoding="utf-8",
	)


def main() -> None:
	script_path = Path(__file__).resolve()
	root = script_path.parent.parent
	output = root / "gallery_data.json"

	items = build_gallery_items(root)
	write_gallery_json(items, output)

	print(f"Built {len(items)} gallery item(s) -> {output}")


if __name__ == "__main__":
	main()
