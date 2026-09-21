"""Last-snapshot cache under `~/.cache/gitframe/`.

The window opens on whatever is on disk and revalidates in the background, so
a missing network shows stale data with a dim marker instead of an empty
screen. Nothing here raises: a broken cache is the same as no cache.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DIR = Path.home() / ".cache" / "gitframe"
LOGIN_FILE = DIR / "login"
AVATAR_TIMEOUT = 10


def _ensure_dir() -> None:
    # Snapshots carry private repository names and commits, so the directory
    # is owner-only. `mkdir(mode=)` does not touch a directory that already
    # exists, hence the explicit chmod.
    DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    DIR.chmod(0o700)


def snapshot_path(login: str, year: int) -> Path:
    return DIR / f"{login}-{year}.json"


def remembered_login() -> str:
    """The login of the last successful fetch, used before the first one."""
    try:
        return LOGIN_FILE.read_text().strip()
    except OSError:
        return ""


def load(year: int, login: str = "") -> dict[str, Any] | None:
    """The cached `viewer` payload for a year, or None."""
    login = login or remembered_login()
    if not login:
        return None
    try:
        return json.loads(snapshot_path(login, year).read_text())
    except (OSError, json.JSONDecodeError):
        return None


def store(viewer: dict[str, Any], year: int) -> None:
    login = viewer.get("login", "")
    if not login:
        return
    try:
        _ensure_dir()
        snapshot_path(login, year).write_text(json.dumps(viewer))
        LOGIN_FILE.write_text(login)
    except OSError:
        pass


def avatar(url: str, login: str) -> str:
    """Local path of the avatar, downloading it once.

    Returns an empty string when there is nothing cached and no network; the
    header then draws the empty circle.
    """
    if not login:
        return ""
    path = DIR / f"avatar-{login}.png"
    if path.exists():
        return str(path)
    if not url:
        return ""
    try:
        _ensure_dir()
        with urllib.request.urlopen(url, timeout=AVATAR_TIMEOUT) as response:
            data = response.read()
        path.write_bytes(data)
    except (urllib.error.URLError, OSError, ValueError):
        return ""
    return str(path)
