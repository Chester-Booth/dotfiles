import "."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string openPanel: ""
    property string scriptRoot: ""

    signal panelClicked(string panel, real centerY)
    signal panelHovered(string panel, real centerY, string source)
    signal panelExited(string source)
    signal runCommand(string command)

    width: Theme.buttonSize
    implicitHeight: content.implicitHeight
    Layout.alignment: Qt.AlignHCenter

    Column {
        id: content

        width: parent.width

        RailButton {
            icon: "⏻"
            accent: Theme.foreground
            active: root.openPanel === "power"
            onClicked: (centerY) => {
                return root.panelClicked("power", centerY);
            }
        }

        PanelRailButton {
            icon: "󰺦"
            accent: Theme.foreground
            panel: "todo"
            active: root.openPanel === "todo"
            onPanelClicked: (panel, centerY) => {
                return root.panelClicked(panel, centerY);
            }
            onPanelHovered: (panel, centerY, source) => {
                return root.panelHovered(panel, centerY, source);
            }
            onPanelExited: (source) => {
                return root.panelExited(source);
            }
            onRightClicked: root.runCommand(root.scriptRoot + "/todo/open.sh")
        }

    }

}
