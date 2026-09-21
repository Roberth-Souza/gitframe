"""The single QObject QML talks to.

It owns the selected year, the cached snapshot on screen and the background
fetch that revalidates it. Everything it exposes is already shaped for the
view: the heatmap arrives as rows of cells with a shade, the commit rows as
plain strings.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import threading
from datetime import date, datetime
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot

from . import cache, github, stats
from .models import Snapshot

# Fixed English labels: `strftime("%b")` follows the system locale.
MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")  # fmt: skip


def _today() -> date:
    """Local calendar day; the heatmap and the tiles both read it."""
    return datetime.now().astimezone().date()


# Emoji, variation selectors and the zero-width joiner. A bio can carry them
# and the font does not, so the system falls back to a colour emoji font and
# paints them in colour, in a window whose palette is greys only. They are dropped rather than recoloured: there is no greyscale
# version of them to draw.
_PICTOGRAPHS = re.compile("[\u2600-\u27bf\ufe00-\ufe0f\u200d\U0001f000-\U0001faff]")


def _one_line(text: str) -> str:
    """A bio as the header draws it: one line, no emoji.

    The API returns the field with the author's own line breaks in it, and
    the header has one elided line to put it on.
    """
    return " ".join(_PICTOGRAPHS.sub("", text).split())


def _short_date(day: date | None) -> str:
    """`Sep 19`, the form the Busiest day tile puts under its number."""
    return f"{MONTHS[day.month - 1]} {day.day}" if day else ""


def _cells(snapshot: Snapshot) -> list[list[dict[str, Any]]]:
    """Weeks as columns of cells, each carrying its weekday row.

    The first and last weeks of a year are partial, so a cell states the row
    it belongs to instead of letting the grid count from the top.
    """
    busiest = stats.busiest_day(snapshot.days)
    columns: list[list[dict[str, Any]]] = []
    for week in snapshot.weeks:
        columns.append(
            [
                {
                    "row": (day.day.weekday() + 1) % 7,  # Sunday first
                    "level": stats.level(day.count, busiest),
                    "count": day.count,
                    "date": day.day.isoformat(),
                    "label": github.day_label(day.day, day.count),
                }
                for day in week
            ]
        )
    return columns


def _months(snapshot: Snapshot) -> list[dict[str, Any]]:
    """One label per month, at the column where that month first appears."""
    labels: list[dict[str, Any]] = []
    seen: set[int] = set()
    for index, week in enumerate(snapshot.weeks):
        for day in week:
            if day.day.month not in seen:
                seen.add(day.day.month)
                labels.append({"column": index, "text": MONTHS[day.day.month - 1]})
            break
    return labels


def _rows(snapshot: Snapshot) -> list[dict[str, str]]:
    return [
        {
            "headline": commit.headline,
            "sha": commit.short_oid,
            "repo": commit.repository,
            "when": github.relative_time(commit.committed_at),
            "url": commit.url,
        }
        for commit in snapshot.commits
    ]


def _avatar_url(login: str, url: str, viewer: str, cached: str) -> str:
    """What `Image.source` gets for one author.

    The viewer's own face is already on disk, downloaded for the header, and
    it is the only face on every commit of an owned repository: serving it
    from the cache keeps the panel drawn when the network is gone.
    """
    if login and login == viewer and cached:
        return "file://" + cached
    return url


def _detail_commits(snapshot: Snapshot, repo: Any, cached: str) -> list[dict[str, str]]:
    """The panel's commit rows: every author, unlike Recent Activity."""
    viewer = snapshot.profile.login
    return [
        {
            "headline": commit.headline,
            "sha": commit.short_oid,
            "when": github.relative_time(commit.committed_at),
            "avatar": _avatar_url(
                commit.author_login, commit.author_avatar_url, viewer, cached
            ),
        }
        for commit in repo.commits
    ]


def _repos(snapshot: Snapshot, cached_avatar: str = "") -> list[dict[str, Any]]:
    """The repository rows, already carrying the strings the list draws.

    The fields after `private` are the detail panel's. They ride along on the
    same query, so the panel has everything but its contributors the moment a
    row is marked.
    """
    rows: list[dict[str, Any]] = []
    for repo in snapshot.repositories:
        when = github.relative_time(repo.pushed_at)
        rows.append(
            {
                "name": repo.name,
                "description": repo.description,
                "language": repo.language,
                "stars": repo.stars,
                "forks": repo.forks,
                "updated": f"Updated {when}" if when else "",
                "url": repo.url,
                "private": repo.private,
                "owner": repo.owner,
                "commitCount": repo.commit_count,
                "pullRequests": repo.pull_requests,
                # `github.com/owner/name`: the scheme is noise on a line that
                # is plainly a URL.
                "shortUrl": repo.url.split("//", 1)[-1],
                "languages": [
                    {"name": share.name, "percent": share.percent}
                    for share in stats.language_shares(list(repo.languages))
                ],
                "commits": _detail_commits(snapshot, repo, cached_avatar),
            }
        )
    return rows


