import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import "."

// The window: a wlr-layer-shell overlay over the whole screen, transparent
// except for the fixed canvas centred in it - the sidebar on the left and the
// content column on its right. Switching screens swaps the column, it never
// resizes the canvas. Being a layer surface, it needs no compositor rule: no
// window decoration is drawn around it and nothing tiles it.
Window {
    id: root

    visible: true
    title: "gitframe"
    color: "transparent"
    width: Screen.width
    height: Screen.height

    // Exclusive keyboard, like a launcher: the overlay holds the keys for as
    // long as it is mapped, wherever the pointer goes. That fits because every
    // way out of the app closes it - there is nothing to alt-tab back to.
    LayerShell.Window.scope: "gitframe"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1

    // The surface has the keyboard grab from the moment it maps, but Qt does
    // not always mark the window active until the first input event, and keys
    // go nowhere until it does. Nudge it on map, and hand the focus back to
    // the cursor whenever it becomes active - unless the field is typing.
    Component.onCompleted: root.requestActivate()
    onActiveChanged: {
        if (root.active && !repositories.searching)
            keyboard.forceActiveFocus();
    }

    // Click away to close: everything around the canvas is transparent, and a
    // click there ends the visit the same way `Q` does.
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }

    // A `Shortcut` is resolved before the key reaches whatever holds the
    // focus, so every one of these has to stand down while the search field
    // is being typed into - otherwise `q` closes the window mid-word.
    Shortcut {
        sequences: ["R", "F5"]
        enabled: !repositories.searching
        onActivated: backend.refresh()
    }

    Shortcut {
        sequence: "Q"
        enabled: !repositories.searching
        onActivated: Qt.quit()
    }

    // Escape backs out one level at a time: out of the field first (the field
    // itself handles that), then out of the content column and back to the
    // sidebar, and only then out of the window. The middle step is the key
    // reaching `Keys.onPressed` below, which it only does while this is off.
    Shortcut {
        sequence: "Escape"
        enabled: !repositories.searching && !keyboard.inContent
        onActivated: Qt.quit()
    }

    // The way in from anywhere. It switches screen too: the field only ever
    // filters the repository list, so leaving it typing over the Overview
    // would filter something the window is not showing.
    Shortcut {
        sequence: "/"
        enabled: !repositories.searching
        onActivated: {
            sidebar.activeTab = 1;
            sidebar.cursorRow = 1;
            keyboard.inContent = true;
            repositories.focusSearch();
        }
    }

    // Everything the app draws: the 1400x736 canvas, centred on the screen.
    // It swallows its own clicks, so only the transparent rest dismisses.
    Rectangle {
        id: canvas

        anchors.centerIn: parent
        width: Config.windowWidth
        height: Config.windowHeight
        color: Config.bg

        MouseArea {
            anchors.fill: parent
        }

        // The window owns the keyboard cursor, but only down to which column holds
        // it: each column owns the regions inside itself. The cursor starts in the
        // sidebar, on the active tab. `l` crosses into the content column, at the
        // position it was left at; `h` from that column's left edge hands it back.
        // The year control is the one region that never exits sideways, since
        // there `h` and `l` are the `<` and `>` arrows.
        Item {
            id: keyboard

            anchors.fill: parent
            focus: true

            property bool inContent: false

            // The column the active tab puts on show. Both are kept alive rather
            // than loaded on demand, so a screen comes back with its cursor where
            // it was left. Each answers the same four calls.
            readonly property Item content: sidebar.activeTab === 0 ? overview
                                                                    : repositories

            Keys.onPressed: (event) => {
                switch (event.key) {
                case Qt.Key_H:
                case Qt.Key_Left:
                    if (keyboard.inContent && !keyboard.content.moveHorizontal(-1))
                        keyboard.inContent = false;
                    break;
                case Qt.Key_L:
                case Qt.Key_Right:
                    if (keyboard.inContent)
                        keyboard.content.moveHorizontal(1);
                    else
                        keyboard.inContent = true;
                    break;
                case Qt.Key_J:
                case Qt.Key_Down:
                    if (keyboard.inContent)
                        keyboard.content.moveVertical(1);
                    else
                        sidebar.moveVertical(1);
                    break;
                case Qt.Key_K:
                case Qt.Key_Up:
                    if (keyboard.inContent)
                        keyboard.content.moveVertical(-1);
                    else
                        sidebar.moveVertical(-1);
                    break;
                case Qt.Key_Escape:
                    // Only ever reached from the content column: from the sidebar
                    // the shortcut above took the key and closed the window. This
                    // is the way back that `h` only offers at a region's left edge.
                    keyboard.inContent = false;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    if (keyboard.inContent)
                        keyboard.content.activate();
                    else
                        sidebar.activate();
                    break;
                default:
                    return;
                }
                // A key the cursor answered to takes the highlight back from the
                // mouse, wherever the pointer happens to be resting.
                keyboard.content.releaseMouse();
                event.accepted = true;
            }

            Sidebar {
                id: sidebar

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Config.pad
                api: backend
                focused: !keyboard.inContent
            }

            Overview {
                id: overview

                anchors.left: sidebar.right
                anchors.leftMargin: Config.blockGap
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: Config.pad
                anchors.bottomMargin: Config.pad
                anchors.rightMargin: Config.pad
                api: backend
                visible: keyboard.content === overview
                focused: keyboard.inContent && visible
            }

            Repositories {
                id: repositories

                anchors.left: sidebar.right
                anchors.leftMargin: Config.blockGap
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: Config.pad
                anchors.bottomMargin: Config.pad
                anchors.rightMargin: Config.pad
                api: backend
                visible: keyboard.content === repositories
                focused: keyboard.inContent && visible

                // The field takes the focus away from the window's key handler,
                // by `/` or by a click, and has to hand it back on the way out.
                onSearchingChanged: {
                    if (repositories.searching)
                        keyboard.inContent = true;
                    else
                        keyboard.forceActiveFocus();
                }
            }
        }
    }
}
