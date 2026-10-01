import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property string iconName: ""
    property string trailingIconName: ""
    property bool accent: false
    property bool iconOnly: false
    leftPadding: iconOnly ? 0 : 12
    rightPadding: iconOnly ? 0 : 12
    topPadding: 0
    bottomPadding: 0
    implicitHeight: 34
    implicitWidth: content.implicitWidth + 24
    hoverEnabled: true
    background: Rectangle {
        radius: 8
        color: control.down ? "#585b70" : control.accent ? "#89b4fa" : control.hovered ? "#45475a" : "#313244"
        opacity: control.enabled ? 1 : 0.4
    }
    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        RowLayout {
            id: content
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            spacing: 7
            Icon { visible: control.iconName.length > 0; name: control.iconName; color: control.accent ? "#1e1e2e" : "#cdd6f4"; size: 14 }
            Text {
                Layout.fillWidth: true
                visible: control.text.length > 0
                text: control.text
                color: control.accent ? "#1e1e2e" : "#cdd6f4"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Icon { visible: control.trailingIconName.length > 0; name: control.trailingIconName; color: control.accent ? "#1e1e2e" : "#cdd6f4"; size: 14 }
        }
    }
}
