import "../services"
import "../shared"
import "../shared" as Shared
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool editMode: false
    property bool editWorkspaceEntered: false
    property var editItems: []

    signal editSaved(string widgetsJson)

    function cloneItems(items) {
        return JSON.parse(JSON.stringify(items || []));
    }

    function beginEdit() {
        if (editMode)
            return "editing";

        editItems = cloneItems(Theme.widgetItems.filter((item) => {
            return item.enabled;
        }));
        editMode = true;
        editWorkspaceEntered = true;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"name:blox-widget-edit\" })"]);
        return "editing";
    }

    function cancelEdit() {
        editMode = false;
        editItems = [];
        leaveEditWorkspace();
        Theme.widgetEditModeFinished("");
        return "cancelled";
    }

    function leaveEditWorkspace() {
        if (!editWorkspaceEntered)
            return ;

        editWorkspaceEntered = false;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"previous\" })"]);
    }

    function saveEdit() {
        const editedById = {
        };
        editItems.forEach((item) => {
            return editedById[item.id] = item;
        });
        Theme.widgetItems = Theme.widgetItems.map((item) => {
            return editedById[item.id] || item;
        });
        const payload = JSON.stringify(Theme.widgetItems);
        editSaved(payload);
        Theme.widgetEditModeFinished(payload);
        editMode = false;
        editItems = [];
        leaveEditWorkspace();
        return payload;
    }

    function replaceEditItem(index, item) {
        const items = editItems.slice();
        items[index] = item;
        editItems = items;
    }

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
        function onWidgetEditModeRequested() {
            root.beginEdit();
        }

        target: Theme
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
            implicitWidth: modelData.anchor === "centre" ? 1 : widgetRenderer.width
            implicitHeight: modelData.anchor === "centre" ? 1 : widgetRenderer.height
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"
            visible: !root.editMode && (modelData.visibility !== "empty-workspace" || root.activeWorkspaceEmpty())
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

            Shared.DesktopWidget {
                id: widgetRenderer

                x: widgetWindow.modelData.anchor === "centre" ? Math.round((parent.width - width) / 2) + widgetWindow.modelData.offset_x : 0
                y: widgetWindow.modelData.anchor === "centre" ? Math.round((parent.height - height) / 2) + widgetWindow.modelData.offset_y : 0
                widget: widgetWindow.modelData
                scriptRoot: root.scriptRoot
                onLeftClicked: {
                    widgetAction.run(root.commandFor(widgetWindow.modelData.left_click_command));
                }
                onRightClicked: {
                    widgetAction.run(root.commandFor(widgetWindow.modelData.right_click_command));
                }
            }

            Process {
                id: widgetAction

                function run(action) {
                    if (action.length === 0) {
                        widgetRenderer.refresh();
                        return ;
                    }
                    if (running)
                        return ;

                    command = ["sh", "-c", action];
                    running = true;
                }

                onExited: widgetRenderer.refresh()
            }

        }

    }

    WidgetEditMode {
        active: root.editMode
        items: root.editItems
        onItemChanged: (index, item) => {
            return root.replaceEditItem(index, item);
        }
        onExitRequested: root.cancelEdit()
        onSaveRequested: root.saveEdit()
    }

    IpcHandler {
        function open() : string {
            return root.beginEdit();
        }

        function close() : string {
            return root.cancelEdit();
        }

        function save() : string {
            return root.saveEdit();
        }

        function status() : string {
            return JSON.stringify({
                "active": root.editMode,
                "items": root.editItems
            });
        }

        target: "widget-edit"
    }

}
