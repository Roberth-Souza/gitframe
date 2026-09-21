import QtQuick
import "."

// The Repositories search box: a magnifier, the query, and a caret that is
// only drawn while the box is being typed into. It rounds, like the other two
// controls in the app; the boxes that hold data stay square.
//
// The box carries one mark for two states - a white border - because the two
// cannot contend: the keyboard cursor can only sit here, and typing can only
// start, while it is the focused region. The caret and the placeholder
// dropping out are what separate "on it" from "in it".
//
// It does not own the cursor: it reports what happened - `entered` when it
// takes the text focus by whatever route, `left` when it gives it up - and the
// screen above moves its cursor to match.
Rectangle {
    id: root

    property alias query: input.text
    // The keyboard cursor sits on the box.
    property bool focused: false
    // The box has the text focus: every key goes to it and no vim motion runs.
    readonly property bool typing: input.activeFocus

    signal entered()
    signal left()
    // Enter: the query is done, take the cursor to the first row.
    signal accepted()

    function beginTyping() { input.forceActiveFocus(); }
    function endTyping() { input.focus = false; }

    height: Config.searchHeight
    color: Config.clear
    radius: Config.radius
    border.width: 1
    border.color: root.focused || root.typing ? Config.fgActive : Config.border

    Behavior on border.color {
        ColorAnimation { duration: Config.dur(Config.animFast) }
    }

    // Anywhere on the box that the text itself does not cover: the padding
    // above, below and left of it still starts a search.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: root.beginTyping()
    }

    Text {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Config.searchPadX
        anchors.verticalCenter: parent.verticalCenter
        text: Config.glyphSearch
        color: root.typing || input.text !== "" ? Config.fg : Config.fgDim
        font.family: Config.font
        font.pixelSize: Config.glyphSize

        Behavior on color {
            ColorAnimation { duration: Config.dur(Config.animFast) }
        }
    }

    TextInput {
        id: input

        anchors.left: mark.right
        anchors.leftMargin: Config.gap
        anchors.right: parent.right
        anchors.rightMargin: Config.searchPadX
        anchors.verticalCenter: parent.verticalCenter
        color: Config.fgActive
        selectionColor: Config.activeFill
        selectedTextColor: Config.fgInvert
        font.family: Config.font
        font.pixelSize: Config.fontSize
        clip: true

        onActiveFocusChanged: activeFocus ? root.entered() : root.left()

        // Escape backs out of the box and Enter hands the cursor to the rows;
        // both keep the query, which the field itself is still showing.
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.endTyping();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.endTyping();
                root.accepted();
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        Text {
            anchors.fill: parent
            visible: input.text === ""
            verticalAlignment: Text.AlignVCenter
            text: Config.searchPlaceholder
            color: Config.fgDim
            font.family: Config.font
            font.pixelSize: Config.fontSize
        }
    }
}
