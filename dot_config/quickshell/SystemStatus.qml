import QtQuick
import QtQuick.Layouts

Rectangle {
    id: system
    required property var status
    signal clicked()
    implicitWidth: metrics.implicitWidth + 20
    implicitHeight: 32
    radius: 12
    color: mouse.containsMouse ? "#45475a" : "#313244"
    RowLayout {
        id: metrics
        anchors.centerIn: parent
        spacing: 14
        Repeater {
            model: ["cpu", "memory", "storage"]
            RowLayout {
                required property string modelData
                spacing: 7
                Icon { name: modelData; Layout.alignment: Qt.AlignVCenter }
                Text {
                    text: system.status[modelData] !== undefined && system.status[modelData] !== null ? system.status[modelData] + "%" : "—"
                    color: "#cdd6f4"
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: 14
                }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: system.clicked()
    }

}
