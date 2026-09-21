import QtQuick
import "."

// The rail's last card: the three largest languages of the account and
// `Other`, each with a thin bar. It rides on the repository list both screens
// already share, so it costs no request, and it is the detail panel's own
// `language_shares` - only summed over every repository instead of one.
//
// One bar per row rather than the stacked bar this card started with. That
// swap is what cutting the list to four rows bought: nine rows left 95px of
// track and a 1% tail drew thinner than a pixel, while four leave exactly
// 100 - so a fill is the percentage in pixels and nothing can round away.
Card {
    id: root

    required property var api

    title: "Languages"
    glyph: Config.glyphLanguage
    height: Config.languagesHeight

    readonly property var shares: root.api.languages

    Column {
        anchors.fill: parent
        spacing: 0
        opacity: root.api.stale ? Config.staleOpacity : 1
        visible: root.shares.length > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        Repeater {
            // Clamped to what the card was sized for, the way Recent Activity
            // clamps its own: a cache written by a build with a different
            // count cannot overflow the card.
            model: root.shares.slice(0, Config.languageRows)

            Item {
                required property var modelData

                width: parent.width
                height: Config.languageRowHeight

                Text {
                    id: name

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Config.languageNameWidth
                    textFormat: Text.PlainText
                    text: modelData.name
                    color: Config.fg
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    elide: Text.ElideRight
                }

                // The track is the heatmap's empty cell and the fill the
                // shade above it, so the bar is built out of the same ramp
                // as everything else that measures something here.
                Rectangle {
                    anchors.left: name.right
                    anchors.leftMargin: Config.gap
                    anchors.verticalCenter: parent.verticalCenter
                    width: Config.languageBarWidth
                    height: Config.languageBarHeight
                    color: Config.levels[0]

                    Rectangle {
                        // 100 wide, so the percentage is the width.
                        width: modelData.percent
                        height: parent.height
                        color: Config.levels[3]
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Config.languagePercentWidth
                    horizontalAlignment: Text.AlignRight
                    text: modelData.percent + "%"
                    color: Config.fgActive
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }
            }
        }
    }

    // An account with no code at all draws this and no rows. No invented
    // copy: the same line the detail panel gives a repository with nothing
    // in it.
    Text {
        anchors.centerIn: parent
        visible: root.shares.length === 0
        text: root.api.hasData ? "no code" : "loading…"
        color: Config.fgDim
        font.family: Config.font
        font.pixelSize: Config.fontSize
    }
}
