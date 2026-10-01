import QtQuick
import QtQuick.Controls

Slider {
    id: control
    from: 0
    to: 100
    stepSize: 1
    implicitHeight: 28
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 5
        radius: 3
        color: "#45475a"
        Rectangle { width: control.visualPosition * parent.width; height: parent.height; radius: 3; color: "#89b4fa" }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 15
        height: 15
        radius: 8
        color: control.pressed ? "#f5c2e7" : "#cdd6f4"
    }
}
