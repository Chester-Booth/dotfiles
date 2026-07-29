import QtQuick

Item {
    id: root

    required property BarPopoutGeometry geometry
    property string openPanel: ""
    property var systemStatus
    property var batteryStatus
    property string scriptRoot: ""
    property bool performanceActionBusy: false
    property string performanceActionError: ""
    property string performanceStatusError: ""
    property string systemTitle: ""
    property string systemBody: ""
    property string systemStatusError: ""
    property var systemActions: []
    property int audioVolume: 0
    property string audioIcon: "󰕾"
    property bool audioMuted: false
    property bool micMuted: false
    property bool networkEnabled: true
    property bool bluetoothEnabled: true
    property string wifiIcon: "󰤩"
    property string wifiText: "Wi-Fi"
    property string bluetoothIcon: "󰂯"
    property string brightnessIcon: "󰃠"
    property int brightnessPercent: 0
    property string blueLightMode: "auto"
    property bool blueLightActive: false
    property string activeMprisPlayer: ""

    signal hoverEntered()
    signal hoverExited()
    signal closePanel()
    signal performanceAction(string command)
    signal performanceVisibleChanged(bool visible)
    signal systemAction(string command, bool keepOpen)
    signal levelPreview(string kind, int value, bool muted)
    signal selectSystemPanel(string panel)
    signal selectMprisPlayer(string playerName)

    HoverPopupWindow {
        anchorWindow: root.geometry.panelWindow
        anchorX: Theme.barPosition === "top" || Theme.barPosition === "bottom" ? root.geometry.adjacentPopupX(mediaPlayer.implicitWidth, systemWindow.anchorX, systemPopout.width) : root.geometry.popupX(mediaPlayer.implicitWidth, root.geometry.openPanelX)
        anchorY: Theme.barPosition === "left" || Theme.barPosition === "right" ? Math.max(8, systemWindow.anchorY - mediaPlayer.implicitHeight - 8) : root.geometry.popupY(mediaPlayer.implicitHeight, root.geometry.openPanelY)
        contentWidth: 330
        contentHeight: mediaPlayer.implicitHeight
        open: root.openPanel === "audio" && mediaPlayer.hasPlayers
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()

        MediaPlayer {
            id: mediaPlayer

            width: 330
            activePlayerName: root.activeMprisPlayer
            onSelectPlayer: (playerName) => {
                return root.selectMprisPlayer(playerName);
            }
        }

    }

    HoverPopupWindow {
        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(performancePopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(performancePopout.height, root.geometry.openPanelY)
        contentWidth: performancePopout.width
        contentHeight: performancePopout.height
        open: root.openPanel === "system"
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: root.performanceVisibleChanged(visible)

        PerformancePopout {
            id: performancePopout

            status: root.systemStatus || ({
            })
            batteryStatus: root.batteryStatus || ({
            })
            scriptRoot: root.scriptRoot
            actionBusy: root.performanceActionBusy
            actionError: root.performanceActionError
            statusError: root.performanceStatusError
            onAction: (command) => {
                return root.performanceAction(command);
            }
        }

    }

    HoverPopupWindow {
        id: systemWindow

        anchorWindow: root.geometry.panelWindow
        anchorX: root.geometry.popupX(systemPopout.width, root.geometry.openPanelX)
        anchorY: root.geometry.popupY(systemPopout.height, root.geometry.openPanelY)
        contentWidth: systemPopout.width
        contentHeight: systemPopout.height
        open: ["audio", "network", "bluetooth", "brightness"].indexOf(root.openPanel) >= 0
        onHoverEntered: root.hoverEntered()
        onHoverExited: root.hoverExited()
        onVisibleChanged: {
            if (!visible && ["audio", "network", "bluetooth", "brightness"].indexOf(root.openPanel) >= 0)
                root.closePanel();

        }

        SystemPopout {
            id: systemPopout

            title: root.systemTitle
            body: root.systemBody
            statusError: root.systemStatusError
            actions: root.systemActions
            mode: root.openPanel
            audioVolume: root.audioVolume
            audioIcon: root.audioIcon
            audioMuted: root.audioMuted
            micMuted: root.micMuted
            networkEnabled: root.networkEnabled
            bluetoothEnabled: root.bluetoothEnabled
            wifiIcon: root.wifiIcon
            wifiText: root.wifiText
            bluetoothIcon: root.bluetoothIcon
            brightnessIcon: root.brightnessIcon
            brightnessPercent: root.brightnessPercent
            blueLightMode: root.blueLightMode
            blueLightActive: root.blueLightActive
            scriptRoot: root.scriptRoot
            onAction: (command, keepOpen) => {
                return root.systemAction(command, keepOpen);
            }
            onLevelPreview: (kind, value, muted) => {
                return root.levelPreview(kind, value, muted);
            }
            onSectionSelected: (panel) => {
                return root.selectSystemPanel(panel);
            }
        }

    }

}
