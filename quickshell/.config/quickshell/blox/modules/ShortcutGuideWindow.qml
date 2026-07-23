import "../shared"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property bool guideOpen
    required property bool rendered
    property var captureSource: null
    property string captureTitle: ""
    readonly property real contentScale: Math.min(1.08, Math.min(width / 1840, height / 1000))

    signal closeRequested()

    visible: rendered
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "blox-shortcut-guide"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Theme.withAlpha(Theme.background, 0.9)
        opacity: root.guideOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.guideOpen ? 300 : 180
                easing.type: Easing.Linear
            }

        }

    }

    Item {
        anchors.fill: parent

        Item {
            id: content

            width: 1760
            height: 920
            anchors.centerIn: parent
            scale: root.contentScale
            transformOrigin: Item.Center
            opacity: root.guideOpen ? 1 : 0
            y: (parent.height - height) / 2 + (root.guideOpen ? 0 : 70)

            Column {
                id: leftColumn

                width: 600
                height: parent.height
                spacing: 24

                Rectangle {
                    id: previewFrame

                    width: parent.width
                    height: 358
                    radius: 12
                    color: Theme.surface
                    clip: true

                    ScreencopyView {
                        anchors.fill: parent
                        captureSource: root.captureSource
                        live: false
                        paintCursor: false
                    }

                }

                Row {
                    width: parent.width
                    spacing: 34

                    Column {
                        width: 324
                        spacing: 14

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Window controls"
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 29
                            font.weight: Font.Medium
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 16

                            Column {
                                spacing: 8

                                Item {
                                    width: 184
                                    height: 120

                                    KeyCap {
                                        x: 64
                                        y: 0
                                        label: "↑"
                                        capWidth: 56
                                        capHeight: 56
                                    }

                                    KeyCap {
                                        x: 0
                                        y: 64
                                        label: "←"
                                        capWidth: 56
                                        capHeight: 56
                                    }

                                    KeyCap {
                                        x: 64
                                        y: 64
                                        label: "↓"
                                        capWidth: 56
                                        capHeight: 56
                                    }

                                    KeyCap {
                                        x: 128
                                        y: 64
                                        label: "→"
                                        capWidth: 56
                                        capHeight: 56
                                    }

                                }

                                Text {
                                    width: 184
                                    text: "Focus direction"
                                    color: Theme.foreground
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 18
                                }

                            }

                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 9

                            KeyCap {
                                label: "Shift"
                                capHeight: 42
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+"
                                color: Theme.muted
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 18
                            }

                            KeyCap {
                                label: "arrow"
                                capHeight: 42
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "moves window"
                                color: Theme.foreground
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 17
                            }

                        }

                        MouseShortcutRow {
                            leftButton: true
                            action: "Move window"
                        }

                        MouseShortcutRow {
                            leftButton: false
                            action: "Resize window"
                        }

                    }

                    Column {
                        width: 242
                        spacing: 14

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Numpad"
                            color: Theme.foreground
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 29
                            font.weight: Font.Medium
                        }

                        Grid {
                            id: numpadGrid

                            columns: 3
                            spacing: 7

                            Repeater {
                                model: [{
                                    "key": "7",
                                    "action": "Float"
                                }, {
                                    "key": "8",
                                    "action": "Maximise"
                                }, {
                                    "key": "9",
                                    "action": "Full screen"
                                }, {
                                    "key": "4",
                                    "action": "Width +5%"
                                }, {
                                    "key": "5",
                                    "action": "Swap master"
                                }, {
                                    "key": "6",
                                    "action": "Width −5%"
                                }, {
                                    "key": "1",
                                    "action": "Width 70%"
                                }, {
                                    "key": "2",
                                    "action": "Width 50%"
                                }, {
                                    "key": "3",
                                    "action": "Width 30%"
                                }]

                                NumpadKey {
                                    required property var modelData

                                    width: 76
                                    height: 76
                                    keyLabel: modelData.key
                                    action: modelData.action
                                }

                            }

                        }

                        NumpadKey {
                            width: 242
                            height: 76
                            keyLabel: "0"
                            action: "Toggle pin"
                        }

                    }

                }

            }

            Row {
                x: 660
                width: 1100
                height: parent.height
                spacing: 56

                // Explicit mirror of the Super binds in hypr/conf.d/binds.lua.
                Column {
                    width: 500
                    spacing: 26

                    ShortcutGroup {
                        width: parent.width
                        heading: "Apps & shell"
                        shortcuts: [{
                            "keys": ["T"],
                            "action": "Terminal"
                        }, {
                            "keys": ["E"],
                            "action": "Files"
                        }, {
                            "keys": ["M"],
                            "action": "Micro"
                        }, {
                            "keys": ["Space"],
                            "action": "Launcher"
                        }, {
                            "keys": ["N"],
                            "action": "Notifications"
                        }, {
                            "keys": ["Shift", "O"],
                            "action": "Orca"
                        }]
                    }

                    ShortcutGroup {
                        width: parent.width
                        heading: "Session & shell"
                        shortcuts: [{
                            "keys": ["Q"],
                            "action": "Close window"
                        }, {
                            "keys": ["L"],
                            "action": "Lock"
                        }, {
                            "keys": ["\\"],
                            "action": "Toggle bar"
                        }, {
                            "keys": ["."],
                            "action": "Emoji picker"
                        }]
                    }

                }

                Column {
                    width: 544
                    spacing: 26

                    ShortcutGroup {
                        width: parent.width
                        heading: "Capture & tools"
                        shortcuts: [{
                            "keys": ["Shift", "S"],
                            "action": "Capture region"
                        }, {
                            "keys": ["Alt", "S"],
                            "action": "Capture frozen region"
                        }, {
                            "keys": ["Shift", "T"],
                            "action": "Copy text from region"
                        }, {
                            "keys": ["Shift", "C"],
                            "action": "Colour picker"
                        }, {
                            "keys": ["V"],
                            "action": "Clipboard history"
                        }]
                    }

                    ShortcutGroup {
                        width: parent.width
                        heading: "Workspaces"
                        shortcuts: [{
                            "keys": ["1–0"],
                            "action": "Switch to 1–10"
                        }, {
                            "keys": ["Shift", "1–0"],
                            "action": "Move window to 1–10"
                        }, {
                            "keys": ["F1–F12"],
                            "action": "Switch to 11–22"
                        }, {
                            "keys": ["Shift", "F1–F12"],
                            "action": "Move window to 11–22"
                        }, {
                            "keys": ["Tab"],
                            "action": "Next workspace"
                        }, {
                            "keys": ["Shift", "Tab"],
                            "action": "Previous workspace"
                        }, {
                            "keys": ["`"],
                            "action": "Magic workspace"
                        }, {
                            "keys": ["Shift", "`"],
                            "action": "Move to magic workspace"
                        }, {
                            "keys": ["↕"],
                            "action": "Cycle workspaces"
                        }]
                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.guideOpen ? 300 : 180
                    easing.type: root.guideOpen ? Easing.OutExpo : Easing.InCubic
                }

            }

            Behavior on y {
                NumberAnimation {
                    duration: root.guideOpen ? 300 : 180
                    easing.type: root.guideOpen ? Easing.OutExpo : Easing.InCubic
                }

            }

        }

    }

    mask: Region {
    }

    component KeyCap: Rectangle {
        id: keyCap

        required property string label
        property real capWidth: Math.max(54, capLabel.implicitWidth + 28)
        property real capHeight: 48

        implicitWidth: capWidth
        implicitHeight: capHeight
        radius: 9
        color: Theme.accent

        Text {
            id: capLabel

            anchors.centerIn: parent
            text: keyCap.label
            color: Theme.selectionForeground
            font.family: Theme.monoFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

    }

    component ShortcutRow: Row {
        id: shortcutRow

        required property var keys
        required property string action
        property real actionWidth: 280

        spacing: 10
        height: 52

        Row {
            id: keySequence

            spacing: 8

            Repeater {
                model: shortcutRow.keys

                Row {
                    required property int index
                    required property string modelData

                    spacing: 8

                    Text {
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 18
                    }

                    KeyCap {
                        label: modelData
                        capHeight: 38
                        capWidth: Math.max(46, label.length * 12 + 24)
                    }

                }

            }

        }

        Text {
            width: shortcutRow.actionWidth
            anchors.verticalCenter: keySequence.verticalCenter
            text: shortcutRow.action
            color: Theme.foreground
            font.family: Theme.bodyFontFamily
            font.pixelSize: 20
            wrapMode: Text.Wrap
        }

    }

    component ShortcutGroup: Column {
        id: shortcutGroup

        required property string heading
        required property var shortcuts
        property real actionWidth: 290

        spacing: 8

        Text {
            text: shortcutGroup.heading
            color: Theme.foreground
            font.family: Theme.bodyFontFamily
            font.pixelSize: 29
            font.weight: Font.Medium
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.foreground, 0.18)
        }

        Repeater {
            model: shortcutGroup.shortcuts

            ShortcutRow {
                required property var modelData

                keys: modelData.keys
                action: modelData.action
                actionWidth: shortcutGroup.actionWidth
            }

        }

    }

    component NumpadKey: Rectangle {
        id: numpadKey

        required property string keyLabel
        required property string action
        property int columnSpan: 1

        radius: 8
        color: Theme.accent

        Column {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: numpadKey.keyLabel
                color: Theme.selectionForeground
                font.family: Theme.monoFontFamily
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: numpadKey.action
                color: Theme.selectionForeground
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

        }

    }

    component MouseShortcutRow: Row {
        id: mouseShortcut

        required property bool leftButton
        required property string action

        spacing: 10
        height: 52

        Rectangle {
            width: 54
            height: 38
            radius: 9
            color: Theme.accent

            Item {
                width: 24
                height: 30
                anchors.centerIn: parent

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: "transparent"
                    border.color: Theme.selectionForeground
                    border.width: 2
                }

                Rectangle {
                    x: mouseShortcut.leftButton ? 3 : 13
                    y: 3
                    width: 8
                    height: 11
                    radius: 3
                    color: Theme.selectionForeground
                }

                Rectangle {
                    x: 11
                    y: 1
                    width: 2
                    height: 14
                    color: Theme.selectionForeground
                }

            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: mouseShortcut.action
            color: Theme.foreground
            font.family: Theme.bodyFontFamily
            font.pixelSize: 20
        }

    }

}
