import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property bool grouped: false
    property string iconName: ""
    property string text: ""
    property string tooltip: ""
    property color foreground: "#cdd6f4"
    property color background: grouped ? "transparent" : "#313244"
    signal clicked(int button)
    signal scrolled(bool up)
    implicitWidth: content.implicitWidth + 20
    implicitHeight: 32
    radius: grouped ? 8 : 12
    color: mouse.containsMouse ? (grouped ? "#45475a" : Qt.lighter(background, 1.2)) : background
    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 7
        Icon { visible: root.iconName.length > 0; name: root.iconName; color: root.foreground; Layout.alignment: Qt.AlignVCenter }
        Text {
            visible: root.text.length > 0
            text: root.text
            color: root.foreground
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 14
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => root.clicked(event.button)
        onWheel: event => { root.scrolled(event.angleDelta.y > 0); event.accepted = true; }
    }
}
