import QtQuick
import "."

// The detail panel, to the right of the repository list. It names the row the
// list has marked - by keyboard cursor or by pointer, whichever spoke last -
// the way the heatmap's tooltip names the day under its cursor. It is the
// repository's tooltip, parked in a fixed place.
//
// So it is pure display: no focus, no cursor of its own, nothing inside it to
// click. `Enter` on the list row already hands the URL to the browser, which
// is where everything this panel leaves out lives.
//
// Its card is the same 704 tall as the list beside it, and the window never
// resizes, so every block inside is a budget:
// 16 + 68 + 25 + 44 + 25 + 66 + 25 + 232 + 25 + 162 + 16 = 704.
Card {
    id: root

    required property var api
    // The marked row, or undefined while the list is empty or still loading.
    property var repo: undefined

    readonly property bool hasRepo: root.repo !== undefined && root.repo !== null
    readonly property string key: root.hasRepo ? root.repo.owner + "/" + root.repo.name
                                               : ""

    width: Config.repoDetailWidth
    height: Config.contentHeight

    // The contributors are fetched only once the cursor has stopped on a row.
    // Without this, walking the list with `j` would fire one REST call per row
    // passed over; with it, only the row that is actually being read costs a
    // request.
    Timer {
        id: settle

        interval: 250
        onTriggered: if (root.hasRepo)
            root.api.requestContributors(root.repo.owner, root.repo.name)
    }

    onKeyChanged: {
        settle.stop();
        if (root.key !== "")
            settle.restart();
    }

    // A 1px line with `detailRuleGap` of air above and below it. Four of them
    // separate the five blocks, and they are what the budget above counts as
    // 25 each.
    component Rule: Item {
        id: rule

        // The commits grid closes itself with a line flush under its last
        // row, so that boundary is already drawn: the `Rule` there keeps the
        // 25 the budget gives it and draws nothing.
        property bool line: true

        width: parent ? parent.width : 0
        height: Config.detailRuleHeight

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Config.border
            visible: rule.line
        }
    }

    // One of the three counters: glyph and number on a line, label under it.
    component Counter: Column {
        id: counter

        required property string glyph
        required property int value
        required property string label

        spacing: 2

        Row {
            spacing: Config.gap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: counter.glyph
                color: Config.fg
                font.family: Config.font
                font.pixelSize: Config.glyphSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // Zeros are drawn here, unlike in the list rows: three
                // counters where two vanish leaves a line that reads broken,
                // and in the panel the zero is the answer to a question the
                // heading asked.
                text: Config.count(counter.value)
                color: Config.fgActive
                font.family: Config.font
                font.pixelSize: Config.fontSizeCounter
            }
        }

        Text {
            text: counter.label
            color: Config.fgDim
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
        }
    }

    // A block heading, the same shape as `Card`'s own: glyph, then title.
    component Heading: Item {
        id: heading

        required property string glyph
        required property string title

        width: parent ? parent.width : 0
        height: Config.cardTitleHeight + 10

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            height: Config.cardTitleHeight
            spacing: Config.gap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: heading.glyph
                color: Config.fg
                font.family: Config.font
                font.pixelSize: Config.glyphSize
                visible: text !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: heading.title
                color: Config.fgActive
                font.family: Config.font
                font.pixelSize: Config.fontSize
            }
        }
    }

    Column {
        id: panel

        anchors.fill: parent
        spacing: 0
        visible: root.hasRepo
        opacity: root.api.stale ? Config.staleOpacity : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        // -- header: name, description, URL --------------------------------
        // Fixed height whatever the repository carries. Many repositories
        // have no description, and a block that grew and shrank as the cursor
        // walked the list would drag every block under it with it.
        Item {
            width: panel.width
            height: Config.detailHeaderHeight

            Item {
                id: nameLine

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Config.detailNameHeight

                Text {
                    id: mark

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hasRepo && root.repo.private ? Config.glyphLock
                                                            : Config.glyphRepo
                    color: Config.fg
                    font.family: Config.font
                    font.pixelSize: Config.glyphSizeName
                }

                // The panel's title, and the one thing on it that names which
                // row the list has marked: 20px, the size the Overview header
                // gives the account name, not the 14 of the list row it is
                // read beside.
                Text {
                    anchors.left: mark.right
                    anchors.leftMargin: Config.gap
                    anchors.right: badge.left
                    anchors.rightMargin: Config.gap
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: root.hasRepo ? root.repo.name : ""
                    color: Config.fgActive
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    elide: Text.ElideRight
                }

                // Rounded, like the search band's two controls: a square
                // box that size reads as a second card corner.
                Rectangle {
                    id: badge

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: visibility.implicitWidth + 2 * Config.detailBadgePadX
                    height: Config.detailBadgeHeight
                    radius: Config.radius
                    color: Config.clear
                    border.width: 1
                    border.color: Config.border

                    Text {
                        id: visibility

                        anchors.centerIn: parent
                        text: root.hasRepo && root.repo.private ? "Private" : "Public"
                        color: Config.fg
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                    }
                }
            }

            Text {
                id: description

                anchors.top: nameLine.bottom
                anchors.topMargin: Config.detailLineGap
                anchors.left: parent.left
                anchors.right: parent.right
                height: Config.detailLineHeight
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
                text: root.hasRepo ? root.repo.description : ""
                color: Config.fg
                font.family: Config.font
                font.pixelSize: Config.fontSize
                elide: Text.ElideRight
            }

            Row {
                anchors.top: description.bottom
                anchors.topMargin: Config.detailLineGap
                anchors.left: parent.left
                height: Config.detailLineHeight
                spacing: Config.gap

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.glyphLink
                    color: Config.fgDim
                    font.family: Config.font
                    font.pixelSize: Config.glyphSize
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: root.hasRepo ? root.repo.shortUrl : ""
                    color: Config.fgDim
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }
            }
        }

        Rule {}

        // -- stars, commits, pull requests ---------------------------------
        // Not stars / forks / watchers: on a personal account forks and
        // watchers are nearly always zero, while commits never are and pull
        // requests often are not.
        Item {
            width: panel.width
            height: Config.detailCounterHeight

            Row {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.hasRepo ? [
                        { "glyph": Config.glyphStar, "value": root.repo.stars,
                          "label": "Stars" },
                        { "glyph": Config.glyphCommit, "value": root.repo.commitCount,
                          "label": "Commits" },
                        { "glyph": Config.glyphPullRequest,
                          "value": root.repo.pullRequests, "label": "Pull requests" }
                    ] : []

                    Item {
                        required property int index
                        required property var modelData

                        width: Math.floor(panel.width / 3)
                        height: Config.detailCounterHeight

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: Config.detailCounterHeight
                            color: Config.border
                            visible: index > 0
                        }

                        Counter {
                            anchors.left: parent.left
                            anchors.leftMargin: index > 0 ? Config.cardPad : 0
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: modelData.glyph
                            value: modelData.value
                            label: modelData.label
                        }
                    }
                }
            }
        }

        Rule {}

        // -- languages -----------------------------------------------------
        Item {
            id: languages

            width: panel.width
            height: Config.detailLanguagesHeight

            readonly property var shares: root.hasRepo ? root.repo.languages : []

            // The slice's shade: the dominant language takes the lightest
            // grey of the heatmap's ramp and `Other`, always last, the
            // darkest: the palette is greys only, so shade stands in for
            // the usual coloured dots.
            function shade(index) {
                return Config.levels[Math.max(1, Config.levels.length - 1 - index)];
            }

            // Where a slice starts, in pixels. Summing the percentages before
            // it and rounding once - rather than rounding each slice's width
            // - is what keeps the bar filled edge to edge: the rounding error
            // never accumulates.
            function offset(index) {
                let sum = 0;
                for (let i = 0; i < index; i++)
                    sum += languages.shares[i].percent;
                return Math.round(bar.width * sum / 100);
            }

            Heading {
                id: languagesHeading

                glyph: ""
                title: "Languages"
            }

            Item {
                id: bar

                anchors.top: languagesHeading.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Config.detailBarHeight
                visible: languages.shares.length > 0

                Repeater {
                    model: languages.shares

                    Rectangle {
                        required property int index
                        required property var modelData

                        readonly property bool last: index === languages.shares.length - 1

                        x: languages.offset(index)
                        // The gap is taken out of the slice, not added between
                        // them, so the bar still ends exactly at the card's
                        // right edge. The last slice keeps its full width.
                        width: languages.offset(index + 1) - x
                               - (last ? 0 : Config.detailBarGap)
                        height: Config.detailBarHeight
                        color: languages.shade(index)
                    }
                }
            }

            // The legend: one dot per slice, in the shade of the slice it
            // names, which is what carries the pairing without colour.
            Row {
                anchors.top: bar.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                height: Config.detailLineHeight
                spacing: Config.cardPad
                visible: bar.visible

                Repeater {
                    model: languages.shares

                    Row {
                        required property int index
                        required property var modelData

                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: width / 2
                            color: languages.shade(index)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: modelData.name + " " + modelData.percent + "%"
                            color: Config.fg
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                        }
                    }
                }
            }

            // A repository with no code at all - the profile readme is one.
            Text {
                anchors.top: languagesHeading.bottom
                anchors.left: parent.left
                height: Config.detailBarHeight
                verticalAlignment: Text.AlignVCenter
                visible: !bar.visible
                text: "no code"
                color: Config.fgDim
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
            }
        }

        Rule {}

        // -- recent commits -------------------------------------------------
        // Every author, unlike Recent Activity on the Overview, which keeps
        // only the viewer's. Here the block belongs to the repository.
        Item {
            id: commits

            width: panel.width
            height: Config.detailCommitsHeight

            // The card holds five rows' worth of space whether or not five
            // commits exist, so the slice is a ceiling.
            readonly property var rows: root.hasRepo
                                        ? root.repo.commits.slice(0, Config.detailCommitRows)
                                        : []

            Heading {
                id: commitsHeading

                glyph: Config.glyphCommit
                title: "Recent commits"
            }

            // The grid closes itself, flush under the last row and on the
            // block's own bottom edge - which is where it lands whether five
            // commits arrived or three. The `Rule` below would have drawn the
            // same line 13px lower, centred in its 25, and that gap read as a
            // hole under the last row.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Config.border
            }

            Column {
                anchors.top: commitsHeading.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Repeater {
                    model: commits.rows

                    Item {
                        required property int index
                        required property var modelData

                        width: parent.width
                        height: Config.commitRowHeight

                        // The rule between two commits, drawn inside the row,
                        // so the block's 232 are unchanged. It runs the full
                        // width, under the face as well: with no air around it
                        // it reads as a grid, while the 12px above and below a
                        // `Rule` is what still marks the end of a block. The
                        // last row has none - the block's own `Rule` follows.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Config.border
                            visible: index < commits.rows.length - 1
                        }

                        Avatar {
                            id: face

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.avatar
                            size: Config.detailAvatarSize
                        }

                        // Two lines in 40px: headline and sha on the first,
                        // the age under the sha on the second. Anchored to
                        // the row's own edges rather than to the 24px face,
                        // which is shorter than both lines together.
                        Text {
                            anchors.left: face.right
                            anchors.leftMargin: Config.blockGap
                            anchors.right: sha.left
                            anchors.rightMargin: Config.gap
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            textFormat: Text.PlainText
                            text: modelData.headline
                            color: Config.fgActive
                            font.family: Config.font
                            font.pixelSize: Config.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            id: sha

                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            text: modelData.sha
                            color: Config.fg
                            font.family: Config.font
                            font.pixelSize: Config.fontSize
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: modelData.when
                            color: Config.fgDim
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                        }
                    }
                }
            }
        }

        Rule { line: false }

        // -- top contributors ------------------------------------------------
        // The only block that costs a request of its own: GraphQL has no
        // contributor list, so this one comes from REST, one call per
        // repository, and arrives after the rest of the panel is already
        // drawn. Until it does, a dim line - never a spinner.
        Item {
            id: contributors

            width: panel.width
            height: Config.detailContributorsHeight

            readonly property var entry: root.hasRepo
                                         ? root.api.contributors[root.key] : undefined
            readonly property var rows: entry ? entry.rows : []

            Heading {
                id: contributorsHeading

                glyph: Config.glyphContributors
                title: "Top contributors"
            }

            Column {
                anchors.top: contributorsHeading.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Repeater {
                    model: contributors.rows.slice(0, Config.detailContributorRows)

                    Item {
                        required property var modelData

                        width: parent.width
                        height: Config.contributorRowHeight

                        Avatar {
                            id: person

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.avatar
                            size: Config.contributorRowHeight - 6
                        }

                        Text {
                            anchors.left: person.right
                            anchors.leftMargin: Config.blockGap
                            anchors.right: total.left
                            anchors.rightMargin: Config.gap
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: modelData.login
                            color: Config.fgActive
                            font.family: Config.font
                            font.pixelSize: Config.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            id: total

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Config.count(modelData.contributions)
                            color: Config.fg
                            font.family: Config.font
                            font.pixelSize: Config.fontSize
                        }
                    }
                }
            }

            Text {
                anchors.top: contributorsHeading.bottom
                anchors.left: parent.left
                height: Config.contributorRowHeight
                verticalAlignment: Text.AlignVCenter
                visible: contributors.rows.length === 0
                textFormat: Text.PlainText
                text: {
                    if (!contributors.entry)
                        return "";
                    if (contributors.entry.state === "loading")
                        return "loading…";
                    if (contributors.entry.state === "failed")
                        return contributors.entry.error;
                    return "no contributors";
                }
                color: Config.fgDim
                font.family: Config.font
                font.pixelSize: Config.fontSize
            }
        }
    }

    // The same dim line the list card draws in place of its rows: what is
    // missing is either the data or a match, and the two must not read alike.
    Text {
        anchors.centerIn: parent
        visible: !root.hasRepo
        textFormat: Text.PlainText
        text: {
            if (root.api.error !== "" && !root.api.hasData)
                return root.api.error;
            if (!root.api.hasData)
                return "loading…";
            return "no repository selected";
        }
        color: Config.fgDim
        font.family: Config.font
        font.pixelSize: Config.fontSize
    }
}
