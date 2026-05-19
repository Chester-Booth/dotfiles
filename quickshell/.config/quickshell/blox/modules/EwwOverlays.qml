import "../services"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string scriptRoot: Quickshell.shellDir + "/scripts"

    function run(command) {
        if (command.length === 0)
            return ;

        action.running = false;
        action.command = ["sh", "-c", command];
        action.running = true;
    }

    function activeWorkspaceEmpty() {
        return workspaceState.json.empty === true;
    }

    function refreshOverlays() {
        todoContent.refresh();
        gcalContent.refresh();
    }

    Component.onCompleted: {
        generatedRefresh.running = true;
    }

    ScriptPoller {
        id: workspaceState

        command: [root.scriptRoot + "/overlays/workspace-empty.sh"]
        interval: 300000
    }

    ScriptPoller {
        id: todoContent

        command: [root.scriptRoot + "/overlays/todo-content.sh"]
        interval: 60000
    }

    ScriptPoller {
        id: gcalContent

        command: [root.scriptRoot + "/overlays/gcal-content.sh"]
        interval: 60000
    }

    Process {
        id: action

        onExited: root.refreshOverlays()
    }

    Process {
        id: generatedRefresh

        command: [root.scriptRoot + "/todo/generated-refresh.sh"]
        onExited: root.refreshOverlays()
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2" || event.name === "openwindow" || event.name === "closewindow") {
                workspaceState.refresh();
                root.refreshOverlays();
            }
        }

        target: Hyprland
    }

    Variants {
        model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

        PanelWindow {
            id: todoWindow

            required property var modelData

            screen: modelData
            implicitWidth: todoBox.width
            implicitHeight: todoBox.height
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"
            visible: root.activeWorkspaceEmpty()
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "todo-overlay"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                left: true
                top: true
            }

            margins {
                left: 20
                top: 20
            }

            OverlayBox {
                id: todoBox

                text: todoContent.raw.length > 0 ? todoContent.raw : "Loading..."
                onLeftClicked: root.run(root.scriptRoot + "/overlays/cycle-todo.sh")
                onRightClicked: root.run(root.scriptRoot + "/overlays/open-todo-editor.sh")
            }

        }

    }

    Variants {
        model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

        PanelWindow {
            id: gcalWindow

            required property var modelData

            screen: modelData
            implicitWidth: gcalBox.width
            implicitHeight: gcalBox.height
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"
            visible: root.activeWorkspaceEmpty()
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "gcal-overlay"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                right: true
                bottom: true
            }

            margins {
                right: 20
                bottom: 20
            }

            OverlayBox {
                id: gcalBox

                text: gcalContent.raw.length > 0 ? gcalContent.raw : "Loading..."
                onLeftClicked: root.run(root.scriptRoot + "/overlays/cycle-gcal.sh")
                onRightClicked: root.run(root.scriptRoot + "/overlays/open-gcal.sh")
            }

        }

    }

    component OverlayBox: Rectangle {
        id: box

        property string text: ""

        signal leftClicked()
        signal rightClicked()

        width: content.implicitWidth + 40
        height: content.implicitHeight + 40
        color: "#4d000000"
        radius: 0

        Text {
            id: content

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 20
            text: box.text
            color: "#ffffff"
            font.family: "Google Sans Code NF"
            font.pixelSize: 14
            wrapMode: Text.NoWrap
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignTop
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (event) => {
                if (event.button === Qt.RightButton)
                    box.rightClicked();
                else
                    box.leftClicked();
            }
        }

    }

}
