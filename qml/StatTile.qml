import QtQuick
import "."

// One of the four tiles: Nerd Font glyph and number on the left, label on the
// right, one line.
//
// It was a centred column - glyph over number over label - while the tiles sat
// four across in a 120px box. In the rail the box is 252 wide and 91 tall, and
// a centred column left the whole width of it empty on both sides. Laid out
// across, the tile spans its card and the number reads as the thing it is.
Card {
    id: root

    required property string glyph
    required property int value
    required property string label
    property bool dim: false

    width: Config.tileWidth
    height: Config.tileHeight

    Item {
        anchors.fill: parent
        anchors.margins: Config.cardPad
        opacity: root.dim ? Config.staleOpacity : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        Text {
            id: mark

            anchors.left: parent.left
            anchors.leftMargin: -Config.tileGlyphOutset
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: Config.fg
            font.family: Config.font
            font.pixelSize: Config.glyphSizeTile
        }

        Text {
            anchors.left: mark.right
            anchors.leftMargin: Config.gap
            anchors.verticalCenter: parent.verticalCenter
            text: Config.count(root.value)
            color: Config.fgActive
            font.family: Config.font
            font.pixelSize: Config.fontSizeTile
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.label
            color: Config.fgDim
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
        }
    }
}
