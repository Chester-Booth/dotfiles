import "."

RailButton {
    id: root

    signal toggle()

    icon: "󰅃"
    accent: Theme.foreground
    active: false
    onClicked: root.toggle()
}
