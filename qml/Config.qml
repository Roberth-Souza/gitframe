pragma Singleton

import QtQuick

// Palette, font and geometry: the sizes this window is built out of. Never
// hardcode a color or a size in a component; add a token here instead.
QtObject {
    // -- palette: greys only, no accent anywhere ---------------------------
    readonly property color bg: "#e6000000"
    readonly property color cardBg: "#00000000"
    readonly property color fg: "#aaaaaa"
    readonly property color fgActive: "#ffffff"
    readonly property color fgDim: "#5d5d5d"
    // The active sidebar tab's fill: a mid grey, not off white, so the one lit
    // block on screen does not out-shout `fgActive`, which is what actually
    // marks a value. Measured off the reference, not chosen.
    readonly property color activeFill: "#9d9d9d"
    // Drawn on top of `activeFill`: the active sidebar tab inverts, so its
    // label and glyph go black. Solid, unlike `bg`, which is 90% alpha.
    readonly property color fgInvert: "#000000"
    readonly property color border: "#3c3c3c"
    readonly property color hover: "#191919"
    // Fully transparent: an unfilled shape, or a border that is not there yet.
    readonly property color clear: "#00000000"
    // Cached data waiting on a refresh is drawn at this opacity.
    readonly property real staleOpacity: 0.6

    // Hover/keyboard tooltip: the rofi window's fill, a near-black at 95%.
    readonly property color tooltipBg: "#f2050505"

    // Heatmap ramp: the empty cell, then four shades up to the densest day.
    readonly property var levels: ["#141414", "#2c2c2c", "#4f4f4f", "#808080", "#bdbdbd"]

    // -- type --------------------------------------------------------------
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeLarge: 20
    // The sidebar name: bigger than @login, far short of the header's 20.
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeCounter: 18
    // The tile's number. It was 26 in a 110px box with three stacked lines;
    // in the rail the box is 252 x 91 and holds one line, so the number is
    // what fills it. 32 and not the 40 it was first drawn at: at 40 a
    // two-digit number crowded the label to the right of it.
    readonly property int fontSizeTile: 32
    readonly property int glyphSize: 14
    // The tile's mark, the one glyph in the app drawn beside a number that
    // size: 18 read as a footnote next to it.
    readonly property int glyphSizeTile: 22
    // The detail panel's repo mark, beside the 20px name. The 14px glyph the
    // list rows carry reads as a footnote next to a name that size.
    readonly property int glyphSizeName: 18

    // -- glyphs ------------------------------------------------------------
    readonly property string glyphApp: ""
    // The two tab marks are the octicon outlines, not fa's solid house and
    // folder: the solid pair read as two filled blobs beside the outlined
    // glyphs the rest of the app draws (oct-repo, oct-lock, oct-pin).
    readonly property string glyphOverview: ""
    readonly property string glyphRepos: ""
    readonly property string glyphFollowing: ""
    readonly property string glyphFollowers: ""
    readonly property string glyphContributions: ""
    readonly property string glyphActivity: ""
    readonly property string glyphCommits: ""
    readonly property string glyphActiveDays: ""
    readonly property string glyphStreak: ""
    readonly property string glyphBusiest: ""
    readonly property string glyphAverage: ""
    readonly property string glyphBio: ""
    readonly property string glyphLocation: ""
    // The Repositories rows: the book, the padlock that replaces it on a
    // private repository, and the two counters. The outlined star and lock
    // are the lighter of the pair at 14px; the solid ones read as blobs.
    readonly property string glyphRepo: ""
    readonly property string glyphLock: ""
    readonly property string glyphStar: ""
    readonly property string glyphFork: ""
    // The detail panel: the three counters, the URL line and the two block
    // headings. Forks and watchers are not among them - both are zero on
    // every repository on this account, and a counter that is always zero is
    // a dead counter. Commits and pull requests are not.
    readonly property string glyphCommit: ""
    readonly property string glyphPullRequest: ""
    readonly property string glyphContributors: ""
    readonly property string glyphLink: ""
    // The search band: the magnifier, and the chevron on the visibility
    // filter. The chevron does not open a menu - the control cycles in
    // place - it only says the box has other values.
    readonly property string glyphSearch: ""
    readonly property string glyphFilter: ""
    // The heading of the sidebar's pinned block, and the only pin drawn: one
    // per row, under a heading that already says `Pinned`, would restate the
    // heading on every line and say nothing the names do not.
    readonly property string glyphPinned: ""
    // The mark left of the sidebar's language line. oct-code: it says the
    // word beside it is a language, which is what lets the line drop `Mostly`.
    readonly property string glyphLanguage: ""

    // -- strings -----------------------------------------------------------
    // The sidebar's pinned block. No count beside it, unlike a tab: every row
    // it has is on screen, so a number would only restate the list.
    readonly property string pinnedTitle: "Pinned repositories"
    // The search field, empty. The three states of the filter beside it.
    readonly property string searchPlaceholder: "Search repositories…"
    readonly property var visibilities: ["All", "Public", "Private"]
    // The one word the query field reads as syntax rather than as text to
    // match: it orders the rows by star count and never narrows them.
    // Deleting it hands the list back to the API's own order, newest push
    // first. The Repositories screen opens with it in the field.
    readonly property string sortStarsToken: "@stars"
    readonly property string repoQueryDefault: sortStarsToken

    // -- geometry ----------------------------------------------------------
    // Everything below is an integer and the window size falls out of it, so
    // heatmap cells never land on half pixels.
    readonly property int pad: 16          // window edge
    readonly property int cardPad: 16      // inside a card
    readonly property int blockGap: 12     // between the stacked blocks
    readonly property int gap: 8           // inside a block

    // The cell used to set the window width; now it is the other way round.
    // The content column holds two columns - the heatmap card and the rail -
    // and the window does not change size, so the 1124 the column already had
    // is the fixed number and the cell is what falls out of it. 12 and 3 are
    // the pair that splits 1124 with both the 53 week columns and the rail's
    // 2x2 tiles landing on integers: 53 * 15 - 3 = 792, + 36 + 32 = 860 for
    // the card, and 1124 - 12 - 860 = 252 for the rail, which is 2 * 120 + 12.
    readonly property int cell: 12
    readonly property int cellGap: 3
    readonly property int weekColumns: 53
    readonly property int weekdayLabelWidth: 36
    readonly property int heatmapWidth: weekColumns * (cell + cellGap) - cellGap
    readonly property int heatmapHeight: 7 * (cell + cellGap) - cellGap
    readonly property int heatmapCardWidth: heatmapWidth + weekdayLabelWidth
                                            + 2 * cardPad
    readonly property int legendCell: 11

    // Around the focused year control, inside its outline.
    readonly property int focusPad: 6

    // The header avatar's cursor ring. It is grey and 3px, not the 1px white
    // the other regions are outlined with: drawn on the avatar's own edge a
    // white hairline disappears into the greyed photo under it. The 3px is
    // what makes it a ring rather than an edge, and `Avatar` pushes the extra
    // width outwards, onto the black card, where the grey reads.
    readonly property color focusRing: "#8a8a8a"
    readonly property int focusRingWidth: 3

    // Corners are square by default and round only where it was asked for:
    // the sidebar row's fill, and the search band's two controls.
    readonly property int radius: 4

    readonly property int tooltipPadX: 8
    readonly property int tooltipPadY: 4
    // Between the tooltip and the cell it points at.
    readonly property int tooltipGap: 6

    // The sidebar absorbs whatever the content column does not need, so the
    // heatmap card never carries dead space: 16 + 232 + 12 + 1124 + 16 = 1400.
    readonly property int sidebarWidth: 232
    readonly property int sidebarAvatarSize: 56
    // Every sidebar row is this tall, tab or pinned repository, and its
    // contents start this far in. A pinned row carries no glyph of its own,
    // so its name starts where the tab labels do rather than where their
    // glyphs do, and the two lists read as one column of text.
    readonly property int tabHeight: 26
    readonly property int sidebarRowPadX: 2 * gap
    readonly property int sidebarLabelX: sidebarRowPadX + glyphSize + gap
    readonly property int ruleGap: 14      // above and below a sidebar rule
    readonly property int avatarSize: 80
    readonly property int cardTitleHeight: 22
    readonly property int monthLabelHeight: 16
    readonly property int legendHeight: 16
    readonly property int counterWidth: 130
    readonly property int separatorHeight: 56
    readonly property int activityRowHeight: 26
    // Eleven rows, back from five. The rail is what paid for them: the four
    // tiles left the stack, so Recent Activity now runs the full height of
    // the second row instead of splitting it with them.
    readonly property int activityRows: 11

    // -- the rail ----------------------------------------------------------
    // The second column of the Overview: the four tiles stacked above the
    // Languages card, all of them the rail's full width.
    //
    // The tiles were a 2x2 while Languages listed every language and was as
    // tall as Recent Activity beside it. Cut to the top three, that card is
    // 168, which left 182 of hole under it - so the tiles took the height
    // back and went from a 2x2 to a column of four. The rail still ends
    // exactly where the left column does: 4 * 91 + 3 * 12 + 12 + 168 = 580.
    readonly property int tileWidth: railWidth
    readonly property int railHeight: heatmapCardHeight + blockGap + activityHeight
    readonly property int tileHeight: (railHeight - 4 * blockGap - languagesHeight) / 4
    // How far the tile glyph reaches into the card's left padding: at the
    // full 16 it sat too far from the border for a mark that leads the row.
    readonly property int tileGlyphOutset: 6

    // The Languages card: the top three languages of the account and `Other`,
    // one thin bar each. That is `language_shares` at its own default, the
    // same top 3 + `Other` the detail panel's bar draws - only summed over
    // every repository instead of one.
    //
    // It is one bar per row here and one stacked bar there, and the reason is
    // width. Nine rows in a 220 column left 95px of track, where this
    // account's 1% tail drew thinner than a pixel. Four rows leave 100 - and
    // at 100 the fill in pixels is the percentage itself, so no slice can
    // round away.
    readonly property int languageBarWidth: 100
    readonly property int languageBarHeight: 6
    // What is left of the 220 once the bar, the percentage and the two gaps
    // are paid for. Every bar starts at the same x, so the name column is
    // fixed and elides rather than pushing the bars around.
    readonly property int languageNameWidth: railWidth - 2 * cardPad - languageBarWidth
                                             - languagePercentWidth - 2 * gap
    readonly property int languageRowHeight: 26
    // Three named languages and `Other`; see `BAR_SLICES` in gitframe/stats.py.
    readonly property int languageRows: 4
    // Four characters at 11px, which is what `100%` measures: the column is
    // fixed so the numbers line up under each other.
    readonly property int languagePercentWidth: 27

    // The Repositories screen. The list takes the share of the content column
    // it has in the reference mock and the detail panel takes the rest.
    readonly property int repoDetailWidth: 480
    readonly property int repoListWidth: contentWidth - blockGap - repoDetailWidth
    // The card's body is 640 and the whole-rows scroll rule needs it to be a
    // multiple of the row, which 64 is and the mock's 72 is not.
    readonly property int repoRowHeight: 64
    // The search band costs exactly one row, which is the whole price of the
    // field: 40 + 2 * 12 = 64, so 64 + 9 * 64 = 640 is still the card's body
    // and the viewport stays a multiple of the row.
    readonly property int searchHeight: 40
    readonly property int searchBandHeight: searchHeight + 2 * blockGap
    readonly property int searchPadX: 12
    // Fixed, not content sized: the label runs All -> Public -> Private and a
    // box that resized under it would jump.
    readonly property int filterWidth: 96
    readonly property int repoRows: 9
    readonly property int repoListHeight: repoRows * repoRowHeight

    // The detail panel beside the list. Its card is the same 704 tall, so
    // everything inside it is a budget and the two row counts are the only
    // slack: 16 + 68 + 25 + 44 + 25 + 66 + 25 + 232 + 25 + 162 + 16 = 704.
    // `commitRowHeight` is 40 and not the mock's roomier row for exactly that
    // reason - at 44 the contributors lose their fifth row.
    readonly property int detailRuleGap: 12
    readonly property int detailRuleHeight: 2 * detailRuleGap + 1
    // Name 28, description 16, URL 16, and 4 between them. Fixed even when
    // the description is missing: unlike a list row, this block must not
    // reflow while the cursor walks the list beside it.
    //
    // The name line is 28 and the gaps 4 because the header total is not
    // free: it is the 68 the budget above gives it. The 20px name needs 28
    // to sit in, and the two gaps pay for it - which also pulls the
    // description and the URL up under the name, so the three read as one
    // title block rather than three stacked lines.
    readonly property int detailNameHeight: 28
    readonly property int detailLineHeight: 16
    readonly property int detailLineGap: 4
    readonly property int detailHeaderHeight: detailNameHeight + detailLineGap
                                              + detailLineHeight + detailLineGap
                                              + detailLineHeight
    readonly property int detailCounterHeight: 44
    readonly property int detailBarHeight: 8
    // The black hairline between two language slices: four greys of the
    // same ramp touching read as one bar with a gradient, so the slices
    // are cut apart rather than shaded apart.
    readonly property int detailBarGap: 2
    readonly property int detailLanguagesHeight: cardTitleHeight + 10 + detailBarHeight
                                                 + 10 + detailLineHeight
    readonly property int commitRowHeight: 40
    readonly property int contributorRowHeight: 26
    readonly property int detailCommitRows: 5
    readonly property int detailContributorRows: 5
    readonly property int detailCommitsHeight: cardTitleHeight + 10
                                               + detailCommitRows * commitRowHeight
    readonly property int detailContributorsHeight: cardTitleHeight + 10
                                                    + detailContributorRows
                                                    * contributorRowHeight
    // The face on a Recent commits row. It is 28 in a 40px row - the ~0.7
    // of the row the reference crop measures - and not the 24 it was: at 24
    // the face was centred on a two-line row while the headline sat on the
    // first line alone, 8px above it, so it read as hanging under the text.
    // At 28 it spans both lines and the two centres are the same point.
    readonly property int detailAvatarSize: 28
    readonly property int detailBadgeHeight: 20
    readonly property int detailBadgePadX: 8

    // The content column is now two columns wide: 860 + 12 + 252 = 1124, the
    // same 1124 the single column had, which is why the window does not move.
    // The width runs outside in for that reason - see `cell`: the 1400 is
    // what must not change, the heatmap card is what the cell pair makes of
    // the column, and the rail is the remainder.
    readonly property int contentWidth: windowWidth - 2 * pad - sidebarWidth - blockGap
    readonly property int railWidth: contentWidth - blockGap - heatmapCardWidth
    readonly property int headerHeight: avatarSize + 2 * cardPad
    readonly property int heatmapCardHeight: 2 * cardPad + cardTitleHeight + 10
                                             + monthLabelHeight + 6 + heatmapHeight
                                             + 14 + legendHeight
    readonly property int activityHeight: 2 * cardPad + cardTitleHeight + 10
                                          + activityRows * activityRowHeight
    // The rail's second card. Its own size, not the height of whatever sits
    // beside it: four rows and the card's chrome. What is left of the rail
    // goes to the tiles - see `tileHeight`.
    readonly property int languagesHeight: 2 * cardPad + cardTitleHeight + 10
                                           + languageRows * languageRowHeight

    // What the content column has to spend, and what the Repositories card
    // fills exactly: 16 + 22 + 10 + 640 + 16 = 704.
    readonly property int contentHeight: windowHeight - 2 * pad

    // 1400 is the one number written down rather than derived, and it is the
    // one the window already had: the redesign was not allowed to move it.
    // The height still falls out of the blocks - the header and the two rows
    // below it, the tiles having left the stack for the rail.
    readonly property int windowWidth: 1400
    readonly property int windowHeight: 2 * pad + headerHeight + blockGap
                                        + heatmapCardHeight + blockGap
                                        + activityHeight

    // -- animation ---------------------------------------------------------
    // Only opacity, translation and height animate. Every duration goes
    // through dur(): animScale 0 disables them, 5 slows them down.
    property real animScale: 1
    property int animFast: 80
    property int animEnter: 200
    property int animExit: 140
    readonly property int easeEnter: Easing.OutCubic
    readonly property int easeExit: Easing.InCubic

    function dur(ms) { return Math.round(ms * animScale); }

    // Thousands separator, locale independent: 1248 -> 1,248.
    function count(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ","); }
}
