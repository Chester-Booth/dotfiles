import "../services"
import QtQuick
import Quickshell

Rectangle {
    id: root

    required property var widget
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool interactive: true
    property int overrideWidth: 0
    property int overrideHeight: 0
    readonly property bool terminalPreset: ["music", "clock", "aquarium", "pipes", "tree", "matrix", "train"].indexOf(widget.type) >= 0
    readonly property bool autoSize: widget.options && widget.options.auto_size === true
    readonly property int configuredWidth: overrideWidth > 0 ? overrideWidth : autoSize ? 0 : Number(widget.width || 0)
    readonly property int configuredHeight: overrideHeight > 0 ? overrideHeight : autoSize ? 0 : Number(widget.height || 0)

    signal leftClicked()
    signal rightClicked()

    function expandedCommand(command) {
        return String(command || "").replace(/\$SCRIPT_ROOT/g, root.scriptRoot);
    }

    function contentCommand() {
        if (!root.terminalPreset)
            return ["sh", "-c", root.expandedCommand(root.widget.content_command)];

        const columns = root.configuredWidth > 0 ? Math.max(10, Math.floor(root.configuredWidth / Math.max(6, Theme.widgetFontSize * 0.6))) : 60;
        const rows = root.configuredHeight > 0 ? Math.max(4, Math.floor(root.configuredHeight / Math.max(10, Theme.widgetFontSize * 1.25))) : 20;
        return [root.scriptRoot + "/overlays/terminal-frame.py", root.widget.type, "--command", root.expandedCommand(root.widget.content_command), "--columns", String(columns), "--rows", String(rows)];
    }

    function refresh() {
        contentPoller.refresh();
    }

    width: configuredWidth > 0 ? configuredWidth : content.implicitWidth + Theme.widgetPadding * 2
    height: configuredHeight > 0 ? configuredHeight : content.implicitHeight + Theme.widgetPadding * 2
    color: Theme.withAlpha(Theme.background, Theme.widgetOpacity)
    radius: widget.shape === "circle" ? Math.min(width, height) / 2 : widget.shape === "rounded" ? Math.max(10, Theme.widgetRadius) : widget.shape === "rectangle" ? 0 : Theme.widgetRadius

    ScriptPoller {
        id: contentPoller

        command: root.contentCommand()
        interval: Math.max(250, Number(root.widget.interval_ms || 60000))
    }

    Text {
        id: content

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.widgetPadding
        text: contentPoller.raw.length > 0 ? contentPoller.raw : "Loading..."
        color: Theme.foreground
        font.family: root.terminalPreset ? Theme.monoFontFamily : Theme.bodyFontFamily
        font.pixelSize: Theme.widgetFontSize
        wrapMode: Text.NoWrap
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignTop
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (event) => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.leftClicked();
        }
    }

}
