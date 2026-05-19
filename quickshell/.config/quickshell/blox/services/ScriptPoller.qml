import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var command: []
    property int interval: 5000
    property string raw: ""
    property var json: ({
    })
    property bool ok: true
    property real lastUpdatedMs: 0

    function refresh() {
        if (command.length > 0 && !process.running)
            process.running = true;

    }

    Process {
        id: process

        command: root.command

        stdout: StdioCollector {
            onStreamFinished: {
                root.raw = this.text.trim();
                root.lastUpdatedMs = Date.now();
                try {
                    root.json = root.raw.length > 0 ? JSON.parse(root.raw) : {
                    };
                    root.ok = true;
                } catch (error) {
                    root.json = ({
                        "text": root.raw
                    });
                    root.ok = false;
                }
            }
        }

    }

    Timer {
        interval: root.interval
        running: root.command.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

}
