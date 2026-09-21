import QtQuick
import "."

// The content column of the Repositories screen: the list card on the left,
// at the share of the column it has in the reference mock, and the detail
// panel filling the rest. The panel takes no focus and holds no cursor - it
// draws whichever row is marked, so it follows the list rather than being
// navigated.
//
// Above the rows sits the search band - the query field and the visibility
// filter - and it costs exactly one row: 40 + 2 * 12 = 64, so the card's body
// is still 64 + 9 * 64 = 640 and the viewport stays a multiple of the row.
// Nine of the eleven repositories are on screen instead of ten.
//
// The rows are the whole account - the query over-fetches - and they are
// read-only: Enter or a click hands the repository's URL to the browser, the
// same way the Overview's avatar opens the profile. The mock's `>` is not
// drawn: it promises a panel that does not exist yet.
//
// The field reads one word as syntax: `@stars` orders the rows by star count
// and is what the screen opens with. It is an ordering, not a filter - it
// hides nothing, the repositories without a star keep their place at the
// bottom in the API's own order, and deleting the word restores that order
// whole.
//
// `Main.qml` owns the keyboard cursor and calls the move functions below, as
// it does on the Overview. Inside this column there are two regions stacked
// the way they are drawn: the search band, whose two controls `h`/`l` walks,
// and the list below it.
//
// On the rows the keyboard cursor and the pointer draw the same mark - the
// grey fill - so the heatmap's rule comes with it: the last device to speak
// owns it. Moving the mouse hands the fill to the row under the pointer, and
// to no row at all once it leaves the list; the next key hands it back to the
// cursor, which never moved.
Item {
    id: root

    required property var api

    // The window sets this while its cursor is in this column.
    property bool focused: false
    // The row the keyboard cursor sits on. The mouse never moves it.
    property int cursor: 0
    // Who owns the grey fill: the pointer while it is over a row, the cursor
    // otherwise. The two share one mark, so only one of them may draw it.
    property bool mouseLeads: false
    // The pointer's last position, in scene coordinates. A list scrolling
    // under a still pointer fires enter and leave on its own, and those are
    // the list moving, not the pointer speaking: without this, one `j` that
    // scrolls the viewport would hand the fill straight back to the mouse.
    property point pointerAt: Qt.point(-1, -1)
    // The row physically under the pointer, whether or not the pointer leads.
    property int hovered: -1

    function pointerMoved(pt, index) {
        root.hovered = index;
        if (pt.x === root.pointerAt.x && pt.y === root.pointerAt.y)
            return;
        root.pointerAt = pt;
        root.mouseLeads = true;
    }
    // Which region holds the cursor, and which control inside the band.
    property int region: regionList
    property int band: 0
    // All / Public / Private, cycled in place by the control on the right of
    // the band. A menu would be the app's first overlay, and three values do
    // not pay for one.
    property int visibility: 0

    readonly property int regionBand: 0
    readonly property int regionList: 1

    readonly property string query: search.query
    // Every key goes to the field: `Main.qml` reads this to stand its
    // shortcuts down, so that typing `q` does not close the window.
    readonly property bool searching: search.typing
    // The query is two things in one string and it is split exactly here, so
    // that nothing below has to know both halves: `sorted` is the order and
    // `terms` is what filters. The token counts only when it is typed whole -
    // `@sta` is still text, and searched for as text.
    readonly property var parsed: {
        const at = root.query.toLowerCase().indexOf(Config.sortStarsToken);
        if (at < 0)
            return { sorted: false, terms: root.query.trim().toLowerCase() };
        const rest = [root.query.slice(0, at),
                      root.query.slice(at + Config.sortStarsToken.length)].join(" ");
        return { sorted: true, terms: rest.trim().toLowerCase() };
    }

    readonly property bool sorted: root.parsed.sorted
    readonly property string terms: root.parsed.terms

    // What the detail panel draws: the row that is marked, by whichever
    // device is leading. The panel is the row's tooltip, so it follows the
    // mark rather than a selection of its own - there is none to make.
    readonly property var marked: {
        const index = root.mouseLeads && root.hovered >= 0 ? root.hovered : root.cursor;
        return index >= 0 && index < root.rows.length ? root.rows[index] : undefined;
    }

    // The query and the filter compose: a row has to pass both. The token
    // is not one of them - it only reorders what the two let through.
    readonly property var rows: {
        const q = root.terms;
        // `filter` hands back a copy, so the sort below never reorders
        // `api.repos` under the Overview.
        const kept = root.api.repos.filter((repo) => {
            if (root.visibility === 1 && repo.private)
                return false;
            if (root.visibility === 2 && !repo.private)
                return false;
            if (q === "")
                return true;
            return repo.name.toLowerCase().includes(q)
                || (repo.description || "").toLowerCase().includes(q);
        });
        if (!root.sorted)
            return kept;
        // The tie-break is explicit because `Array.sort` is not guaranteed
        // stable here and 8 of the 11 repositories have no stars at all:
        // without it they would come back in an arbitrary order instead of
        // the API's, newest push first.
        return kept
            .map((repo, index) => ({ repo: repo, index: index }))
            .sort((a, b) => (b.repo.stars - a.repo.stars) || (a.index - b.index))
            .map((entry) => entry.repo);
    }

    // The sidebar is to the left of both regions, so `h` always hands the key
    // back; `l` walks the band's two controls and is consumed by the list.
    // The detail panel is to the right of it but takes no focus, so there is
    // nothing there for `l` to move onto.
    function moveHorizontal(delta) {
        if (root.region === root.regionBand) {
            const next = root.band + delta;
            if (next < 0)
                return false;
            root.band = Math.min(1, next);
            return true;
        }
        return delta > 0;
    }

    function moveVertical(delta) {
        if (root.region === root.regionBand) {
            if (delta > 0)
                root.region = root.regionList;
            return;
        }
        // `k` from the top row leaves the list for the band, the way it
        // leaves the heatmap for the year control.
        if (delta < 0 && root.cursor === 0) {
            root.region = root.regionBand;
            return;
        }
        const next = Math.max(0, Math.min(list.count - 1, root.cursor + delta));
        root.cursor = next;
        // Scrolls the minimum needed to show the row whole, so no row is ever
        // drawn cut.
        list.positionViewAtIndex(next, ListView.Contain);
    }

    function activate() {
        if (root.region === root.regionList) {
            root.open(root.rows[root.cursor]);
            return;
        }
        if (root.band === 0)
            search.beginTyping();
        else
            root.cycleVisibility();
    }

    // Part of the interface `Main.qml` calls on whichever column is on show:
    // a key the cursor answered to takes the fill back from the pointer,
    // wherever it happens to be resting.
    function releaseMouse() {
        root.mouseLeads = false;
    }

    // The way in from anywhere: `/` puts this screen on show and starts
    // typing, since the field only ever filters these rows.
    function focusSearch() {
        root.region = root.regionBand;
        root.band = 0;
        search.beginTyping();
    }

    function cycleVisibility() {
        root.visibility = (root.visibility + 1) % Config.visibilities.length;
    }

    // Same as the Overview avatar: the browser takes over from here, so the
    // window closes behind it, and the open goes through the backend so it
    // outlives the quit.
    function open(repo) {
        if (repo && repo.url) {
            root.api.openUrl(repo.url);
            Qt.quit();
        }
    }

    // A narrower result always starts at the top: the row the cursor was on
    // is usually not in the list any more.
    onQueryChanged: root.toTop()
    onVisibilityChanged: root.toTop()

    function toTop() {
        root.cursor = 0;
        list.positionViewAtBeginning();
    }

    Card {
        id: card

        title: "Repositories"
        glyph: Config.glyphRepos
        width: Config.repoListWidth
        height: Config.contentHeight
        anchors.left: parent.left
        anchors.top: parent.top

        Item {
            id: searchBand

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Config.searchBandHeight

            SearchField {
                id: search

                query: Config.repoQueryDefault
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: filter.left
                anchors.rightMargin: Config.blockGap
                focused: root.focused && root.region === root.regionBand
                         && root.band === 0

                onEntered: {
                    root.region = root.regionBand;
                    root.band = 0;
                }
                onAccepted: {
                    root.region = root.regionList;
                    root.cursor = 0;
                }
            }

            // All -> Public -> Private, in place. The chevron says the box has
            // other values; it does not promise a menu.
            Rectangle {
                id: filter

                readonly property bool onCursor: root.focused
                                                  && root.region === root.regionBand
                                                  && root.band === 1

                anchors.top: parent.top
                anchors.right: parent.right
                width: Config.filterWidth
                height: Config.searchHeight
                radius: Config.radius
                color: filterArea.containsMouse ? Config.hover : Config.clear
                border.width: 1
                border.color: filter.onCursor ? Config.fgActive : Config.border

                Behavior on color {
                    ColorAnimation { duration: Config.dur(Config.animFast) }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Config.dur(Config.animFast) }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Config.searchPadX
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.visibilities[root.visibility]
                    // Brighter once it is holding rows back, so the list is
                    // never short for a reason nothing on screen states.
                    color: root.visibility === 0 ? Config.fg : Config.fgActive
                    font.family: Config.font
                    font.pixelSize: Config.fontSize

                    Behavior on color {
                        ColorAnimation { duration: Config.dur(Config.animFast) }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Config.searchPadX
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.glyphFilter
                    color: Config.fgDim
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }

                MouseArea {
                    id: filterArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.region = root.regionBand;
                        root.band = 1;
                        root.cycleVisibility();
                    }
                }
            }
        }

        ListView {
            id: list

            anchors.top: searchBand.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Config.repoListHeight
            clip: true
            visible: root.rows.length > 0
            model: root.rows
            // The viewport is an exact multiple of the row height, and these
            // two keep the wheel from stopping mid-row or overshooting past
            // the ends.
            snapMode: ListView.SnapToItem
            boundsBehavior: Flickable.StopAtBounds
            opacity: root.api.stale ? Config.staleOpacity : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.dur(Config.animEnter)
                    easing.type: Config.easeEnter
                }
            }

            // A refresh can return a shorter list than the one the cursor
            // was walking. An empty one is the model between snapshots, or a
            // query that matches nothing, and must not send the cursor back
            // to the top on its own.
            onCountChanged: if (count > 0)
                root.cursor = Math.min(root.cursor, count - 1)

            delegate: Item {
                id: row

                required property int index
                required property var modelData

                readonly property bool onCursor: root.focused
                                                  && !root.mouseLeads
                                                  && root.region === root.regionList
                                                  && index === root.cursor

                width: list.width
                height: Config.repoRowHeight

                // One mark for both devices: the pointer draws it while it
                // leads, the cursor the rest of the time.
                Rectangle {
                    anchors.fill: parent
                    color: (root.mouseLeads && area.containsMouse) || row.onCursor
                           ? Config.hover : Config.clear

                    Behavior on color {
                        ColorAnimation { duration: Config.dur(Config.animFast) }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    visible: row.index < list.count - 1
                    color: Config.border
                }

                // The book, or the padlock on a private repository. Four of
                // the eleven repositories on this account are private, so the
                // swap carries real information.
                Text {
                    id: mark

                    anchors.left: parent.left
                    anchors.leftMargin: Config.gap
                    // Centred on the name line, not on the row: the row is
                    // three lines tall and the mark belongs to the name.
                    anchors.top: block.top
                    anchors.topMargin: Math.round((title.height - height) / 2)
                    text: row.modelData.private ? Config.glyphLock
                                                : Config.glyphRepo
                    color: Config.fg
                    font.family: Config.font
                    font.pixelSize: Config.glyphSize
                }

                Column {
                    id: block

                    anchors.left: mark.right
                    anchors.leftMargin: Config.blockGap
                    anchors.right: parent.right
                    anchors.rightMargin: Config.gap
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // The name line carries the counters, so the two sit on
                    // one baseline without anchoring across parents.
                    Item {
                        id: title

                        width: block.width
                        height: name.implicitHeight

                        Text {
                            id: name

                            anchors.left: parent.left
                            textFormat: Text.PlainText
                            text: row.modelData.name
                            color: Config.fgActive
                            font.family: Config.font
                            font.pixelSize: Config.fontSize
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width
                                            - counters.width - Config.blockGap)
                        }

                        // Stars and forks, each drawn only when it is not
                        // zero: on this account almost every repository has
                        // both at zero, and a wall of zeros says nothing.
                        Row {
                            id: counters

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Config.blockGap

                            Row {
                                spacing: 4
                                visible: row.modelData.stars > 0

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Config.glyphStar
                                    color: Config.fg
                                    font.family: Config.font
                                    font.pixelSize: Config.glyphSize
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Config.count(row.modelData.stars)
                                    color: Config.fg
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSize
                                }
                            }

                            Row {
                                spacing: 4
                                visible: row.modelData.forks > 0

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Config.glyphFork
                                    color: Config.fg
                                    font.family: Config.font
                                    font.pixelSize: Config.glyphSize
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Config.count(row.modelData.forks)
                                    color: Config.fg
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSize
                                }
                            }
                        }
                    }

                    // Two repositories have no description; the line then
                    // collapses and the block re-centres rather than leaving
                    // a hole.
                    Text {
                        width: block.width
                        visible: text !== ""
                        textFormat: Text.PlainText
                        text: row.modelData.description
                        color: Config.fg
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Text {
                        width: block.width
                        textFormat: Text.PlainText
                        text: {
                            const parts = [];
                            if (row.modelData.language)
                                parts.push(row.modelData.language);
                            if (row.modelData.updated)
                                parts.push(row.modelData.updated);
                            return parts.join("  ·  ");
                        }
                        color: Config.fgDim
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.pointerMoved(area.mapToItem(null, area.mouseX,
                                                                 area.mouseY), row.index)
                    onPositionChanged: (mouse) => root.pointerMoved(
                        area.mapToItem(null, mouse.x, mouse.y), row.index)
                    // The fill goes back to the cursor when the pointer leaves
                    // the list - not when a row leaves from under it, which is
                    // the same event with the pointer still inside.
                    onExited: {
                        const p = area.mapToItem(list, area.mouseX, area.mouseY);
                        if (p.x < 0 || p.y < 0 || p.x >= list.width || p.y >= list.height) {
                            root.mouseLeads = false;
                            root.hovered = -1;
                        }
                    }
                    onClicked: {
                        root.region = root.regionList;
                        root.open(row.modelData);
                    }
                }
            }
        }

        // One line in place of the rows, never a dialog: what is missing is
        // either the data or a match, and the two must not read the same.
        Text {
            anchors.horizontalCenter: list.horizontalCenter
            anchors.verticalCenter: list.verticalCenter
            visible: root.rows.length === 0
            textFormat: Text.PlainText
            text: {
                if (root.api.error !== "" && !root.api.hasData)
                    return root.api.error;
                if (!root.api.hasData)
                    return "loading…";
                if (root.api.repos.length === 0)
                    return "no repositories";
                return "no matches";
            }
            color: Config.fgDim
            font.family: Config.font
            font.pixelSize: Config.fontSize
        }
    }

    RepoDetail {
        api: root.api
        repo: root.marked
        anchors.right: parent.right
        anchors.top: parent.top
    }
}
