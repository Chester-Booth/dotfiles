import "."
import "../shared"
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var targetScreen
    property bool open: false
    property string updateSummary: ""

    signal action(string kind)
    signal close()

    screen: targetScreen
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    aboveWindows: true
    visible: open
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    PowerOverlay {
        anchors.fill: parent
        updateSummary: root.updateSummary
        onAction: (kind) => root.action(kind)
        onClose: root.close()
    }
}
