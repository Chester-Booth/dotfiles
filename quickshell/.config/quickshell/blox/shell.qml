import "./modules"
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool barOpen: true
    property bool clipboardOpen: false

    IpcHandler {
        function toggle() : string {
            root.barOpen = !root.barOpen;
            return root.barOpen ? "visible" : "hidden";
        }

        target: "bar"
    }

    IpcHandler {
        function toggle() : string {
            root.clipboardOpen = !root.clipboardOpen;
            return root.clipboardOpen ? "visible" : "hidden";
        }

        function close() : string {
            root.clipboardOpen = false;
            return "hidden";
        }

        target: "clipboard"
    }

    Bar {
        barOpen: root.barOpen
    }

    ClipboardManager {
        open: root.clipboardOpen
        onOpenChanged: root.clipboardOpen = open
    }

    EwwOverlays {
    }

}
