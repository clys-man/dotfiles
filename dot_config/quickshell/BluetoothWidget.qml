import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth

ColumnLayout {
    id: bluetooth
    required property var app
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values.filter(d => d.name || d.paired).sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired) || a.name.localeCompare(b.name)) : []
    property bool scanning: false
    spacing: 12
    Component.onDestruction: { if (scanning && adapter) adapter.discovering = false; }
    Timer { interval: 20000; running: bluetooth.scanning; onTriggered: { if (bluetooth.adapter) bluetooth.adapter.discovering = false; bluetooth.scanning = false; } }
    RowLayout {
        Layout.fillWidth: true
        PanelLabel { Layout.fillWidth: true; text: bluetooth.adapter ? "Bluetooth" : "Adapter unavailable"; color: "#a6adc8" }
        PanelSwitch { checked: !!bluetooth.adapter && bluetooth.adapter.enabled; enabled: !!bluetooth.adapter; Accessible.name: "Bluetooth"; onToggled: bluetooth.adapter.enabled = checked }
    }
    PanelAction {
        visible: !!bluetooth.adapter && bluetooth.adapter.enabled
        Layout.fillWidth: true
        text: bluetooth.scanning ? "Stop scanning" : "Scan for devices"
        onClicked: { bluetooth.scanning = !bluetooth.scanning; bluetooth.adapter.discovering = bluetooth.scanning; }
    }
    ScrollView {
        visible: !!bluetooth.adapter && bluetooth.adapter.enabled
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(320, Math.max(60, list.implicitHeight))
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6
            Repeater {
                model: bluetooth.devices
                Rectangle {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: 10
                    color: "#313244"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Icon { name: "bluetooth"; color: row.modelData.connected ? "#a6e3a1" : "#89b4fa"; size: 20 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            PanelLabel { Layout.fillWidth: true; text: row.modelData.name || row.modelData.address; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            PanelLabel { font.pixelSize: 10; color: "#9399b2"; text: (row.modelData.connected ? "Connected" : row.modelData.paired ? "Paired" : "Available") + (row.modelData.batteryAvailable ? " · " + Math.round(row.modelData.battery * 100) + "%" : "") }
                        }
                        PanelAction {
                            text: row.modelData.connected ? "Disconnect" : row.modelData.paired ? "Connect" : "Pair"
                            onClicked: {
                                if (row.modelData.connected) row.modelData.disconnect();
                                else if (row.modelData.paired) row.modelData.connect();
                                else { bluetooth.app.bluetoothSettings(); }
                            }
                        }
                    }
                }
            }
            PanelLabel { visible: bluetooth.devices.length === 0; Layout.fillWidth: true; color: "#9399b2"; text: bluetooth.scanning ? "Scanning for devices…" : "No devices found. Scan for devices." }
        }
    }
}
