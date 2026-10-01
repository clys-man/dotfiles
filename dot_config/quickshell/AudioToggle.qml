import QtQuick
import QtQuick.Layouts
import Quickshell

PanelAction {
    id: control
    property bool muted: false
    property bool microphone: false
    property string outputIcon: "volume"
    iconOnly: true
    implicitWidth: 36
    Layout.minimumWidth: 36
    Layout.preferredWidth: 36
    Layout.maximumWidth: 36
    Accessible.name: microphone ? "Microphone" : "Audio"
    contentItem: Item {
        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            sourceSize.width: 36
            sourceSize.height: 36
            source: Quickshell.shellPath("icons/" + (control.microphone ? "microphone" : control.outputIcon) + (control.muted ? "-muted" : "") + ".svg")
        }
    }
}
