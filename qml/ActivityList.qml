import QtQuick
import "."

// The commit rows: headline, short sha, the repository it landed in, and how
// long ago it was committed. `Config.activityRows` sets how many there are;
// the taller window is what paid for them.
Card {
    id: root

    required property var api

    title: "Recent Activity"
    glyph: Config.glyphCommits
    height: Config.activityHeight

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
            // Clamped here too: the card is sized for exactly this many
            // rows, and a cache written before the count changed is longer.
            model: root.api.commits.slice(0, Config.activityRows)

            Item {
                required property var modelData

                width: root.width - 2 * Config.cardPad
                height: Config.activityRowHeight

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
