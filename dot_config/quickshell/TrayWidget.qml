import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

ColumnLayout {
    id: tray
    required property var app
    property var selected: null
    property var menuPath: []
    property var selectedMenu: menuPath.length ? menuPath[menuPath.length - 1] : selected ? selected.menu : null
    spacing: 8
    QsMenuOpener { id: menu; menu: tray.selectedMenu }
    PanelLabel { visible: SystemTray.items.values.length === 0; Layout.fillWidth: true; color: "#9399b2"; text: "No applications in the tray." }
    Repeater {
        model: tray.selected ? [] : SystemTray.items.values
        Rectangle {
            id: row
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 10
            color: hover.containsMouse ? "#45475a" : "#313244"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                Image { source: row.modelData.icon; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                PanelLabel { Layout.fillWidth: true; text: row.modelData.title || row.modelData.id; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                Icon { name: row.modelData.hasMenu ? "chevron-right" : "external"; color: "#9399b2" }
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: event => {
                    if (event.button === Qt.MiddleButton) row.modelData.secondaryActivate();
                    else if (row.modelData.hasMenu) tray.selected = row.modelData;
                    else { row.modelData.activate(); tray.app.closePopup(); }
                }
            }
        }
    }
    RowLayout {
        visible: !!tray.selected
        Layout.fillWidth: true
        PanelAction { iconName: "chevron-left"; text: "Back"; onClicked: { if (tray.menuPath.length) tray.menuPath = tray.menuPath.slice(0, -1); else tray.selected = null; } }
        PanelLabel { Layout.fillWidth: true; text: tray.selected ? tray.selected.title : ""; elide: Text.ElideRight; wrapMode: Text.NoWrap }
    }
    Repeater {
        model: tray.selected ? menu.children : null
        Item {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: modelData.isSeparator ? 9 : 36
            Rectangle { visible: entry.modelData.isSeparator; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: "#45475a" }
            PanelAction {
                visible: !entry.modelData.isSeparator
                anchors.fill: parent
                enabled: entry.modelData.enabled
                iconName: entry.modelData.checkState === Qt.Checked ? "check" : ""
                trailingIconName: entry.modelData.hasChildren ? "chevron-right" : ""
                text: entry.modelData.text.replace(/&(.)/g, "$1")
                onClicked: {
                    if (entry.modelData.hasChildren) tray.menuPath = tray.menuPath.concat([entry.modelData]);
                    else { entry.modelData.triggered(); tray.app.closePopup(); }
                }
            }
        }
    }
}
