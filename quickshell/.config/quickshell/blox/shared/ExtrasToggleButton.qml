import "."

RailButton {
    id: root

    property bool horizontal: false

    signal toggle()
    signal openRequested()

    icon: horizontal ? "󰅂" : "󰅀"
    // The collapsed arrow points towards the concealed tray items (outwards
    // from the toggle). Once expanded it points back towards the toggle.
    iconRotation: active ? 0 : 180
    accent: Theme.foreground
    onClicked: root.toggle()
    onHovered: root.openRequested()
}
