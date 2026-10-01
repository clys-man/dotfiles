import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

RowLayout {
    id: center
    required property var app
    readonly property var store: app.notifications
    property real availableHeight: 700
    spacing: 20
    implicitHeight: Math.min(700, availableHeight)
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 360
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            PanelLabel { Layout.fillWidth: true; text: "Notifications"; font.pixelSize: 15; font.bold: true }
            PanelAction { text: "Clear"; enabled: center.store.count > 0; onClicked: center.store.clear() }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: 8
                Repeater {
                    model: center.store.entries.filter(e => !e.transient)
                    NotificationCard {
                        required property var modelData
                        Layout.fillWidth: true
                        entry: modelData
                        store: center.store
                    }
                }
                Item {
                    visible: center.store.count === 0
                    Layout.fillWidth: true
                    implicitHeight: 220
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14
                        Icon { Layout.alignment: Qt.AlignHCenter; name: "bell"; color: "#585b70"; size: 40 }
                        PanelLabel { text: "No notifications"; color: "#9399b2" }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#45475a" }
        RowLayout {
            Layout.fillWidth: true
            PanelLabel { Layout.fillWidth: true; text: "Do Not Disturb"; color: "#a6adc8" }
            PanelSwitch { checked: center.store.doNotDisturb; Accessible.name: "Do Not Disturb"; onToggled: center.store.doNotDisturb = checked }
        }
    }
    Rectangle { Layout.fillHeight: true; width: 1; color: "#313244" }
    Binding { target: center.app.gnome; property: "rangeStart"; value: calendar.cells[0]; when: center.visible }
    Binding { target: center.app.gnome; property: "rangeEnd"; value: new Date(calendar.cells[41].getFullYear(), calendar.cells[41].getMonth(), calendar.cells[41].getDate() + 1); when: center.visible }
    ColumnLayout {
        Layout.preferredWidth: 310
        Layout.fillHeight: true
        spacing: 16
        Item {
            Layout.fillWidth: true
            implicitHeight: dateLabels.implicitHeight
            ColumnLayout {
                id: dateLabels
                width: parent.width
                spacing: 6
                PanelLabel { Layout.fillWidth: true; text: calendar.today.toLocaleDateString(Qt.locale("en_US"), "dddd"); color: "#a6adc8"; font.pixelSize: 14 }
                PanelLabel { Layout.fillWidth: true; text: calendar.today.toLocaleDateString(Qt.locale("en_US"), "MMMM d, yyyy"); font.pixelSize: 18; font.bold: true }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { calendar.month = new Date(calendar.today.getFullYear(), calendar.today.getMonth(), 1); calendar.selected = calendar.today; }
            }
        }
        CalendarWidget { id: calendar; Layout.fillWidth: true; compact: true; integration: center.app.gnome }
        ScrollView {
            id: details
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: details.availableWidth
                spacing: 12
                AgendaWidget { Layout.fillWidth: true; app: center.app; selectedDate: calendar.selected }
                WeatherWidget { Layout.fillWidth: true; app: center.app }
            }
        }
    }
}
