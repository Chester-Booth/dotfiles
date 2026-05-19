import "."

RailButton {
    id: root

    property var status
    property real popupY: 0

    signal toggleExpanded()
    signal systemPanelRequested(real centerY)

    icon: status && status.icon ? status.icon : "󰁹"
    accent: status && status.class === "critical" ? Theme.red : status && status.class === "charging" ? Theme.green : Theme.muted
    active: false
    onClicked: root.toggleExpanded()
    onRightClicked: root.systemPanelRequested(popupY)
}