def _languages(snapshot: Snapshot) -> list[dict[str, Any]]:
    """The Overview's Languages card: the whole account in one bar.

    It rides on the repository list both screens already share, so it costs
    no request, and it is `language_shares` at its own default - the same top
    three and `Other` the detail panel's bar draws, only summed over every
    repository instead of one.
    """
    shares = stats.language_shares(stats.account_languages(snapshot.repositories))
    return [{"name": share.name, "percent": share.percent} for share in shares]


def _pinned(snapshot: Snapshot) -> list[dict[str, str]]:
    """The sidebar's pinned rows: a name to draw and a URL to open.

    Nothing else travels with them. A pinned repository can be another
    account's, so there is no row in the Repositories list to jump to and the
    only thing the row can do is hand its URL to the browser.
    """
    return [{"name": repo.name, "url": repo.url} for repo in snapshot.pinned]


class Backend(QObject):
    """Properties and signals for `Main.qml`."""

    changed = Signal()
    statusChanged = Signal()
    contributorsChanged = Signal()
    _arrived = Signal(object, int)
    _failed = Signal(str, int)
    _contributors = Signal(str, object)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._year = _today().year
        self._snapshot: Snapshot | None = None
        self._avatar = ""
        self._error = ""
        self._stale = False
        self._loading = False
        # `owner/name` -> {state, error, rows}. One request per repository the
        # panel is asked about, kept for the session: the REST endpoint is the
        # app's only per-repository call and walking back up the list must not
        # pay for it twice.
        self._contributor_cache: dict[str, dict[str, Any]] = {}
        self._arrived.connect(self._apply)
        self._failed.connect(self._fail)
        self._contributors.connect(self._contributors_done)

    # -- data in -----------------------------------------------------------

    def start(self) -> None:
        """Paint the cache, then revalidate in the background."""
        cached = cache.load(self._year)
        if cached:
            self._apply(cached, self._year, cached=True)
        self.refresh()

    @Slot()
    def refresh(self) -> None:
        if self._loading:
            return
        self._loading = True
        self.statusChanged.emit()
        year = self._year
        threading.Thread(target=self._work, args=(year,), daemon=True).start()

    def _work(self, year: int) -> None:
        try:
            viewer = github.fetch(year)
        except github.GitHubError as exc:
            self._failed.emit(str(exc), year)
            return
        cache.store(viewer, year)
        self._arrived.emit(viewer, year)

    def _apply(self, viewer: dict[str, Any], year: int, cached: bool = False) -> None:
        """Put a snapshot on screen, from the cache or from the network.

        Cached data is drawn at full strength: it is dimmed only once a
        refresh has actually failed, so the window does not open dark and
        brighten a second later.
        """
        if year != self._year:
            return
        self._snapshot = github.parse(viewer, year)
        self._avatar = cache.avatar(
            self._snapshot.profile.avatar_url, self._snapshot.profile.login
        )
        if not cached:
            self._error = ""
            self._stale = False
            self._loading = False
        self.changed.emit()
        self.statusChanged.emit()

    def _fail(self, message: str, year: int) -> None:
        if year != self._year:
            return
        self._loading = False
        self._error = message
        self._stale = self._snapshot is not None
        self.statusChanged.emit()

    # -- contributors ------------------------------------------------------
    # The one block that does not ride along on the year's query: GraphQL has
    # no contributor list, so this is a REST call of its own, fired only for
    # the repository the panel is actually showing.

    @Slot(str, str)
    def requestContributors(self, owner: str, name: str) -> None:
        """Fetch one repository's contributors, once."""
        if not owner or not name:
            return
        key = f"{owner}/{name}"
        if key in self._contributor_cache:
            return
        self._contributor_cache[key] = {"state": "loading", "error": "", "rows": []}
        self.contributorsChanged.emit()
        threading.Thread(
            target=self._contributor_work, args=(owner, name), daemon=True
        ).start()

    def _contributor_work(self, owner: str, name: str) -> None:
        key = f"{owner}/{name}"
        try:
            people = github.fetch_contributors(owner, name)
        except github.GitHubError as exc:
            self._contributors.emit(key, str(exc))
            return
        self._contributors.emit(key, people)

    def _contributors_done(self, key: str, result: Any) -> None:
        if isinstance(result, str):
            self._contributor_cache[key] = {
                "state": "failed",
                "error": result,
                "rows": [],
            }
        else:
            viewer = self._snapshot.profile.login if self._snapshot else ""
            self._contributor_cache[key] = {
                "state": "ready",
                "error": "",
                "rows": [
                    {
                        "login": person.login,
                        "contributions": person.contributions,
                        "avatar": _avatar_url(
                            person.login, person.avatar_url, viewer, self._avatar
                        ),
                    }
                    for person in result
                ],
            }
        self.contributorsChanged.emit()

    contributors = Property(
        "QVariantMap",
        lambda self: self._contributor_cache,
        notify=contributorsChanged,
    )

    # -- year navigation ---------------------------------------------------

    def _get_year(self) -> int:
        return self._year

    def _set_year(self, year: int) -> None:
        if year == self._year:
            return
        self._year = year
        self._snapshot = None
        self._error = ""
        self._stale = False
        self._loading = False
        self.changed.emit()
        cached = cache.load(year)
        if cached:
            self._apply(cached, year, cached=True)
        self.refresh()

    year = Property(int, _get_year, _set_year, notify=changed)

    @Slot(int)
    def step_year(self, delta: int) -> None:
        self._set_year(self._year + delta)

    @Slot(str)
    def openUrl(self, url: str) -> None:
        """Hand a URL to the browser, detached from this process.

        `Qt.openUrlExternally` is not usable here: the window closes right
        after the call, and on this desktop Qt's open is asynchronous, so
        quitting cancels it and the page never arrives. `xdg-open` in its own
        session outlives the app - and it still reuses the running browser
        instead of starting a second one.
        """
        if not url:
            return
        opener = shutil.which("xdg-open")
        if not opener:
            return
        subprocess.Popen(
            [opener, url],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    # -- profile -----------------------------------------------------------

    def _profile_str(self, field: str) -> str:
        return getattr(self._snapshot.profile, field) if self._snapshot else ""

    def _profile_int(self, field: str) -> int:
        return getattr(self._snapshot.profile, field) if self._snapshot else 0

    def _profile_url(self) -> str:
        login = self._profile_str("login")
        return f"https://github.com/{login}" if login else ""

    name = Property(str, lambda self: self._profile_str("name"), notify=changed)
    login = Property(str, lambda self: self._profile_str("login"), notify=changed)
    bio = Property(
        str, lambda self: _one_line(self._profile_str("bio")), notify=changed
    )
    location = Property(str, lambda self: self._profile_str("location"), notify=changed)
    avatar = Property(str, lambda self: self._avatar, notify=changed)
    # The avatar links to the profile. The URL is the login, so nothing extra
    # is fetched; it stays empty until a snapshot is on screen.
    profileUrl = Property(str, lambda self: self._profile_url(), notify=changed)
    repositories = Property(
        int, lambda self: self._profile_int("repositories"), notify=changed
    )
    following = Property(
        int, lambda self: self._profile_int("following"), notify=changed
    )
    followers = Property(
        int, lambda self: self._profile_int("followers"), notify=changed
    )
    contributions = Property(
        int, lambda self: self._profile_int("contributions"), notify=changed
    )

    # -- heatmap, tiles, activity -----------------------------------------

    weeks = Property(
        "QVariantList",
        lambda self: _cells(self._snapshot) if self._snapshot else [],
        notify=changed,
    )
    months = Property(
        "QVariantList",
        lambda self: _months(self._snapshot) if self._snapshot else [],
        notify=changed,
    )
    commits = Property(
        "QVariantList",
        lambda self: _rows(self._snapshot) if self._snapshot else [],
        notify=changed,
    )
    repos = Property(
        "QVariantList",
        lambda self: _repos(self._snapshot, self._avatar) if self._snapshot else [],
        notify=changed,
    )
    pinned = Property(
        "QVariantList",
        lambda self: _pinned(self._snapshot) if self._snapshot else [],
        notify=changed,
    )
    languages = Property(
        "QVariantList",
        lambda self: _languages(self._snapshot) if self._snapshot else [],
        notify=changed,
    )

    # The sidebar's third line: the account's own, where a fixed tagline would
    # be the author's phrase under every other user's name.
    language = Property(
        str,
        lambda self: stats.dominant_language(
            self._snapshot.repositories if self._snapshot else []
        ),
        notify=changed,
    )

    def _streaks(self) -> stats.Streaks:
        days = self._snapshot.days if self._snapshot else []
        return stats.compute(days, _today())

    # The four the tiles draw.
    currentStreak = Property(int, lambda self: self._streaks().current, notify=changed)
    busiestDay = Property(int, lambda self: self._streaks().busiest, notify=changed)
    activeDays = Property(int, lambda self: self._streaks().active_days, notify=changed)
    perWeek = Property(int, lambda self: self._streaks().per_week, notify=changed)

    # The date under `Busiest day`: the number alone does not say which day it
    # was, and the tile has a label line to put it on. Empty on a year with no
    # contributions at all, where there is no day to name.
    busiestOn = Property(
        str, lambda self: _short_date(self._streaks().busiest_on), notify=changed
    )

    # Read by the heatmap's footer, and by nothing else since `This year` left
    # the tiles - the footer is one card away and already writes the number.
    yearTotal = Property(int, lambda self: self._streaks().year_total, notify=changed)
    # Neither is drawn today. Both are a binding away from taking a tile back,
    # and they are computed in the same pass either way.
    today = Property(int, lambda self: self._streaks().today, notify=changed)
    bestStreak = Property(int, lambda self: self._streaks().best, notify=changed)

    # -- status ------------------------------------------------------------

    # The heatmap puts its cursor on today when the selected year holds it.
    todayIso = Property(str, lambda self: _today().isoformat(), notify=changed)

    hasData = Property(bool, lambda self: self._snapshot is not None, notify=changed)
    error = Property(str, lambda self: self._error, notify=statusChanged)
    stale = Property(bool, lambda self: self._stale, notify=statusChanged)
    loading = Property(bool, lambda self: self._loading, notify=statusChanged)
