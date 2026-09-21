import QtQuick
import "."

// The frame's left column, identical on every screen: the profile block, the
// tab list, the pinned repositories and the offline line at the foot.
// `Main.qml` owns the cursor and calls the move functions below.
//
// The search field was reserved here and is not: it only ever filtered the
// repository list, so it lives in that card, above the rows it acts on.
//
// The avatar here is deliberately the second one on screen: the 56px one says
// whose app this is, the 80px one in the Overview header is the profile card.
// That only reads as intentional because the two differ in weight, so this one
// must stay smaller - and it is a mark, not a control: no link, no focus.
//
// The third line is the account's dominant language, not `api.bio`: the real
// bio is two wrapped lines and this column is 232px wide. A name longer than
// the column is elided, never wrapped.
//
// The tabs and the pinned rows are one cursor list, walked by `j`/`k` in a
// single run, but they are not the same kind of row: `Enter` on a tab swaps
// the content column, `Enter` on a pinned repository opens the browser and
// closes the window. A pinned item can belong to another account, so there is
// no row in the Repositories list for it to select instead.
//
// It is a Card, like every block in the content column: without that border
// the column bled into the window and nothing separated it from the blocks on
// its right. The 232px are the box, so the content inside is 232 - 2 * cardPad
// = 200 wide and the window size is unchanged.
Card {
    id: root

    required property var api

    // The window sets this while its cursor is in the sidebar.
    property bool focused: false
    // The screen on show, and the row the cursor sits on. They start on the
    // same tab and share one mark - the fill - so only one of them is ever
    // drawn: `cursorRow` while the sidebar is focused, `activeTab` otherwise.
    // `activeTab` indexes the tabs alone; `cursorRow` runs on past them, into
    // the pinned list.
    property int activeTab: 0
    property int cursorRow: 0

    // A list, so Commits / Stats / Settings can be added later without
    // rewriting this file. A count of 0 draws no count: the Overview has no
    // number, and Repositories has none until a snapshot is on screen.
    readonly property var tabs: [
        { "name": "Overview", "glyph": Config.glyphOverview, "count": 0 },
        { "name": "Repositories", "glyph": Config.glyphRepos, "count": api.repositories }
    ]

    readonly property var pinned: root.api.pinned
    readonly property int rowCount: root.tabs.length + root.pinned.length

    // A refresh can shorten the list - a pin dropped, or the first snapshot
    // replacing an empty one - so the cursor is pulled back inside it.
    onRowCountChanged: root.cursorRow = Math.min(root.cursorRow,
                                                 root.rowCount - 1)

    function moveVertical(delta) {
        root.cursorRow = Math.max(0, Math.min(root.rowCount - 1,
                                              root.cursorRow + delta));
    }

    // Moving onto a row does nothing; this is what a row does. On a tab it
    // switches screen, and on a pinned repository it hands the URL to the
    // browser and closes the window, the same way a Repositories row does.
    function activate() {
        if (root.cursorRow < root.tabs.length) {
            root.activeTab = root.cursorRow;
            return;
        }
        root.open(root.pinned[root.cursorRow - root.tabs.length]);
    }

    function open(repo) {
        if (repo && repo.url) {
            root.api.openUrl(repo.url);
            Qt.quit();
        }
    }

    width: Config.sidebarWidth

    Column {
        id: mark

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.gap
        opacity: root.api.stale ? Config.staleOpacity : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        Row {
            spacing: Config.blockGap

            Avatar {
                source: root.api.avatar ? "file://" + root.api.avatar : ""
                size: Config.sidebarAvatarSize
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    textFormat: Text.PlainText
                    text: root.api.name
                    color: Config.fgActive
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeMedium
                }

                Text {
                    textFormat: Text.PlainText
                    text: root.api.login ? "@" + root.api.login : ""
                    color: Config.fg
                    font.family: Config.font
                    font.pixelSize: Config.fontSize
                }
            }
        }

        Row {
            spacing: Config.gap

            Text {
                id: languageGlyph

                anchors.verticalCenter: parent.verticalCenter
                text: Config.glyphLanguage
                color: Config.fgDim
                font.family: Config.font
                font.pixelSize: Config.glyphSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: mark.width - languageGlyph.width - Config.gap
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: root.api.language
                color: Config.fgDim
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
            }
        }
    }

    Rectangle {
        id: markRule

        anchors.top: mark.bottom
        anchors.topMargin: Config.ruleGap
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Config.border
    }

    Column {
        id: tabColumn

        anchors.top: markRule.bottom
        anchors.topMargin: Config.ruleGap
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.gap

        Repeater {
            model: root.tabs

            Rectangle {
                required property int index
                required property var modelData

                // The fill is the cursor. While the cursor is in the sidebar
                // it marks the row under it; when the cursor leaves for the
                // content column it falls back to the active screen's tab.
                // One filled box on screen, never two - which is why the 1px
                // white ring these rows used to carry is gone.
                readonly property bool filled: root.focused
                                               ? index === root.cursorRow
                                               : index === root.activeTab

                width: tabColumn.width
                height: Config.tabHeight
                // The fill inverts: off-white box, black label and glyph.
                color: filled ? Config.activeFill : Config.clear
                radius: Config.radius

                Behavior on color {
                    ColorAnimation { duration: Config.dur(Config.animFast) }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Config.sidebarRowPadX
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.gap

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.glyph
                        color: filled ? Config.fgInvert : Config.fg
                        font.family: Config.font
                        font.pixelSize: Config.glyphSize

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.dur(Config.animFast)
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: filled ? Config.fgInvert : Config.fg
                        font.family: Config.font
                        font.pixelSize: Config.fontSize

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.dur(Config.animFast)
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Config.sidebarRowPadX
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.count > 0
                    text: "[" + Config.count(modelData.count) + "]"
                    color: filled ? Config.fgInvert : Config.fg
                    font.family: Config.font
                    font.pixelSize: Config.fontSize

                    Behavior on color {
                        ColorAnimation { duration: Config.dur(Config.animFast) }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cursorRow = index;
                        root.activeTab = index;
                    }
                }
            }
        }
    }

    // The pinned repositories, below a second rule. The whole block goes when
    // there is nothing pinned - an empty heading would hold space for a list
    // the account does not have.
    Rectangle {
        id: pinnedRule

        anchors.top: tabColumn.bottom
        anchors.topMargin: Config.ruleGap
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.pinned.length > 0
        height: 1
        color: Config.border
    }

    Column {
        id: pinnedColumn

        anchors.top: pinnedRule.bottom
        anchors.topMargin: Config.ruleGap
        anchors.left: parent.left
        anchors.right: parent.right
        visible: pinnedRule.visible
        spacing: Config.gap
        opacity: root.api.stale ? Config.staleOpacity : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }

        // The block's heading, and the only pin on screen. It sits where the
        // tab glyphs do, and the names below it where the tab labels do.
        Row {
            height: Config.cardTitleHeight
            x: Config.sidebarRowPadX
            spacing: Config.gap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.glyphPinned
                color: Config.fg
                font.family: Config.font
                font.pixelSize: Config.glyphSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.pinnedTitle
                color: Config.fgActive
                font.family: Config.font
                font.pixelSize: Config.fontSize
            }
        }

        Repeater {
            model: root.pinned

            Rectangle {
                required property int index
                required property var modelData

                // The cursor runs on from the tabs, so this row's place in it
                // is its index past the last tab.
                readonly property int row: root.tabs.length + index
                // The same fill the tabs carry, and here it is only ever the
                // cursor: a pinned row is never the active screen, so it goes
                // blank the moment the cursor leaves the sidebar.
                readonly property bool filled: root.focused
                                               && row === root.cursorRow

                width: pinnedColumn.width
                height: Config.tabHeight
                color: filled ? Config.activeFill : Config.clear
                radius: Config.radius

                Behavior on color {
                    ColorAnimation { duration: Config.dur(Config.animFast) }
                }

                // The bare name, elided: a pinned repository can be someone
                // else's, and `owner/name` does not fit a 200px column.
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Config.sidebarLabelX
                    anchors.right: parent.right
                    anchors.rightMargin: Config.sidebarRowPadX
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.name
                    color: filled ? Config.fgInvert : Config.fg
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.fontSize

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.dur(Config.animFast)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cursorRow = row;
                        root.open(modelData);
                    }
                }
            }
        }
    }

    // Offline / failed refresh: a dim line at the foot, never a dialog. The
    // blocks keep showing the last snapshot, dimmed.
    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.api.error !== "" && root.api.hasData
        textFormat: Text.PlainText
        text: root.api.error
        color: Config.fgDim
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        wrapMode: Text.WordWrap
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.dur(Config.animEnter)
                easing.type: Config.easeEnter
            }
        }
    }
}
