"""Plain data carried between the GitHub client, the stats and QML."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date


@dataclass(frozen=True, slots=True)
class Profile:
    """The viewer's identity and the four header counters."""

    login: str
    name: str
    avatar_url: str
    bio: str
    location: str
    repositories: int
    following: int
    followers: int
    contributions: int


@dataclass(frozen=True, slots=True)
class ContributionDay:
    """One cell of the heatmap."""

    day: date
    count: int


@dataclass(frozen=True, slots=True)
class Streaks:
    """Streaks and totals, all scoped to the selected year.

    The four the tiles draw are `current`, `busiest`, `active_days` and
    `per_week`. `today`, `best` and `year_total` outlive them: the heatmap's
    footer reads the total, and the other two are one binding away from
    taking a tile back, which is why they are still computed in the same pass.
    """

    today: int
    current: int
    best: int
    year_total: int
    active_days: int = 0
    busiest: int = 0
    busiest_on: date | None = None
    per_week: int = 0


@dataclass(frozen=True, slots=True)
class CommitEntry:
    """One commit row, on Recent Activity and in the detail panel.

    The author travels with it because the panel draws every author's commits,
    not only the viewer's: on a repository the viewer does not own that is the
    whole point of the block.
    """

    oid: str
    headline: str
    repository: str
    committed_at: str
    author_login: str = ""
    author_avatar_url: str = ""

    @property
    def short_oid(self) -> str:
        return self.oid[:7]


@dataclass(frozen=True, slots=True)
class Language:
    """One language of a repository, as the API weighs it: bytes of code."""

    name: str
    size: int


@dataclass(frozen=True, slots=True)
class LanguageShare:
    """One slice of the language bar. Shares always sum to 100."""

    name: str
    percent: int


@dataclass(frozen=True, slots=True)
class Contributor:
    """One row of Top contributors, the only thing the REST API is used for."""

    login: str
    contributions: int
    avatar_url: str


@dataclass(frozen=True, slots=True)
class PinnedRepo:
    """One row of the sidebar's pinned block.

    It is deliberately not a `Repository`: a pinned item can belong to someone
    else, so this list is not a subset of the owned repositories the two
    screens are built from, and the row draws nothing else about it.
    """

    name: str
    url: str


@dataclass(frozen=True, slots=True)
class Repository:
    """One row of the Repositories list, and the detail panel beside it.

    The fields after `private` are the panel's alone. They cost no request of
    their own: the list query already walks every repository, so it carries
    them along.
    """

    name: str
    description: str
    language: str
    stars: int
    forks: int
    pushed_at: str
    url: str
    private: bool
    owner: str = ""
    commit_count: int = 0
    pull_requests: int = 0
    languages: tuple[Language, ...] = ()
    commits: tuple[CommitEntry, ...] = ()


@dataclass(frozen=True, slots=True)
class Snapshot:
    """Everything one year's query yields, cached as a unit."""

    year: int
    profile: Profile
    weeks: list[list[ContributionDay]] = field(default_factory=list)
    commits: list[CommitEntry] = field(default_factory=list)
    repositories: list[Repository] = field(default_factory=list)
    pinned: list[PinnedRepo] = field(default_factory=list)

    @property
    def days(self) -> list[ContributionDay]:
        return [day for week in self.weeks for day in week]
