#!/usr/bin/env python3
"""Build ``gallery_data.json`` by scanning flat chart asset folders.

This script is intentionally simple and deterministic:

1. Scan the Figurability project root.
2. Only keep top-level folders whose names start with digits, such as:
   - ``02_Differential_Analysis``
   - ``05_Correlation_Network``
3. Inside each category folder, locate preview images ending with:
   - ``_demo.png``
   - ``_demo.jpg``
   - ``_demo.jpeg``
4. Infer the chart title, matching code file, and matching data file.
5. Write a clean JSON array to ``gallery_data.json`` in the project root.

The generated JSON is consumed directly by ``index.html``.
"""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path


# Supported file suffixes for preview images and source code.
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg"}
CODE_SUFFIXES = (".R", ".py")


@dataclass
class GalleryItem:
    """One gallery card record used by the front-end."""

    category: str
    chart_name: str
    image_path: str
    code_path: str | None
    data_path: str | None


def prettify_label(raw_text: str) -> str:
    """Convert underscored/sluggified text into readable title case.

    Examples
    --------
    ``Differential_Analysis`` -> ``Differential Analysis``
    ``sankey_feature_flow`` -> ``Sankey Feature Flow``
    """

    normalized = raw_text.replace("_", " ").replace("-", " ").strip()
    normalized = re.sub(r"\s+", " ", normalized)
    return normalized.title()


def is_category_dir(path: Path) -> bool:
    """Return True only for top-level folders that begin with digits."""

    return path.is_dir() and re.match(r"^\d+", path.name) is not None


def infer_category(folder_name: str) -> str:
    """Strip numeric prefix and convert the remaining text into a label.

    Example
    -------
    ``02_Differential_Analysis`` -> ``Differential Analysis``
    """

    cleaned = re.sub(r"^\d+[\s._-]*", "", folder_name)
    return prettify_label(cleaned or folder_name)


def infer_chart_basename(preview_file: Path) -> str:
    """Recover the logical chart basename from a ``*_demo`` preview file."""

    return re.sub(r"_demo$", "", preview_file.stem, flags=re.IGNORECASE)


def find_matching_code_file(folder: Path, base_name: str) -> Path | None:
    """Find a same-basename code file using the preferred suffix order."""

    for suffix in CODE_SUFFIXES:
        candidate = folder / f"{base_name}{suffix}"
        if candidate.exists():
            return candidate
    return None


def find_matching_data_file(folder: Path, base_name: str) -> Path | None:
    """Find a same-basename CSV file.

    Supported naming styles:
    - ``<name>_data.csv``
    - ``<name>.csv``
    """

    candidates = (
        folder / f"{base_name}_data.csv",
        folder / f"{base_name}.csv",
    )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def collect_gallery_items(project_root: Path) -> list[GalleryItem]:
    """Scan the project and return all chart cards in stable order."""

    items: list[GalleryItem] = []

    for category_dir in sorted(project_root.iterdir()):
        if not is_category_dir(category_dir):
            continue

        category_label = infer_category(category_dir.name)

        for preview in sorted(category_dir.iterdir()):
            if not preview.is_file():
                continue
            if preview.suffix.lower() not in IMAGE_SUFFIXES:
                continue
            if not re.search(r"_demo$", preview.stem, flags=re.IGNORECASE):
                continue

            base_name = infer_chart_basename(preview)
            code_file = find_matching_code_file(category_dir, base_name)
            data_file = find_matching_data_file(category_dir, base_name)

            items.append(
                GalleryItem(
                    category=category_label,
                    chart_name=prettify_label(base_name),
                    image_path=preview.relative_to(project_root).as_posix(),
                    code_path=code_file.relative_to(project_root).as_posix() if code_file else None,
                    data_path=data_file.relative_to(project_root).as_posix() if data_file else None,
                )
            )

    return sorted(items, key=lambda item: (item.category, item.chart_name))


def write_gallery_json(items: list[GalleryItem], output_file: Path) -> None:
    """Write human-readable UTF-8 JSON for the front-end."""

    payload = [asdict(item) for item in items]
    output_file.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    """Entry point for local CLI usage."""

    project_root = Path(__file__).resolve().parent.parent
    output_file = project_root / "gallery_data.json"

    items = collect_gallery_items(project_root)
    write_gallery_json(items, output_file)

    print(f"Built {len(items)} gallery item(s) -> {output_file}")


if __name__ == "__main__":
    main()
