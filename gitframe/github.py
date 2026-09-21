"""GraphQL client: one query per year, run through `gh api graphql`.

`gh` owns authentication, so there is no token handling here. A failure is
raised as `GitHubError` and the backend turns it into a dim line on screen.
"""

from __future__ import annotations

import json
import subprocess
from datetime import date, datetime
from typing import Any

from .models import (
    CommitEntry,
    ContributionDay,
    Contributor,
    Language,
    PinnedRepo,
    Profile,
    Repository,
    Snapshot,
)

# Spelled out for `day_label`: the window is English regardless of the locale.
MONTH_NAMES = ("January", "February", "March", "April", "May", "June",
               "July", "August", "September", "October", "November",
               "December")  # fmt: skip

QUERY = """
query($from: DateTime!, $to: DateTime!, $repos: Int!, $commits: Int!,
      $languages: Int!, $pinned: Int!) {
  viewer {
    login
    name
    avatarUrl
    bio
    location
    followers { totalCount }
    following { totalCount }
    repoCount: repositories(ownerAffiliations: OWNER) { totalCount }
    pinnedItems(first: $pinned, types: REPOSITORY) {
      nodes { ... on Repository { name url } }
    }
    contributionsCollection(from: $from, to: $to) {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount } }
      }
    }
    recent: repositories(first: $repos,
                         orderBy: {field: PUSHED_AT, direction: DESC},
                         ownerAffiliations: OWNER) {
      nodes {
        name
        nameWithOwner
        description
        isPrivate
        stargazerCount
        forkCount
        pushedAt
        url
        primaryLanguage { name }
        pullRequests { totalCount }
        languages(first: $languages, orderBy: {field: SIZE, direction: DESC}) {
          edges { size node { name } }
        }
        defaultBranchRef {
          target {
            ... on Commit {
              history(first: $commits) {
                totalCount
                nodes {
                  oid
                  messageHeadline
                  committedDate
                  author { user { login avatarUrl } }
                }
              }
            }
          }
        }
      }
    }
  }
}
"""

# The one repository list the query returns: it feeds the Repositories screen
# whole and Recent Activity through a filter. The limit is well past the
# account's size so the screen never shows a truncated list, and both it and
# `COMMIT_LIMIT` over-fetch on purpose - merge commits and other people's
# commits are dropped client-side.
#
# 100 is GraphQL's own ceiling for `first`, not a number chosen for this
# account, which has 11. It is the largest list the screen can hold without
# paginating, and asking for it is free: `first` is a ceiling, so an account
# below it returns exactly the same payload. Measured against the live API,
# 30 vs 100: 78 KB both, 2.06s vs 2.04s median of 4, and the cost goes 1 -> 2
# points of the 5000 per hour. An account past 100 is truncated and would need
# `pageInfo.endCursor` and a request per extra 100; not built, not needed here.
REPO_LIMIT = 100
COMMIT_LIMIT = 20
# Recent Activity draws this many rows; see `activityRows` in qml/Config.qml.
# Eleven since the four tiles moved into the rail and stopped taking a row of
# their own out of the column.
ACTIVITY_ROWS = 11
# The detail panel's two capped blocks. Both are a ceiling, not a promise: the
# card holds their space whether or not the rows arrive to fill it.
DETAIL_COMMITS = 5
CONTRIBUTOR_LIMIT = 5
# Deeper than the bar draws: the tail is summed into `Other`, so it has to be
# fetched before it can be summed.
LANGUAGE_LIMIT = 10
# GitHub's own ceiling on a profile: the sidebar draws whatever comes back.
PINNED_LIMIT = 6
TIMEOUT = 20


class GitHubError(RuntimeError):
    """`gh` is missing, unauthenticated, offline, or answered with errors."""


def _run(args: list[str]) -> str:
    try:
        result = subprocess.run(
            args, capture_output=True, text=True, timeout=TIMEOUT, check=False
        )
    except FileNotFoundError as exc:
        raise GitHubError("gh not found") from exc
    except subprocess.TimeoutExpired as exc:
        raise GitHubError("github timed out") from exc
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip().splitlines()
        raise GitHubError(message[-1] if message else "gh failed")
    return result.stdout


