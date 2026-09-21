import QtQuick
import "."

// The line over a heatmap cell, for the mouse and for the keyboard cursor
// alike. A bordered box like every other surface here: square corners, no
// tail, the rofi window's near-black fill. It anchors itself above the cell
// it describes and falls below when there is no room, staying inside the
// bounds it was given.
Rectangle {
    id: root

    // The day being named: `x` and `y` in the coordinate space of `bounds`,
    // and the line to print, or null when no day is named. It arrives as one
    // object so the box never reads half of an update.
    property var cell: null
    property real cellSize: Config.cell
    // The box the tooltip may not leave; the grid area of the card.
    property Item bounds: parent

    // While it fades out the box keeps the day it was naming: an empty text
    // would shrink it to a small square and the coordinates would jump to
    // wherever the keyboard cursor stands, both of them visible through the
    // fade.
    property var held: null

    onCellChanged: {
        if (root.cell)
            root.held = root.cell;
    }

    color: Config.tooltipBg
    border.color: Config.border
    border.width: 1
    radius: 0

    width: label.implicitWidth + 2 * Config.tooltipPadX
    height: label.implicitHeight + 2 * Config.tooltipPadY

    // Centred on the cell, clamped so neither end runs past the grid.
    x: Math.max(0, Math.min(root.bounds ? root.bounds.width - root.width : 0,
                            (root.held ? root.held.x : 0) + (root.cellSize - root.width) / 2))
    // Above the cell, unless that would clip the top.
    y: !root.held ? 0
       : (root.held.y - root.height - Config.tooltipGap >= 0
          ? root.held.y - root.height - Config.tooltipGap
          : root.held.y + root.cellSize + Config.tooltipGap)

    opacity: root.cell ? 1 : 0
    visible: root.opacity > 0 && root.held !== null

    Behavior on opacity {
        NumberAnimation { duration: Config.dur(Config.animFast) }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.held ? root.held.text : ""
        color: Config.fgActive
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
    }
}
