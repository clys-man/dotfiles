import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: audio
    required property var app
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property var availableOutputs: []
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio && availableOutputs.indexOf(n.name) >= 0)
    Process {
        id: availability
        command: ["python3", Quickshell.shellPath("audio_availability.py")]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try { audio.availableOutputs = JSON.parse(data); }
                catch (error) { audio.availableOutputs = []; }
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: { if (!availability.running) availability.running = true; } }
    property string outputError: ""
    Process {
        id: changeOutput
        property string targetName: ""
        command: ["python3", Quickshell.shellPath("audio-output.py"), targetName]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) audio.outputError = "Could not switch audio output.";
        }
    }
    spacing: 12
    PwObjectTracker { objects: [audio.sink, audio.source].concat(audio.outputs).filter(n => !!n) }
    PanelLabel { text: "Audio output"; color: "#a6adc8" }
    RowLayout {
        Layout.fillWidth: true
        PanelSlider { Layout.fillWidth: true; enabled: !!audio.sink && !!audio.sink.audio; value: audio.sink && audio.sink.audio ? audio.sink.audio.volume * 100 : 0; onMoved: audio.sink.audio.volume = value / 100 }
        PanelLabel { Layout.minimumWidth: 42; Layout.preferredWidth: 42; Layout.maximumWidth: 42; horizontalAlignment: Text.AlignRight; text: audio.sink && audio.sink.audio ? Math.round(audio.sink.audio.volume * 100) + "%" : "—" }
        AudioToggle { Layout.leftMargin: 6; outputIcon: audio.app.audioOutputIcon; muted: !!audio.sink && !!audio.sink.audio && audio.sink.audio.muted; enabled: !!audio.sink && !!audio.sink.audio; onClicked: audio.sink.audio.muted = !audio.sink.audio.muted }
    }
    Repeater {
        model: audio.outputs
        PanelAction {
            required property var modelData
            Layout.fillWidth: true
            iconName: audio.sink === modelData ? "check" : ""
            text: modelData.description
            accent: audio.sink === modelData
            enabled: !changeOutput.running
            onClicked: {
                audio.outputError = "";
                changeOutput.targetName = modelData.name;
                changeOutput.running = true;
            }
        }
    }
    PanelLabel { visible: audio.outputError.length > 0; Layout.fillWidth: true; text: audio.outputError; color: "#f38ba8" }
    Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }
    PanelLabel { text: "Microphone"; color: "#a6adc8" }
    RowLayout {
        Layout.fillWidth: true
        PanelSlider { Layout.fillWidth: true; enabled: !!audio.source && !!audio.source.audio; value: audio.source && audio.source.audio ? audio.source.audio.volume * 100 : 0; onMoved: audio.source.audio.volume = value / 100 }
        PanelLabel { Layout.minimumWidth: 42; Layout.preferredWidth: 42; Layout.maximumWidth: 42; horizontalAlignment: Text.AlignRight; text: audio.source && audio.source.audio ? Math.round(audio.source.audio.volume * 100) + "%" : "—" }
        AudioToggle { Layout.leftMargin: 6; microphone: true; muted: !!audio.source && !!audio.source.audio && audio.source.audio.muted; enabled: !!audio.source && !!audio.source.audio; onClicked: audio.source.audio.muted = !audio.source.audio.muted }
    }
}
