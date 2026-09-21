import QtQuick
import "."

// The content column of the Overview screen: the four blocks stacked with the
// same gap. It also owns its own chain of keyboard regions - the avatar on
// top, then the year control, then the grid - the way the heatmap owns the two
// it draws. `Main.qml` still handles every key; this only exposes the moves.
Item {
    id: root

    required property var api

    // The window sets this while its cursor is in this column rather than in
    // the sidebar, so only one region on screen is ever marked.
    property bool focused: false
    // The topmost region. It starts on the avatar, so the first `l` out of the
    // sidebar lands there; after that the position is simply kept.
    property bool onAvatar: true

    // Part of the interface `Main.qml` calls on whichever column is on show:
    // a key takes the highlight back from the pointer.
    function releaseMouse() {
        heatmap.mouseLeads = false;
    }

    // Returns false when the cursor is already at this column's left edge and
    // the key belongs to the sidebar instead.
    function moveHorizontal(delta) {
        if (root.onAvatar)
            return delta > 0;  // nothing sits right of the avatar either
        return heatmap.moveHorizontal(delta);
    }

    function moveVertical(delta) {
        if (root.onAvatar) {
            if (delta > 0)
                root.onAvatar = false;
            return;
        }
        if (delta < 0 && heatmap.region < 0) {
            root.onAvatar = true;
            return;
        }
        heatmap.moveVertical(delta);
    }

    function activate() {
        if (root.onAvatar)
            header.open();
    }

    Column {
        anchors.fill: parent
        spacing: Config.blockGap

        Header {
            id: header

            width: parent.width
            api: root.api
            focused: root.focused && root.onAvatar
        }

        // Under the header the column splits in two: the heatmap and the
        // commits on the left, the tiles and the languages in the rail. Only
        // the left one holds keyboard regions - the rail draws and nothing
        // else, the way the Repositories detail panel does.
        Row {
            width: parent.width
            spacing: Config.blockGap

            Column {
                spacing: Config.blockGap

                Heatmap {
                    id: heatmap

                    width: Config.heatmapCardWidth
                    api: root.api
                    focused: root.focused && !root.onAvatar
                }

                ActivityList {
                    width: Config.heatmapCardWidth
                    api: root.api
                }
            }

            Column {
                spacing: Config.blockGap

                // The four tiles stacked, rather than a row across the
                // window. They keep no wrapper card: a heading over them
                // would cost the height the numbers need.
                Column {
                    spacing: Config.blockGap

                    StatTile {
                        glyph: Config.glyphStreak
                        value: root.api.currentStreak
                        label: "Current streak"
                        dim: root.api.stale
                    }

                    StatTile {
                        glyph: Config.glyphBusiest
                        value: root.api.busiestDay
                        // The number alone does not say which day it was.
                        label: root.api.busiestOn !== ""
                               ? "Busiest · " + root.api.busiestOn : "Busiest day"
                        dim: root.api.stale
                    }

                    StatTile {
                        glyph: Config.glyphActiveDays
                        value: root.api.activeDays
                        label: "Active days"
                        dim: root.api.stale
                    }

                    StatTile {
                        glyph: Config.glyphAverage
                        value: root.api.perWeek
                        label: "Avg / week"
                        dim: root.api.stale
                    }
                }

                Languages {
                    width: Config.railWidth
                    api: root.api
                }
            }
        }
    }
}
