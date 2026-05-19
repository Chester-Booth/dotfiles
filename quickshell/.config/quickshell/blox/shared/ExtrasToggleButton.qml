import "."

RailButton {
    id: root

    signal toggle()
    signal openRequested()

    icon: "󰅃"
    iconRotation: active ? 180 : 0
    accent: Theme.foreground
    onClicked: root.toggle()
    onHovered: root.openRequested()
}