def fetch(year: int) -> dict[str, Any]:
    """Run the year's query and return the raw `data.viewer` payload."""
    args = [
        "gh", "api", "graphql",
        "-f", f"query={QUERY}",
        "-f", f"from={year}-01-01T00:00:00Z",
        "-f", f"to={year}-12-31T23:59:59Z",
        "-F", f"repos={REPO_LIMIT}",
        "-F", f"commits={COMMIT_LIMIT}",
        "-F", f"languages={LANGUAGE_LIMIT}",
        "-F", f"pinned={PINNED_LIMIT}",
    ]  # fmt: skip
    raw = _run(args)
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise GitHubError("unreadable response") from exc
    if payload.get("errors"):
        raise GitHubError(str(payload["errors"][0].get("message", "query failed")))
    viewer = payload.get("data", {}).get("viewer")
    if not viewer:
        raise GitHubError("empty response")
    return viewer


def parse_profile(viewer: dict[str, Any]) -> Profile:
    calendar = viewer["contributionsCollection"]["contributionCalendar"]
    return Profile(
        login=viewer["login"],
        name=viewer.get("name") or viewer["login"],
        avatar_url=viewer.get("avatarUrl") or "",
        bio=viewer.get("bio") or "",
        location=viewer.get("location") or "",
        repositories=viewer["repoCount"]["totalCount"],
        following=viewer["following"]["totalCount"],
        followers=viewer["followers"]["totalCount"],
        contributions=calendar["totalContributions"],
    )


def parse_weeks(viewer: dict[str, Any]) -> list[list[ContributionDay]]:
    """Weeks as they come back, short first and last week included."""
    calendar = viewer["contributionsCollection"]["contributionCalendar"]
    weeks: list[list[ContributionDay]] = []
    for week in calendar["weeks"]:
        days = [
            ContributionDay(
                day=date.fromisoformat(entry["date"]),
                count=entry["contributionCount"],
            )
            for entry in week["contributionDays"]
        ]
        if days:
            weeks.append(days)
    return weeks


def _history(repo: dict[str, Any]) -> dict[str, Any]:
    """The default branch's history, or an empty dict.

    An empty repository has no default branch at all, so every step of the
    walk down to `history` can be null.
    """
    branch = repo.get("defaultBranchRef") or {}
    target = branch.get("target") or {}
    return target.get("history") or {}


def _repo_commits(repo: dict[str, Any]) -> list[CommitEntry]:
    """Every commit the history carried, in the order the API returned it."""
    entries: list[CommitEntry] = []
    for commit in _history(repo).get("nodes") or []:
        author = (commit.get("author") or {}).get("user") or {}
        entries.append(
            CommitEntry(
                oid=commit["oid"],
                headline=commit["messageHeadline"],
                repository=repo.get("name", ""),
                committed_at=commit["committedDate"],
                author_login=author.get("login") or "",
                author_avatar_url=author.get("avatarUrl") or "",
            )
        )
    return entries


def parse_commits(
    viewer: dict[str, Any], login: str, limit: int = ACTIVITY_ROWS
) -> list[CommitEntry]:
    """The viewer's own commits across the recently pushed repositories.

    `history` returns every author on the default branch, so the filter on
    `author_login` is what keeps other people's commits out. The detail panel
    keeps them instead, which is why the filter lives here and not in
    `_repo_commits`.
    """
    entries: list[CommitEntry] = []
    for repo in viewer["recent"]["nodes"]:
        entries.extend(
            entry for entry in _repo_commits(repo) if entry.author_login == login
        )
    entries.sort(key=lambda entry: entry.committed_at, reverse=True)
    return entries[:limit]


def parse_languages(repo: dict[str, Any]) -> tuple[Language, ...]:
    """The language breakdown, largest first, zero-sized entries dropped."""
    edges = (repo.get("languages") or {}).get("edges") or []
    languages = [
        Language(
            name=(edge.get("node") or {}).get("name") or "", size=edge.get("size") or 0
        )
        for edge in edges
    ]
    return tuple(
        sorted(
            (language for language in languages if language.name and language.size > 0),
            key=lambda language: language.size,
            reverse=True,
        )
    )


def parse_pinned(viewer: dict[str, Any], limit: int = PINNED_LIMIT) -> list[PinnedRepo]:
    """The pinned repositories, in the order the profile pins them.

    Read with defaults like everything else: a cache written before
    `pinnedItems` was queried draws no block rather than failing. A pinned
    item can be another account's repository, so this is not a subset of
    `parse_repositories` and a row cannot be resolved against that list.
    """
    nodes = (viewer.get("pinnedItems") or {}).get("nodes") or []
    pinned = [
        PinnedRepo(name=node.get("name") or "", url=node.get("url") or "")
        for node in nodes
        if node
    ]
    return [repo for repo in pinned if repo.name and repo.url][:limit]


