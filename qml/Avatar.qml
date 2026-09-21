import QtQuick
import QtQuick.Effects
import "."

// The circular avatar, drained of colour and masked to a circle, inside a 1px
// ring. The 56px mark at the top of the sidebar, the 80px one in the Overview
// header, and the 24px faces on the detail panel's commit and contributor
// rows. Only the size, the source and what the ring means differ, so the
// caller owns all three.
//
// `source` is whatever `Image` accepts: a `file://` path for the viewer's own
// avatar, which the cache holds on disk, or the `https://` URL the API gives
// for everyone else. An empty or unreachable one leaves the bare ring, which
// is also what the window shows offline.
Item {
    id: root

    required property string source

    property int size: Config.avatarSize
    property color ringColor: Config.border
    // A thicker ring grows outwards, onto the background, instead of eating
    // into the avatar: at 1px it sits on the circle's edge as before, and
    // every pixel above that is added outside it.
    property int ringWidth: 1

    width: root.size
    height: root.size

    Image {
        id: picture

        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        // Decoded at twice the drawn size so the masked circle keeps its
        // detail after the effect resamples it.
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        smooth: true
        mipmap: true
        visible: false
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: width / 2
        color: "black"
        antialiasing: true
        visible: false
        // Supersampled: the mask is drawn at 2x and downsampled, so the circle
        // edge arrives as a smooth alpha ramp.
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(width * 2, height * 2)
    }

    MultiEffect {
        anchors.fill: parent
        source: picture
        maskEnabled: true
        maskSource: mask
        // Without a spread the mask alpha is thresholded to a hard step and
        // the circle comes out jagged.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        saturation: -1  // greys only, the avatar included
        visible: picture.status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -(root.ringWidth - 1)
        radius: width / 2
        color: "transparent"
        antialiasing: true
        border.color: root.ringColor
        border.width: root.ringWidth

        Behavior on border.color {
            ColorAnimation { duration: Config.dur(Config.animFast) }
        }
    }
}
