import QtQuick
import "."

// 7x53 contribution grid for the selected year: month labels above, weekday
// labels on the left, year navigation in the heading, total and legend below.
// Weeks are drawn from the cells the backend hands over, each carrying its own
// weekday row, so the partial first and last weeks of a year line up.
//
// The card holds two of the Overview column's keyboard regions, stacked the
// way they are drawn: the year control on top and the grid below it.
// `Overview.qml` calls the move functions below; leaving the year upwards is
// its business, since the avatar above belongs to another card, and so is
// leaving the grid downwards, onto Recent Activity.
Card {
    id: root

    required property var api

    readonly property int pitch: Config.cell + Config.cellGap
    readonly property var weekdays: [
        { "row": 1, "text": "Mon" },
        { "row": 3, "text": "Wed" },
        { "row": 5, "text": "Fri" }
    ]

    // The focused region: -1 is the year control, 0 the grid.
    property int region: -1
    // False while the window's cursor sits outside this card, so only one
    // region on screen is ever marked.
    property bool focused: true
    property int cursorCol: 0
    property int cursorRow: 0
    // The cursor survives a refresh by date, not by coordinates: a year with
    // a different number of weeks would otherwise shift it sideways.
    property string cursorIso: ""

    // Watched rather than read inline, so a new snapshot re-places the cursor.
    readonly property var weeks: root.api.weeks

    // The last device to speak owns the highlight. Moving the mouse hands it
    // to the cell under the pointer, and to nothing at all while the pointer
    // sits on a gap; the next navigation key hands it back to the cursor,
    // which stayed where it was - the mouse still never moves it.
    property bool mouseLeads: false

    readonly property var hoverCell: root.mouseLeads && hover.col >= 0
                                     ? root.cellAt(hover.col, hover.row) : null
    readonly property var cursorCell: root.region >= 0 ? root.cellAt(root.cursorCol, root.cursorRow) : null
    readonly property bool cursorShown: root.focused && !root.mouseLeads && root.cursorCell !== null
    // The day being named, or null when none is. Column, row and line travel
    // as one object, so the outline and the box below never read half of an
    // update and never fall back on the cursor while they are being hidden.
    readonly property var tip: root.hoverCell
        ? { "col": hover.col, "row": hover.row, "label": root.hoverCell.label }
        : (root.cursorShown
           ? { "col": root.cursorCol, "row": root.cursorRow, "label": root.cursorCell.label }
           : null)

    title: "Contribution Activity"
    glyph: Config.glyphActivity
    height: Config.heatmapCardHeight

    onWeeksChanged: root.placeCursor()

    // -- cursor ------------------------------------------------------------

    // The cell at a column and weekday row, or null where the week is short.
    function cellAt(col, row) {
        const weeks = root.weeks;
        if (!weeks || col < 0 || col >= weeks.length)
            return null;
        const week = weeks[col];
        for (let i = 0; i < week.length; i++)
            if (week[i].row === row)
                return week[i];
        return null;
    }

    // Days run consecutively, so a week's rows are the range between its ends.
    function clampRow(col, row) {
        const week = root.weeks[col];
        return Math.max(week[0].row, Math.min(week[week.length - 1].row, row));
    }

    function locate(iso) {
        const weeks = root.weeks;
        for (let col = 0; col < weeks.length; col++)
            for (let i = 0; i < weeks[col].length; i++)
                if (weeks[col][i].date === iso)
                    return { "col": col, "row": weeks[col][i].row };
        return null;
    }

    // Keep the selected day across a refresh; on a new year fall on today,
    // and on a past year on its last day.
    function placeCursor() {
        const weeks = root.weeks;
        if (!weeks || weeks.length === 0) {
            // A year still loading has no grid to stand on; the year control
            // is the one region that is always there.
            root.cursorIso = "";
            root.region = -1;
            return;
        }
        const last = weeks[weeks.length - 1];
        const spot = root.locate(root.cursorIso)
                     || root.locate(root.api.todayIso)
                     || { "col": weeks.length - 1, "row": last[last.length - 1].row };
        root.setCursor(spot.col, spot.row);
    }

    function setCursor(col, row) {
        const cell = root.cellAt(col, row);
        if (!cell)
            return;
        root.cursorCol = col;
        root.cursorRow = row;
        root.cursorIso = cell.date;
    }

    // False when the key was not consumed, which only happens at week 0 going
    // left: the column's left edge, where the sidebar takes the cursor over.
    // The year control never refuses, since there the two keys are its arrows.
    function moveHorizontal(delta) {
        if (root.region < 0 || !root.cursorCell) {
            root.api.step_year(delta);
            return true;
        }
        const col = root.cursorCol + delta;
        if (col < 0)
            return false;
        if (col > root.weeks.length - 1)
            return true;
        root.setCursor(col, root.clampRow(col, root.cursorRow));
        return true;
    }

    // False when the cursor would step below its week: the grid's bottom
    // edge, where Recent Activity takes the cursor over.
    function moveVertical(delta) {
        if (root.region < 0 || !root.cursorCell) {
            if (delta > 0 && root.cursorIso !== "")
                root.region = 0;
            return true;
        }
        const week = root.weeks[root.cursorCol];
        const row = root.cursorRow + delta;
        if (row < week[0].row) {
            root.region = -1;
            return true;
        }
        if (row > week[week.length - 1].row)
            return false;
        root.setCursor(root.cursorCol, row);
        return true;
    }

    // -- year --------------------------------------------------------------

    controls: Rectangle {
        // The focused region is marked the same way the selected cell is: a
        // 1px white outline, nothing else.
        anchors.verticalCenter: parent.verticalCenter
        width: yearRow.width + 2 * Config.focusPad
        height: Config.cardTitleHeight
        color: Config.clear
        border.color: root.focused && root.region < 0 ? Config.fgActive : Config.clear
        border.width: 1
        radius: 0

        Behavior on border.color {
            ColorAnimation { duration: Config.dur(Config.animFast) }
        }

        Row {
            id: yearRow

            anchors.centerIn: parent
            spacing: Config.gap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "‹"
                color: previousArea.containsMouse ? Config.fgActive : Config.fg
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge

                Behavior on color {
                    ColorAnimation { duration: Config.dur(Config.animFast) }
                }

                MouseArea {
                    id: previousArea

                    anchors.fill: parent
                    anchors.margins: -Config.gap / 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.api.step_year(-1)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.api.year
                color: Config.fgActive
                font.family: Config.font
                font.pixelSize: Config.fontSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: nextArea.containsMouse ? Config.fgActive : Config.fg
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge

                Behavior on color {
                    ColorAnimation { duration: Config.dur(Config.animFast) }
                }

                MouseArea {
                    id: nextArea

                    anchors.fill: parent
                    anchors.margins: -Config.gap / 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.api.step_year(1)
                }
            }
        }
    }

    // -- grid --------------------------------------------------------------

    Item {
        id: grid

        anchors.fill: parent
        opacity: root.api.hasData ? (root.api.stale ? Config.staleOpacity : 1) : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        Repeater {
            model: root.api.months

            Text {
                required property var modelData

                x: Config.weekdayLabelWidth + modelData.column * root.pitch
                y: 0
                text: modelData.text
                color: Config.fgDim
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
            }
        }

        Item {
            id: cells

            y: Config.monthLabelHeight + 6
            width: parent.width
            height: Config.heatmapHeight

            Repeater {
                model: root.weekdays

                Text {
                    required property var modelData

                    x: 0
                    y: modelData.row * root.pitch + (Config.cell - height) / 2
                    text: modelData.text
                    color: Config.fgDim
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }
            }

            Repeater {
                model: root.api.weeks

                Item {
                    required property int index
                    required property var modelData

                    x: Config.weekdayLabelWidth + index * root.pitch
                    width: Config.cell
                    height: Config.heatmapHeight

                    Repeater {
                        model: modelData

                        Rectangle {
                            required property var modelData

                            y: modelData.row * root.pitch
                            width: Config.cell
                            height: Config.cell
                            color: Config.levels[modelData.level]
                            radius: 0
                        }
                    }
                }
            }

            // The highlight: an outline around the named cell, drawn just
            // outside it so the shade underneath is left alone. It follows
            // whichever device spoke last, so it sits with the tooltip.
            Rectangle {
                visible: root.tip !== null
                x: Config.weekdayLabelWidth + (root.tip ? root.tip.col : 0) * root.pitch - 1
                y: (root.tip ? root.tip.row : 0) * root.pitch - 1
                width: Config.cell + 2
                height: Config.cell + 2
                color: Config.clear
                border.color: Config.fgActive
                border.width: 1
                radius: 0
            }

            MouseArea {
                id: hover

                // Only the cells: the weekday labels are not hoverable.
                x: Config.weekdayLabelWidth
                width: Config.heatmapWidth
                height: Config.heatmapHeight
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                property int col: -1
                property int row: -1

                function track(px, py) {
                    root.mouseLeads = true;
                    // The gap between cells counts as nothing, not as the
                    // cell before it.
                    if (px % root.pitch >= Config.cell || py % root.pitch >= Config.cell) {
                        hover.col = -1;
                        return;
                    }
                    const col = Math.floor(px / root.pitch);
                    const row = Math.floor(py / root.pitch);
                    hover.col = root.cellAt(col, row) ? col : -1;
                    hover.row = row;
                }

                onPositionChanged: (mouse) => hover.track(mouse.x, mouse.y)
                // Leaving the grid is not an input: the cursor takes the
                // highlight back rather than leaving the card blank.
                onExited: {
                    hover.col = -1;
                    root.mouseLeads = false;
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: Config.count(root.api.yearTotal) + " contributions in " + root.api.year
            color: Config.fg
            font.family: Config.font
            font.pixelSize: Config.fontSize
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (Config.legendHeight - Config.legendCell) / 2
            spacing: Config.cellGap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Less"
                color: Config.fgDim
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
            }

            Repeater {
                model: Config.levels

                Rectangle {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: Config.legendCell
                    height: Config.legendCell
                    color: modelData
                    radius: 0
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "More"
                color: Config.fgDim
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
            }
        }

        // Last in the card, so it sits over the grid and the footer line.
        Tooltip {
            bounds: grid
            cell: root.tip ? { "x": Config.weekdayLabelWidth + root.tip.col * root.pitch,
                               "y": cells.y + root.tip.row * root.pitch,
                               "text": root.tip.label } : null
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.api.hasData
        textFormat: Text.PlainText
        text: root.api.error !== "" ? root.api.error : "loading…"
        color: Config.fgDim
        font.family: Config.font
        font.pixelSize: Config.fontSize
    }
}
