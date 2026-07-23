import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property FontLoader
    font: FontLoader {
        source: "../assets/fonts/lucide.ttf"
    }

    readonly property string family: font.status === FontLoader.Ready ? font.name : "sans-serif"
    readonly property var codepoints: ({
        "app-window": 58406,
        "battery": 57427,
        "bell": 57433,
        "bluetooth": 57436,
        "clock": 57479,
        "coffee": 57494,
        "chevron-down": 57453,
        "chevron-up": 57456,
        "download": 57522,
        "ellipsis": 57526,
        "fan": 58233,
        "grip-vertical": 57579,
        "grid-2x2": 58623,
        "gpu": 58906,
        "notebook-tabs": 58775,
        "panels-top-left": 57644,
        "plus": 57661,
        "power": 57664,
        "refresh-cw": 57669,
        "rotate-ccw": 57672,
        "save": 57677,
        "shield": 57688,
        "sun": 57720,
        "upload": 57758,
        "volume-2": 57771,
        "wifi": 57774,
        "x": 57778
    })

    function icon(name) {
        const codepoint = codepoints[name];
        return codepoint === undefined ? "" : String.fromCodePoint(codepoint);
    }

}
