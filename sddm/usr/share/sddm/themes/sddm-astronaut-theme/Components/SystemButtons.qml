// Config created by Keyitdev https://github.com/Keyitdev/sddm-astronaut-theme
// Copyright (C) 2022-2025 Keyitdev
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

RowLayout {
    id: buttonRow

    spacing: root.font.pointSize * 1.6

    property var shutdown: ({
        "action": "shutdown",
        "icon": "⏻",
        "label": config.TranslateShutdown || "Shut down",
        "available": sddm.canPowerOff,
        "danger": true
    })
    property var reboot: ({
        "action": "reboot",
        "icon": "󰜉",
        "label": config.TranslateReboot || "Reboot",
        "available": sddm.canReboot,
        "danger": true
    })
    property var suspend: ({
        "action": "suspend",
        "icon": "󰒲",
        "label": config.TranslateSuspend || "Sleep",
        "available": sddm.canSuspend,
        "danger": false
    })
    property var hibernate: ({
        "action": "hibernate",
        "icon": "󰤄",
        "label": config.TranslateHibernate || "Hibernate",
        "available": sddm.canHibernate,
        "danger": false
    })

    property ComboBox exposedSession
    readonly property string iconFont: "MartianMono Nerd Font Propo"

    Repeater {
        id: systemButtonRepeater
        
        model: [shutdown, reboot, suspend, hibernate]

        RoundButton {
            id: systemButton

            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.topMargin: root.font.pointSize * 6.5

            implicitWidth: Math.max(root.font.pointSize * 8.6, buttonLabel.implicitWidth + root.font.pointSize * 2.6)
            implicitHeight: root.font.pointSize * 5.8
            Layout.preferredWidth: implicitWidth
            Layout.minimumWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            text: modelData.label
            palette.buttonText: config.SessionButtonTextColor
            display: AbstractButton.TextOnly
            visible: config.HideSystemButtons != "true" && (config.BypassSystemButtonsChecks == "true" ? 1 : modelData.available)
            hoverEnabled: true
            
            background: Rectangle {
                anchors.fill: parent
                radius: 8
                color: "transparent"
            }

            contentItem: Item {
                Column {
                    id: buttonContent

                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        id: iconGlyph

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        color: systemButton.palette.buttonText
                        font.family: buttonRow.iconFont
                        font.pixelSize: 30
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        id: buttonLabel

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: systemButton.palette.buttonText
                        font.family: root.font.family
                        font.pointSize: root.font.pointSize * 0.8
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Keys.onReturnPressed: clicked()
            onClicked: {
                parent.forceActiveFocus()
                modelData.action == "shutdown" ? sddm.powerOff() : modelData.action == "reboot" ? sddm.reboot() : modelData.action == "suspend" ? sddm.suspend() : sddm.hibernate()
            }
            KeyNavigation.left: index > 0 ? parent.children[index-1] : null
            
            states: [
                State {
                    name: "pressed"
                    when: parent.children[index].down
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: Qt.darker(config.HoverSessionButtonTextColor, 1.1)
                    }
                },
                State {
                    name: "hovered"
                    when: parent.children[index].hovered
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: Qt.lighter(config.HoverSessionButtonTextColor, 1.1)
                    }
                },
                State {
                    name: "focused"
                    when: parent.children[index].activeFocus
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: config.HoverSessionButtonTextColor
                    }
                }
            ]
            transitions: [
                Transition {
                    PropertyAnimation {
                        properties: "palette.buttonText, border.color"
                        duration: 150
                    }
                }
            ]

        }

    }

}
