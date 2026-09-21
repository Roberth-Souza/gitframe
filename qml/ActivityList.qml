import QtQuick
import "."

// The commit rows: headline, short sha, the repository it landed in, and how
// long ago it was committed. `Config.activityRows` sets how many there are;
// the taller window is what paid for them.
//
// The rows are links to their commit on GitHub, and the card is the last of
// the Overview column's keyboard regions, below the grid. The cursor and the
// pointer draw the same mark, the grey `Config.hover` fill, and the last
// device to speak owns it - the Repositories list's rule.
Card {
    id: root

    required property var api

    // False while the window's cursor sits outside this card.
    property bool focused: false
    property int cursor: 0
    property bool mouseLeads: false

    // Clamped here too: the card is sized for exactly this many rows, and a
    // cache written before the count changed is longer.
    readonly property var rows: root.api.commits.slice(0, Config.activityRows)

    title: "Recent Activity"
    glyph: Config.glyphCommits
    height: Config.activityHeight

    // A refresh can bring fewer rows than the cursor was walking.
    onRowsChanged: if (root.rows.length > 0)
        root.cursor = Math.min(root.cursor, root.rows.length - 1)

    // False when `k` leaves the first row: the grid above takes it over.
    function moveVertical(delta) {
        const next = root.cursor + delta;
        if (next < 0)
            return false;
        root.cursor = Math.min(next, Math.max(root.rows.length - 1, 0));
        return true;
    }

    function activate() {
        root.open(root.rows[root.cursor]);
    }

    // Same as the Overview avatar: the browser takes over from here, so the
    // window closes behind it, and the open goes through the backend so it
    // outlives the quit.
    function open(commit) {
        if (commit && commit.url) {
            root.api.openUrl(commit.url);
            Qt.quit();
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0
        opacity: root.api.stale ? Config.staleOpacity : 1
        visible: root.api.commits.length > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        Repeater {
            model: root.rows

            Item {
                id: row

                required property int index
                required property var modelData

                width: root.width - 2 * Config.cardPad
                height: Config.activityRowHeight

                // Bleeds `gap` into the card's padding on both sides, so the
                // text does not sit flush against the edge of its own fill.
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -Config.gap
                    anchors.rightMargin: -Config.gap
                    color: (root.mouseLeads && area.containsMouse)
                           || (root.focused && !root.mouseLeads
                               && row.index === root.cursor)
                           ? Config.hover : Config.clear

                    Behavior on color {
                        ColorAnimation { duration: Config.dur(Config.animFast) }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.gap
                    width: parent.width - when.width - Config.gap

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: modelData.headline
                        color: Config.fgActive
                        font.family: Config.font
                        font.pixelSize: Config.fontSize
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, parent.width - sha.width
                                        - repo.width - 2 * Config.gap)
                    }

                    Text {
                        id: sha

                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.sha
                        color: Config.fg
                        font.family: Config.font
                        font.pixelSize: Config.fontSize
                    }

                    Text {
                        id: repo

                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: "in /" + modelData.repo
                        color: Config.fgDim
                        font.family: Config.font
                        font.pixelSize: Config.fontSize
                    }
                }

                Text {
                    id: when

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.when
                    color: Config.fgDim
                    font.family: Config.font
                    font.pixelSize: Config.fontSize
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    anchors.leftMargin: -Config.gap
                    anchors.rightMargin: -Config.gap
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.mouseLeads = true
                    onPositionChanged: root.mouseLeads = true
                    onClicked: root.open(row.modelData)
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.api.commits.length === 0
        textFormat: Text.PlainText
        text: root.api.error !== "" ? root.api.error
                                        : (root.api.hasData ? "no commits in "
                                           + root.api.year : "loading…")
        color: Config.fgDim
        font.family: Config.font
        font.pixelSize: Config.fontSize
    }
}
