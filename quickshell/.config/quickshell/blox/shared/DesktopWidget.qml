import "../services"
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    required property var widget
    property string scriptRoot: Quickshell.shellDir + "/scripts"
    property bool interactive: true
    property int overrideWidth: 0
    property int overrideHeight: 0
    property string terminalFrame: ""
    readonly property bool terminalPreset: ["music", "clock", "aquarium", "pipes", "tree", "matrix", "train"].indexOf(widget.type) >= 0
    readonly property bool autoSize: widget.options && widget.options.auto_size === true
    readonly property real widgetScale: Math.max(0.25, Math.min(4, Number(widget.options && widget.options.scale || 1)))
    readonly property real scaledPadding: Theme.widgetPadding * widgetScale
    readonly property int configuredWidth: autoSize ? 0 : Number(widget.width || 0)
    readonly property int configuredHeight: autoSize ? 0 : Number(widget.height || 0)

    signal leftClicked()
    signal rightClicked()

    function expandedCommand(command) {
        return String(command || "").replace(/\$SCRIPT_ROOT/g, root.scriptRoot);
    }

    function contentCommand() {
        if (!root.terminalPreset)
            return ["sh", "-c", root.expandedCommand(root.widget.content_command)];

        const logicalWidth = root.overrideWidth > 0 ? root.overrideWidth / root.widgetScale : root.configuredWidth;
        const logicalHeight = root.overrideHeight > 0 ? root.overrideHeight / root.widgetScale : root.configuredHeight;
        const columns = logicalWidth > 0 ? Math.max(10, Math.floor(logicalWidth / Math.max(6, Theme.widgetFontSize * 0.6))) : 60;
        const rows = logicalHeight > 0 ? Math.max(4, Math.floor(logicalHeight / Math.max(10, Theme.widgetFontSize * 1.25))) : 20;
        return [root.scriptRoot + "/overlays/terminal-frame.py", root.widget.type, "--stream", "--frame-ms", "100", "--command", root.expandedCommand(root.widget.content_command), "--columns", String(columns), "--rows", String(rows)];
    }

    function refresh() {
        if (root.terminalPreset) {
            if (terminalProcess.running)
                terminalProcess.signal(15);
            else
                terminalProcess.running = true;
        } else {
            contentPoller.refresh();
        }
    }

    width: overrideWidth > 0 ? overrideWidth : configuredWidth > 0 ? configuredWidth * widgetScale : content.implicitWidth + scaledPadding * 2
    height: overrideHeight > 0 ? overrideHeight : configuredHeight > 0 ? configuredHeight * widgetScale : content.implicitHeight + scaledPadding * 2
    color: widget.type === "aquarium" ? "#000000" : Theme.withAlpha(Theme.background, Theme.widgetOpacity)
    radius: widget.shape === "circle" ? Math.min(width, height) / 2 : widget.shape === "rounded" ? Math.max(10, Theme.widgetRadius) : widget.shape === "rectangle" ? 0 : Theme.widgetRadius

    ScriptPoller {
        id: contentPoller

        command: root.terminalPreset ? [] : root.contentCommand()
        interval: Math.max(250, Number(root.widget.interval_ms || 60000))
    }

    Process {
        // Ignore incomplete output; the next complete frame replaces it.

        id: terminalProcess

        command: root.contentCommand()
        running: root.terminalPreset
        onExited: terminalRestart.restart()
        Component.onDestruction: {
            terminalRestart.stop();
            if (running)
                signal(15);

        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                try {
                    root.terminalFrame = JSON.parse(data);
                } catch (error) {
                }
            }
        }

    }

    Timer {
        id: terminalRestart

        interval: 500
        repeat: false
        onTriggered: {
            if (root.terminalPreset && !terminalProcess.running)
                terminalProcess.running = true;

        }
    }

    Text {
        id: content

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: root.scaledPadding
        text: root.terminalPreset ? (root.terminalFrame.length > 0 ? root.terminalFrame : "Loading…") : (contentPoller.raw.length > 0 ? contentPoller.raw : "Loading…")
        textFormat: root.terminalPreset ? Text.RichText : Text.PlainText
        color: Theme.foreground
        font.family: root.terminalPreset ? Theme.monoFontFamily : Theme.bodyFontFamily
        font.pixelSize: Theme.widgetFontSize * root.widgetScale
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
