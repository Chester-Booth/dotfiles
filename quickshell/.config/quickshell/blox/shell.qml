import "./modules"
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool barOpen: true

    IpcHandler {
        function toggle() : string {
            root.barOpen = !root.barOpen;
            return root.barOpen ? "visible" : "hidden";
        }

        target: "bar"
    }

    Bar {
        barOpen: root.barOpen
        onOsdLevelPreview: (kind, value, muted) => {
            return osd.preview(kind, value, muted);
        }
    }

    Osd {
        id: osd
    }

    DesktopWidgets {
    }

    ThemePicker {
    }

    ShortcutGuide {
    }

}
