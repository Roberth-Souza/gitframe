import QtQuick
import "."

// Circular avatar and identity on the left, four counters on the right,
// separated by vertical rules. The avatar is the window's topmost keyboard
// region and opens the profile, by click or by Enter.
Card {
    id: root

    required property var api

    // The window sets this when its keyboard cursor is on the avatar.
    property bool focused: false

    // Handing the URL to the browser is the end of the visit: the window has
    // nothing left to say once the profile is open elsewhere, so it closes.
    // The open goes through the backend, not `Qt.openUrlExternally`, which
    // does not survive the quit on the next line.
    function open() {
        if (root.api.profileUrl !== "") {
            root.api.openUrl(root.api.profileUrl);
            Qt.quit();
        }
    }

    readonly property var counters: [
        { "glyph": Config.glyphRepos, "value": api.repositories, "label": "Repositories" },
        { "glyph": Config.glyphFollowing, "value": api.following, "label": "Following" },
        { "glyph": Config.glyphFollowers, "value": api.followers, "label": "Followers" },
        { "glyph": Config.glyphContributions, "value": api.contributions, "label": "Contributions" }
    ]

    height: Config.headerHeight

    Item {
        anchors.fill: parent
        opacity: root.api.stale ? Config.staleOpacity : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        Avatar {
            id: avatar

            source: root.api.avatar ? "file://" + root.api.avatar : ""
            size: Config.avatarSize
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // The ring carries both marks: it is this region's cursor
            // outline and the hover feedback. The avatar itself is an image
            // and must not brighten or scale. Grey and 3px rather than the
            // 1px white the other regions use - see `Config.focusRing`.
            readonly property bool marked: root.focused || profileArea.containsMouse

            ringColor: marked ? Config.focusRing : Config.border
            ringWidth: marked ? Config.focusRingWidth : 1

            // Opens the profile in the default browser, through xdg-open.
            MouseArea {
                id: profileArea

                anchors.fill: parent
                enabled: root.api.profileUrl !== ""
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open()
            }
        }

        Column {
            id: identity

            anchors.left: avatar.right
            anchors.leftMargin: Config.cardPad + Config.gap
            // Bound on the right as well, so the bio below elides against the
            // counters rather than against a width written down here.
            anchors.right: counters.left
            anchors.rightMargin: Config.cardPad
            anchors.verticalCenter: parent.verticalCenter
            spacing: Config.gap

            Text {
                textFormat: Text.PlainText
                text: root.api.name
                color: Config.fgActive
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
            }

            Text {
                textFormat: Text.PlainText
                text: root.api.login ? "@" + root.api.login : ""
                color: Config.fg
                font.family: Config.font
                font.pixelSize: Config.fontSize
            }

            // Location then bio, both the account's own. The rule between
            // them is the counters' own separator, at the height of a line.
            //
            // The location is as wide as it needs to be and the bio takes
            // whatever is left: a bio can run to 160 characters and is
            // always the line that gets cut, so it is the one that must not
            // be sized by hand.
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                height: Config.glyphSize
                visible: root.api.bio !== "" || root.api.location !== ""

                Row {
                    id: place

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.gap
                    visible: root.api.location !== ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Config.glyphLocation
                        color: Config.fgDim
                        font.family: Config.font
                        font.pixelSize: Config.glyphSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: root.api.location
                        color: Config.fgDim
                        font.family: Config.font
                        font.pixelSize: Config.fontSize
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.api.bio !== ""
                        width: 1
                        height: Config.glyphSize
                        color: Config.border
                    }
                }

                Text {
                    id: bioGlyph

                    anchors.left: place.visible ? place.right : parent.left
                    anchors.leftMargin: place.visible ? Config.gap : 0
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.api.bio !== ""
                    text: Config.glyphBio
                    color: Config.fgDim
                    font.family: Config.font
                    font.pixelSize: Config.glyphSize
                }

                Text {
                    anchors.left: bioGlyph.right
                    anchors.leftMargin: Config.gap
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.api.bio !== ""
                    textFormat: Text.PlainText
                    text: root.api.bio
                    color: Config.fgDim
                    font.family: Config.font
                    font.pixelSize: Config.fontSize
                    elide: Text.ElideRight
                }
            }
        }

        Row {
            id: counters

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Repeater {
                model: root.counters

                Row {
                    required property int index
                    required property var modelData

                    spacing: 0

                    Rectangle {
                        width: 1
                        height: Config.separatorHeight
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.border
                        visible: index > 0
                    }

                    Column {
                        width: Config.counterWidth
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.glyph
                            color: Config.fg
                            font.family: Config.font
                            font.pixelSize: Config.glyphSize
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Config.count(modelData.value)
                            color: Config.fgActive
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeCounter
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Config.fgDim
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                        }
                    }
                }
            }
        }
    }
}
