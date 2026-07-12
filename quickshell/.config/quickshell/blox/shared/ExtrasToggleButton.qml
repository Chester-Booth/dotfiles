import "."

RailButton {
    id: root

    property bool horizontal: false

    signal toggle()
    signal openRequested()

    icon: horizontal ? "󰅂" : "󰅀"
    iconRotation: active ? 180 : 0
    accent: Theme.foreground
    onClicked: root.toggle()
    onHovered: root.openRequested()
}
