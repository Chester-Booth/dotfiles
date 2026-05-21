import "../shared"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool open: false
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property var items: []
    property string query: ""
    property string pendingCommand: ""
    property string selectedId: ""

    function toggle() {
        open = !open;
        if (open)
            refresh();

    }

    function close() {
        open = false;
        query = "";
    }

    function refresh() {
        listProcess.running = false;
        listProcess.command = [root.scriptRoot + "/clipboard/state.py", "list"];
        listProcess.running = true;
    }

    function filteredItems() {
        const needle = query.trim().toLowerCase();
        if (needle.length === 0)
            return items;

        return items.filter(function(item) {
            return ((item.text || "") + " " + (item.label || "") + " " + (item.mime || "")).toLowerCase().indexOf(needle) >= 0;
        });
    }

    function runClipboard(args, closeAfter) {
        pendingCommand = args.join("\0");
        commandProcess.running = false;
        commandProcess.command = [root.scriptRoot + "/clipboard/state.py"].concat(args);
        commandProcess.running = true;
        if (closeAfter)
            close();

    }

    Process {
        id: watcher

        command: [root.scriptRoot + "/clipboard/watch.sh"]
        running: true
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim() || "{\"items\":[]}");
                    root.items = data.items || [];
                } catch (error) {
                    root.items = [];
                }
            }
        }

    }

    Process {
        id: commandProcess

        onExited: root.refresh()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            property real panelX: Math.max(12, width - clipboardPanel.width - 18)
            property real panelY: 54

            function clampPanel() {
                panelX = Math.max(8, Math.min(width - clipboardPanel.width - 8, panelX));
                panelY = Math.max(8, Math.min(height - clipboardPanel.height - 8, panelY));
            }

            screen: modelData
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            visible: root.open
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: clipboardPanel

                width: Math.min(430, Math.max(360, window.width - 24))
                height: Math.min(620, Math.max(360, window.height - 90))
                x: window.panelX
                y: window.panelY
                radius: 8
                color: Theme.background
                border.color: Theme.surfaceAlt
                border.width: 1
                clip: true
                onWidthChanged: window.clampPanel()
                onHeightChanged: window.clampPanel()

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Rectangle {
                        id: header

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        color: "transparent"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            drag.target: clipboardPanel
                            drag.axis: Drag.XAndYAxis
                            drag.minimumX: 8
                            drag.maximumX: window.width - clipboardPanel.width - 8
                            drag.minimumY: 8
                            drag.maximumY: window.height - clipboardPanel.height - 8
                            onPressed: mouse.accepted = true
                            onReleased: {
                                window.panelX = clipboardPanel.x;
                                window.panelY = clipboardPanel.y;
                                window.clampPanel();
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                text: "󰅌"
                                color: Theme.blue
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: "Clipboard"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.items.length + " saved"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                            }

                            IconButton {
                                icon: "󰐊"
                                danger: true
                                onClicked: root.runClipboard(["clear"], false)
                            }

                            IconButton {
                                icon: "󰅖"
                                onClicked: root.close()
                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 7
                        color: Theme.surface
                        border.color: searchInput.activeFocus ? Theme.blue : Theme.surfaceAlt
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "󰍉"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }

                            TextInput {
                                id: searchInput

                                Layout.fillWidth: true
                                text: root.query
                                color: Theme.foreground
                                selectionColor: Theme.surfaceAlt
                                selectedTextColor: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                clip: true
                                onTextChanged: root.query = text
                                Component.onCompleted: forceActiveFocus()
                                Keys.onEscapePressed: root.close()
                            }

                        }

                    }

                    ListView {
                        id: itemList

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        clip: true
                        model: root.filteredItems()

                        Text {
                            anchors.centerIn: parent
                            visible: itemList.count === 0
                            text: root.query.length > 0 ? "No matches" : "Clipboard is empty"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        delegate: Rectangle {
                            required property var modelData

                            width: itemList.width
                            height: modelData.kind === "image" ? 118 : 92
                            radius: 8
                            color: itemMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                            border.color: modelData.pinned ? Theme.yellow : Theme.surfaceAlt
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 72
                                    Layout.preferredHeight: 72
                                    radius: 6
                                    color: Theme.background
                                    border.color: Theme.surfaceAlt
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        visible: modelData.kind === "image"
                                        source: modelData.url || ""
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.kind !== "image"
                                        text: "󰈙"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 24
                                    }

                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.kind === "image" ? (modelData.mime || "Image") : (modelData.label || "Text")
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: modelData.kind === "image" ? ((modelData.size || 0) + " bytes") : (modelData.text || "")
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        maximumLineCount: modelData.kind === "image" ? 1 : 3
                                    }

                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 30
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 6

                                    IconButton {
                                        icon: modelData.pinned ? "󰐃" : "󰤱"
                                        active: modelData.pinned
                                        onClicked: root.runClipboard(["pin", modelData.id], false)
                                    }

                                    IconButton {
                                        icon: "󰆴"
                                        danger: true
                                        onClicked: root.runClipboard(["delete", modelData.id], false)
                                    }

                                }

                            }

                            MouseArea {
                                id: itemMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: {
                                    if (mouse.button === Qt.RightButton)
                                        root.runClipboard(["select", modelData.id], false);
                                    else
                                        root.runClipboard(["select", modelData.id, "--paste"], true);
                                }
                            }

                        }

                    }

                }

            }

        }

    }

    component IconButton: Rectangle {
        property string icon: ""
        property bool danger: false
        property bool active: false

        signal clicked()

        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        radius: 6
        color: mouse.containsMouse || active ? Theme.surfaceAlt : Theme.surface
        border.color: danger ? Theme.red : (active ? Theme.yellow : Theme.surfaceAlt)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: icon
            color: danger ? Theme.red : (active ? Theme.yellow : Theme.foreground)
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }

    }

}
