import QtQuick
import QtQuick.Controls

Switch {
    id: control
    implicitWidth: 44
    implicitHeight: 28
    padding: 0
    indicator: Rectangle {
        width: 44
        height: 24
        y: (control.height - height) / 2
        radius: 12
        color: control.checked ? "#89b4fa" : "#45475a"
        opacity: control.enabled ? 1 : 0.4
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            y: 3
            width: 18
            height: 18
            radius: 9
            color: control.checked ? "#1e1e2e" : "#cdd6f4"
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }
    contentItem: Item {}
}
