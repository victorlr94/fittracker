"""Emite `app/assets/catalog/manifest.json` — versión y metadatos por
dataset. La app compara `version` contra `app_setting.catalog_version_*`
para decidir si vuelve a sembrar el catálogo (docs/03-ingesta-de-datos.md).
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class DatasetManifestEntry:
    version: int
    row_count: int
    sha256: str
    source: str
    source_ref: str
    license: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "version": self.version,
            "row_count": self.row_count,
            "sha256": self.sha256,
            "source": self.source,
            "source_ref": self.source_ref,
            "license": self.license,
        }


def sha256_of_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def write_manifest(output_dir: Path, datasets: dict[str, DatasetManifestEntry]) -> Path:
    """Escribe manifest.json. A diferencia de los archivos de datos, el
    manifiesto SÍ lleva marca de tiempo de generación — es metadata sobre
    el build, no parte del contenido del catálogo."""
    manifest = {
        "generated_at": datetime.now(UTC).isoformat(),
        "datasets": {name: entry.to_dict() for name, entry in datasets.items()},
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return manifest_path
