"""Descarga con caché simple en data/raw/ y utilidades de red mínimas.

Sin dependencias externas a propósito: una petición GET ocasional no
justifica sumar httpx/requests al proyecto (ver la skill
`python-code-quality`).
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

from fittracker_data.config import DATA_RAW_DIR

logger = logging.getLogger(__name__)

_REQUEST_TIMEOUT_SECONDS = 30.0


class DownloadError(Exception):
    """Fallo al descargar o leer un recurso externo."""


def download_text(url: str, *, cache_name: str, force: bool = False) -> str:
    """Descarga `url` como texto y la cachea en `data/raw/<cache_name>`.

    Si el archivo cacheado ya existe y `force` es False, se reutiliza sin
    volver a golpear la red — así se puede iterar en el resto del pipeline
    sin re-descargar en cada corrida.
    """
    DATA_RAW_DIR.mkdir(parents=True, exist_ok=True)
    cache_path: Path = DATA_RAW_DIR / cache_name

    if cache_path.exists() and not force:
        logger.info("Usando caché local: %s", cache_path)
        return cache_path.read_text(encoding="utf-8")

    logger.info("Descargando %s", url)
    try:
        with urlopen(url, timeout=_REQUEST_TIMEOUT_SECONDS) as response:  # noqa: S310
            raw_bytes: bytes = response.read()
    except (URLError, HTTPError) as exc:
        raise DownloadError(f"No se pudo descargar {url}: {exc}") from exc

    text: str = raw_bytes.decode("utf-8")
    cache_path.write_text(text, encoding="utf-8")
    return text


def fetch_latest_commit_sha(repo: str, *, branch: str = "main") -> str | None:
    """Sha corto del último commit de `repo` en `branch`, para dejar
    trazabilidad en el manifiesto (docs/03-ingesta-de-datos.md).

    Es solo metadata de procedencia: si falla (sin red, límite de tasa de
    la API de GitHub), se degrada a `None` en vez de romper el build —
    perder la referencia exacta del commit no invalida el catálogo.
    """
    url = f"https://api.github.com/repos/{repo}/commits/{branch}"
    try:
        with urlopen(url, timeout=_REQUEST_TIMEOUT_SECONDS) as response:  # noqa: S310
            payload = json.loads(response.read().decode("utf-8"))
        sha = payload["sha"]
    except (URLError, HTTPError, KeyError, ValueError) as exc:
        logger.warning("No se pudo obtener el commit de %s: %s", repo, exc)
        return None

    return str(sha)[:12]
