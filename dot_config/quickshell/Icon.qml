import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: icon
    property string name: ""
    property color color: "#cdd6f4"
    property int size: 14
    implicitWidth: size
    implicitHeight: size
    Image {
        anchors.fill: parent
        source: icon.name.length ? Quickshell.shellPath("icons/" + icon.name + ".svg") : ""
        sourceSize.width: icon.size * 2
        sourceSize.height: icon.size * 2
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1; colorizationColor: icon.color }
    }
}
