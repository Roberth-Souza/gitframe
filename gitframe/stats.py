"""Streaks and totals computed from a year of contribution days.

Pure functions: no Qt, no network. Everything is scoped to the days handed in,
which is always a single year, so streaks crossing 31 Dec are not tracked.
"""

from __future__ import annotations

from datetime import date

from .models import ContributionDay, Language, LanguageShare, Repository, Streaks


def today_count(days: list[ContributionDay], reference: date) -> int:
    """Contributions on `reference`, or 0 when it falls outside the year."""
    for day in days:
        if day.day == reference:
            return day.count
    return 0


def year_total(days: list[ContributionDay]) -> int:
    return sum(day.count for day in days)


def best_streak(days: list[ContributionDay]) -> int:
    """Longest run of consecutive days with at least one contribution."""
    best = 0
    run = 0
    for day in sorted(days, key=lambda d: d.day):
        if day.count > 0:
            run += 1
            best = max(best, run)
        else:
            run = 0
    return best


def current_streak(days: list[ContributionDay], reference: date) -> int:
    """Run of active days ending at `reference`.

    An empty `reference` does not break the streak: the day is still in
    progress, so the walk starts from the day before it. Days after
    `reference` are ignored, which matters for a year already in the past
    (there the anchor is the last day of the year).
    """
    counts = {day.day: day.count for day in days}
    if not counts:
        return 0

    anchor = reference if reference in counts else max(counts)

    index = sorted(counts)
    position = index.index(anchor)
    if counts[anchor] == 0:
        position -= 1

    streak = 0
    while position >= 0 and counts[index[position]] > 0:
        streak += 1
        position -= 1
    return streak


def active_days(days: list[ContributionDay]) -> int:
    """Days of the year with at least one contribution."""
    return sum(1 for day in days if day.count > 0)


def busiest_on(days: list[ContributionDay]) -> date | None:
    """The day the busiest count landed on, the earliest one on a tie.

    None when the year has nothing in it, which is what keeps the tile from
    naming a date the account never touched.
    """
    peak: ContributionDay | None = None
    for day in sorted(days, key=lambda entry: entry.day):
        if day.count > 0 and (peak is None or day.count > peak.count):
            peak = day
    return peak.day if peak else None


def per_week(days: list[ContributionDay], reference: date) -> int:
    """Contributions per week over the part of the year that has happened.

    The calendar always comes back whole - 365 days, most of them still in
    the future in January - so dividing by 52 would read every current year
    as finished. The divisor is the days up to `reference` instead, and a
    year already past simply ends at its own last day.
    """
    if not days:
        return 0
    ordered = sorted(days, key=lambda entry: entry.day)
    first = ordered[0].day
    last = min(ordered[-1].day, reference)
    if last < first:
        return 0
    elapsed = (last - first).days + 1
    return round(year_total(days) * 7 / elapsed)


def compute(days: list[ContributionDay], reference: date) -> Streaks:
    """Everything the tiles and the heatmap's footer read, in one pass."""
    return Streaks(
        today=today_count(days, reference),
        current=current_streak(days, reference),
        best=best_streak(days),
        year_total=year_total(days),
        active_days=active_days(days),
        busiest=busiest_day(days),
        busiest_on=busiest_on(days),
        per_week=per_week(days, reference),
    )


LEVELS = 4


def level(count: int, busiest: int) -> int:
    """Heatmap shade, 0 (empty) to 4 (densest), scaled to the busiest day.

    GitHub scales the shades to the year on screen rather than to a fixed
    number of contributions, so a quiet year still uses the whole ramp.
    """
    if count <= 0 or busiest <= 0:
        return 0
    step = max(busiest / LEVELS, 1.0)
    return min(LEVELS, int((count - 1) // step) + 1)


def busiest_day(days: list[ContributionDay]) -> int:
    return max((day.count for day in days), default=0)


# The language bar names this many languages and sums the rest into `Other`.
BAR_SLICES = 3
OTHER = "Other"
# A slice below this reads `0%` and draws thinner than a pixel, which is a
# slice that says nothing twice over. It is dropped instead.
MIN_SHARE = 0.5


def language_shares(
    languages: list[Language], slices: int = BAR_SLICES
) -> list[LanguageShare]:
    """The language bar: the largest `slices` languages, then `Other`.

    Percentages are whole numbers that sum to exactly 100, by largest
    remainder, so the bar always fills its width. Dropping a slice under
    `MIN_SHARE` shifts the rest by less than half a percent, which is below
    what a whole number can show.
    """
    ordered = sorted(
        (language for language in languages if language.size > 0),
        key=lambda language: language.size,
        reverse=True,
    )
    total = sum(language.size for language in ordered)
    if not ordered or total <= 0:
        return []

    buckets = list(ordered[:slices])
    tail = sum(language.size for language in ordered[slices:])
    if tail > 0:
        buckets.append(Language(name=OTHER, size=tail))

    kept = [b for b in buckets if b.size * 100 / total >= MIN_SHARE] or buckets[:1]
    kept_total = sum(bucket.size for bucket in kept)
    exact = [bucket.size * 100 / kept_total for bucket in kept]
    percents = [int(value) for value in exact]
    # Largest remainder: hand the points rounding lost to the closest calls.
    short = 100 - sum(percents)
    by_remainder = sorted(
        range(len(kept)), key=lambda i: exact[i] - percents[i], reverse=True
    )
    for index in by_remainder[:short]:
        percents[index] += 1
    return [
        LanguageShare(name=kept[i].name, percent=percents[i]) for i in range(len(kept))
    ]


def account_languages(repositories: list[Repository]) -> list[Language]:
    """Every language of every repository, summed by bytes and ordered.

    Weighed by size, the same measure as the detail panel's bar, not by how
    many repositories name it primary. Ties go to the name, so neither the
    sidebar's line nor the card's order flips between refreshes.
    """
    totals: dict[str, int] = {}
    for repo in repositories:
        for language in repo.languages:
            totals[language.name] = totals.get(language.name, 0) + language.size
    return sorted(
        (Language(name=name, size=size) for name, size in totals.items()),
        key=lambda language: (-language.size, language.name),
    )


def dominant_language(repositories: list[Repository]) -> str:
    """The sidebar's language line. Empty when no repository has any code."""
    ordered = account_languages(repositories)
    return ordered[0].name if ordered else ""
