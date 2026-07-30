import QtQuick

QtObject {
    id: root

    property string mode: ""
    property string title: ""
    property string body: ""
    property string statusError: ""
    property var actions: []
    property string scriptRoot: ""
    property int audioVolume: 0
    property string audioIcon: "󰕾"
    property bool audioMuted: false
    property bool micMuted: false
    property bool networkEnabled: true
    property bool bluetoothEnabled: true
    property string wifiIcon: "󰤩"
    property string wifiText: "Wi-Fi"
    property string bluetoothIcon: "󰂯"
    property string brightnessIcon: "󰃠"
    property int brightnessPercent: 0
    property string blueLightMode: "auto"
    property bool blueLightActive: false
    property int visualAudioVolume: audioVolume
    property int visualBrightnessPercent: brightnessPercent
    property string visualBlueLightMode: blueLightMode
    property bool adjustingAudio: false
    property bool adjustingBrightness: false
    property bool audioApplyPending: false
    property bool brightnessApplyPending: false
    readonly property bool audioOverdriven: currentMode() === "audio" && !audioMuted && audioVolume > 100
    readonly property bool visualAudioOverdriven: currentMode() === "audio" && !audioMuted && visualAudioVolume > 100
    property Timer audioApplyDelay

    audioApplyDelay: Timer {
        interval: 50
        repeat: false
        onTriggered: {
            if (root.audioApplyPending) {
                root.applyAudio();
                restart();
            }
        }
    }

    property Timer brightnessApplyDelay

    brightnessApplyDelay: Timer {
        interval: 50
        repeat: false
        onTriggered: {
            if (root.brightnessApplyPending) {
                root.applyBrightness();
                restart();
            }
        }
    }

    property Timer audioSyncDelay

    audioSyncDelay: Timer {
        interval: 250
        repeat: false
        onTriggered: root.visualAudioVolume = root.audioVolume
    }

    property Timer brightnessSyncDelay

    brightnessSyncDelay: Timer {
        interval: 250
        repeat: false
        onTriggered: root.visualBrightnessPercent = root.brightnessPercent
    }

    signal actionRequested(string command, bool keepOpen)
    signal levelPreviewRequested(string kind, int value, bool muted)

    function currentMode() {
        return mode === "mic" ? "bluetooth" : mode;
    }

    function actionByLabel(text) {
        const lower = text.toLowerCase();
        for (let i = 0; i < actions.length; i++) {
            const label = String(actions[i].label || "").toLowerCase();
            if (label.indexOf(lower) >= 0)
                return actions[i];

        }
        return null;
    }

    function runLabel(text, keepOpen) {
        const item = actionByLabel(text);
        if (item)
            actionRequested(item.command || "", keepOpen);

    }

    function heroIcon() {
        if (currentMode() === "audio")
            return audioIcon;

        if (currentMode() === "network")
            return wifiIcon;

        if (currentMode() === "bluetooth")
            return bluetoothIcon;

        if (currentMode() === "brightness")
            return brightnessIcon;

        return "󰁹";
    }

    function subtitle() {
        if (currentMode() === "network")
            return wifiText;

        if (currentMode() === "audio")
            return audioMuted ? "Muted" : visualAudioVolume + "%";

        if (currentMode() === "brightness")
            return visualBrightnessPercent + "% • " + (blueLightActive ? "Active" : "Inactive");

        if (currentMode() === "bluetooth")
            return body.split("\n").join(" ");

        return body.split("\n")[0];
    }

    function runCommand(command, keepOpen) {
        actionRequested(command, keepOpen);
    }

    function applyAudio() {
        audioApplyPending = false;
        runCommand(scriptRoot + "/control.sh audio-set-silent " + visualAudioVolume, true);
    }

    function queueAudio(value) {
        visualAudioVolume = value;
        levelPreviewRequested("volume", value, audioMuted);
        audioApplyPending = true;
        audioSyncDelay.stop();
        if (!audioApplyDelay.running) {
            applyAudio();
            audioApplyDelay.restart();
        }
    }

    function finishAudio() {
        adjustingAudio = false;
        audioApplyDelay.stop();
        if (audioApplyPending)
            applyAudio();

        audioSyncDelay.restart();
    }

    function applyBrightness() {
        brightnessApplyPending = false;
        runCommand(scriptRoot + "/control.sh brightness-set-silent " + visualBrightnessPercent, true);
    }

    function queueBrightness(value) {
        visualBrightnessPercent = value;
        levelPreviewRequested("brightness", value, false);
        brightnessApplyPending = true;
        brightnessSyncDelay.stop();
        if (!brightnessApplyDelay.running) {
            applyBrightness();
            brightnessApplyDelay.restart();
        }
    }

    function finishBrightness() {
        adjustingBrightness = false;
        brightnessApplyDelay.stop();
        if (brightnessApplyPending)
            applyBrightness();

        brightnessSyncDelay.restart();
    }

    onAudioVolumeChanged: {
        if (!adjustingAudio && !audioSyncDelay.running)
            visualAudioVolume = audioVolume;

    }
    onBrightnessPercentChanged: {
        if (!adjustingBrightness && !brightnessSyncDelay.running)
            visualBrightnessPercent = brightnessPercent;

    }
    onBlueLightModeChanged: visualBlueLightMode = blueLightMode
}
