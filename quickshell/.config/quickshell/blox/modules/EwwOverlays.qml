import "../services"
import "../shared"
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

        Quickshell.execDetached(["sh", "-c", command]);
    }

    function commandFor(command) {
        return String(command || "").replace(/\$SCRIPT_ROOT/g, root.scriptRoot);
    }

    function activeWorkspaceEmpty() {
        return workspaceState.json.empty === true;
    }

    ScriptPoller {
        id: workspaceState

        command: [root.scriptRoot + "/overlays/workspace-empty.sh"]
        interval: 300000
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2" || event.name === "openwindow" || event.name === "closewindow")
                workspaceState.refresh();

        }

        target: Hyprland
    }

    Variants {
        model: Theme.widgetItems.filter((item) => {
            return item.enabled;
        })

        PanelWindow {
            id: widgetWindow

            required property var modelData
            readonly property bool atLeft: modelData.anchor === "top-left" || modelData.anchor === "bottom-left"
            readonly property bool atRight: modelData.anchor === "top-right" || modelData.anchor === "bottom-right"
            readonly property bool atTop: modelData.anchor === "top-left" || modelData.anchor === "top-right"
            readonly property bool atBottom: modelData.anchor === "bottom-left" || modelData.anchor === "bottom-right"

            screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
            implicitWidth: modelData.anchor === "centre" ? 1 : widgetBox.width
            implicitHeight: modelData.anchor === "centre" ? 1 : widgetBox.height
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"
            visible: modelData.visibility !== "empty-workspace" || root.activeWorkspaceEmpty()
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "blox-widget-" + modelData.id
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                left: widgetWindow.atLeft || modelData.anchor === "centre"
                right: widgetWindow.atRight || modelData.anchor === "centre"
                top: widgetWindow.atTop || modelData.anchor === "centre"
                bottom: widgetWindow.atBottom || modelData.anchor === "centre"
            }

            margins {
                left: widgetWindow.atLeft ? modelData.offset_x : 0
                right: widgetWindow.atRight ? modelData.offset_x : 0
                top: widgetWindow.atTop ? modelData.offset_y : 0
                bottom: widgetWindow.atBottom ? modelData.offset_y : 0
            }

            ScriptPoller {
                id: widgetContent

                command: ["sh", "-c", root.commandFor(widgetWindow.modelData.content_command)]
                interval: widgetWindow.modelData.interval_ms
            }

            OverlayBox {
                id: widgetBox

                x: widgetWindow.modelData.anchor === "centre" ? Math.round((parent.width - width) / 2) + widgetWindow.modelData.offset_x : 0
                y: widgetWindow.modelData.anchor === "centre" ? Math.round((parent.height - height) / 2) + widgetWindow.modelData.offset_y : 0
                text: widgetContent.raw.length > 0 ? widgetContent.raw : "Loading..."
                desiredWidth: widgetWindow.modelData.width
                desiredHeight: widgetWindow.modelData.height
                shape: widgetWindow.modelData.shape
                onLeftClicked: {
                    root.run(root.commandFor(widgetWindow.modelData.left_click_command));
                    widgetContent.refresh();
                }
                onRightClicked: {
                    root.run(root.commandFor(widgetWindow.modelData.right_click_command));
                    widgetContent.refresh();
                }
            }

        }

    }

    component OverlayBox: Rectangle {
        id: box

        property string text: ""
        property int desiredWidth: 0
        property int desiredHeight: 0
        property string shape: "auto"

        signal leftClicked()
        signal rightClicked()

        width: desiredWidth > 0 ? desiredWidth : content.implicitWidth + Theme.widgetPadding * 2
        height: desiredHeight > 0 ? desiredHeight : content.implicitHeight + Theme.widgetPadding * 2
        color: Theme.withAlpha(Theme.background, Theme.widgetOpacity)
        radius: shape === "circle" ? Math.min(width, height) / 2 : shape === "rounded" ? Math.max(10, Theme.widgetRadius) : shape === "rectangle" ? 0 : Theme.widgetRadius

        Text {
            id: content

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.widgetPadding
            text: box.text
            color: Theme.foreground
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.widgetFontSize
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
