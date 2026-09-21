import QtQuick
import "."

// The bordered black box every block sits in: 1px border, square corners, no
// shadow. An optional heading row (Nerd Font glyph + title) sits above the
// content area.
Rectangle {
    id: root

    property string title: ""
    property string glyph: ""
    default property alias content: body.data
    // Sits at the right end of the heading row (the heatmap's year nav).
    property alias controls: controls.data

    color: Config.cardBg
    border.color: Config.border
    border.width: 1
    radius: 0

    Row {
        id: heading

        visible: root.title !== ""
        height: visible ? Config.cardTitleHeight : 0
        spacing: Config.gap
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Config.cardPad

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: Config.fg
            font.family: Config.font
            font.pixelSize: Config.glyphSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Config.fgActive
            font.family: Config.font
            font.pixelSize: Config.fontSize
        }
    }

    Item {
        id: controls

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Config.cardPad
        height: heading.visible ? Config.cardTitleHeight : 0
        width: childrenRect.width
    }

    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: heading.visible ? heading.bottom : parent.top
        anchors.margins: Config.cardPad
        anchors.topMargin: heading.visible ? 10 : Config.cardPad
    }
}
