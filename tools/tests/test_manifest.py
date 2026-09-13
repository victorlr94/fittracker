"""El manifiesto debe ser determinista dado el mismo contenido, y su
escritura no debe depender de nada externo (sin red, sin reloj fijado)."""

import json
from pathlib import Path

from fittracker_data.manifest import (
    DatasetManifestEntry,
    sha256_of_bytes,
    write_manifest,
)


def test_sha256_es_determinista_para_el_mismo_contenido() -> None:
    payload = b'[{"a": 1}]'
    assert sha256_of_bytes(payload) == sha256_of_bytes(payload)
    assert sha256_of_bytes(payload) != sha256_of_bytes(b'[{"a": 2}]')


def test_write_manifest_produce_json_valido_con_las_entradas(tmp_path: Path) -> None:
    entry = DatasetManifestEntry(
        version=3,
        row_count=876,
        sha256="abc123",
        source="yuhonas/free-exercise-db",
        source_ref="9c1f2ab",
        license="Unlicense",
    )

    manifest_path = write_manifest(tmp_path, {"exercises": entry})

    assert manifest_path == tmp_path / "manifest.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert data["datasets"]["exercises"]["row_count"] == 876
    assert data["datasets"]["exercises"]["license"] == "Unlicense"
    assert "generated_at" in data