def parse_repositories(viewer: dict[str, Any]) -> list[Repository]:
    """The owned repositories, newest push first, as the API ordered them.

    Every field is read with a default: a cache written before these fields
    were queried has to draw a row without them rather than fail.
    """
    repositories: list[Repository] = []
    for repo in viewer.get("recent", {}).get("nodes") or []:
        language = repo.get("primaryLanguage") or {}
        full_name = repo.get("nameWithOwner") or ""
        repositories.append(
            Repository(
                name=repo.get("name", ""),
                description=" ".join((repo.get("description") or "").split()),
                language=language.get("name") or "",
                stars=repo.get("stargazerCount") or 0,
                forks=repo.get("forkCount") or 0,
                pushed_at=repo.get("pushedAt") or "",
                url=repo.get("url") or "",
                private=bool(repo.get("isPrivate")),
                owner=full_name.partition("/")[0],
                commit_count=_history(repo).get("totalCount") or 0,
                pull_requests=(repo.get("pullRequests") or {}).get("totalCount") or 0,
                languages=parse_languages(repo),
                commits=tuple(_repo_commits(repo)[:DETAIL_COMMITS]),
            )
        )
    return repositories


def fetch_contributors(
    owner: str, name: str, limit: int = CONTRIBUTOR_LIMIT
) -> list[Contributor]:
    """Top contributors of one repository, through the REST API.

    The GraphQL schema has no contributor list, so this is the app's second
    transport and its only per-repository request. It is why the detail panel
    draws this block last and dim until it arrives.
    """
    if not owner or not name:
        return []
    raw = _run(
        ["gh", "api", f"/repos/{owner}/{name}/contributors?per_page={limit}"]
    ).strip()
    # An empty repository answers 204 with no body at all.
    if not raw:
        return []
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise GitHubError("unreadable response") from exc
    return parse_contributors(payload, limit)


def parse_contributors(
    payload: Any, limit: int = CONTRIBUTOR_LIMIT
) -> list[Contributor]:
    """The REST list, which already arrives ordered by contribution count."""
    if not isinstance(payload, list):
        raise GitHubError("unexpected response")
    return [
        Contributor(
            login=entry.get("login") or "",
            contributions=entry.get("contributions") or 0,
            avatar_url=entry.get("avatar_url") or "",
        )
        for entry in payload[:limit]
    ]


def parse(viewer: dict[str, Any], year: int) -> Snapshot:
    profile = parse_profile(viewer)
    return Snapshot(
        year=year,
        profile=profile,
        weeks=parse_weeks(viewer),
        commits=parse_commits(viewer, profile.login),
        repositories=parse_repositories(viewer),
        pinned=parse_pinned(viewer),
    )


def load(year: int) -> Snapshot:
    return parse(fetch(year), year)


def relative_time(iso: str, reference: datetime | None = None) -> str:
    """`committedDate` as the short `3h ago` form the rows show."""
    try:
        moment = datetime.fromisoformat(iso)
    except ValueError:
        return ""
    now = reference or datetime.now(tz=moment.tzinfo)
    seconds = int((now - moment).total_seconds())
    if seconds < 60:
        return "just now"
    if seconds < 3600:
        return f"{seconds // 60}m ago"
    if seconds < 86400:
        return f"{seconds // 3600}h ago"
    if seconds < 2592000:
        return f"{seconds // 86400}d ago"
    return f"{seconds // 2592000}mo ago"


def day_label(day: date, count: int) -> str:
    """The hover line over a heatmap cell: `18 contributions on September 19th.`

    The month names are spelled out here rather than through `strftime`, which
    follows the system locale; the window is English throughout.
    """
    if count == 0:
        amount = "No contributions"
    elif count == 1:
        amount = "1 contribution"
    else:
        amount = f"{count} contributions"
    return f"{amount} on {MONTH_NAMES[day.month - 1]} {day.day}{_ordinal(day.day)}."


def _ordinal(number: int) -> str:
    """English ordinal suffix: 1st, 2nd, 3rd, 4th, and 11th/12th/13th."""
    if 11 <= number % 100 <= 13:
        return "th"
    return {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")
