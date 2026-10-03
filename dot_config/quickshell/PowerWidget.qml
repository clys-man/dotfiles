import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import Quickshell.Io

ColumnLayout {
    id: power
    required property var app
    readonly property var connectedDevices: Bluetooth.devices.values.filter(device => device.connected && device.batteryAvailable).concat(power.app.status.usbDevices || [])
    function deviceIcon(device) {
        const type = String(device.icon || "").toLowerCase();
        if (/headset|headphone|audio-card/.test(type)) return "headphones";
        if (/mouse/.test(type)) return "mouse";
        if (/keyboard/.test(type)) return "keyboard";
        if (/phone|modem/.test(type)) return "phone";
        if (/speaker/.test(type)) return "speaker";
        if (/gaming|gamepad|joystick/.test(type)) return "gamepad";
        if (/computer/.test(type)) return "computer";
        if (/watch/.test(type)) return "watch";
        return "bluetooth";
    }
    property string profile: ""
    property var profiles: []
    property string error: ""
    spacing: 12
    Process {
        id: current
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector { onStreamFinished: power.profile = text.trim() }
    }
    Process {
        command: ["powerprofilesctl", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: power.profiles = ["power-saver", "balanced", "performance"].filter(p => text.indexOf(p + ":") >= 0)
        }
    }
    Process {
        id: change
        property string nextProfile: ""
        command: ["powerprofilesctl", "set", nextProfile]
        stderr: StdioCollector { onStreamFinished: power.error = text.trim() }
        onExited: (code, status) => { if (code === 0) { power.error = ""; current.running = true; } }
    }
    PanelLabel { Layout.fillWidth: true; font.pixelSize: 22; text: power.app.status.battery ? power.app.status.battery.percent + "%" : "Plugged in" }
    PanelLabel { color: "#a6adc8"; text: !power.app.status.battery || power.app.status.battery.charging ? "Charging" : "Battery" }
    Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }
    ColumnLayout {
        Layout.fillWidth: true
        visible: power.connectedDevices.length > 0
        spacing: 10
        PanelLabel { text: "Devices"; color: "#a6adc8" }
        ScrollView {
            id: devicesScroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(180, deviceList.implicitHeight)
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                id: deviceList
                width: devicesScroll.availableWidth
                spacing: 8
                Repeater {
                    model: power.connectedDevices
                    Rectangle {
                        id: deviceRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 10
                        color: "#313244"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            Icon { name: power.deviceIcon(deviceRow.modelData); color: "#89b4fa"; size: 18 }
                            PanelLabel {
                                Layout.fillWidth: true
                                text: deviceRow.modelData.name || deviceRow.modelData.deviceName || deviceRow.modelData.address
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                            }
                            PanelLabel {
                                text: Math.round(deviceRow.modelData.battery * 100) + "%"
                                color: deviceRow.modelData.battery <= 0.2 ? "#f38ba8" : "#a6adc8"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }
    }
    PanelLabel { text: "Power profile"; color: "#a6adc8" }
    Repeater {
        model: power.profiles
        PanelAction {
            required property string modelData
            Layout.fillWidth: true
            accent: power.profile === modelData
            enabled: !change.running
            iconName: ({"power-saver": "leaf", "balanced": "balance", "performance": "gauge"})[modelData]
            text: ({"power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance"})[modelData]
            onClicked: { change.nextProfile = modelData; change.running = true; }
        }
    }
    PanelLabel { visible: power.profiles.length === 0; Layout.fillWidth: true; text: "Power profiles unavailable."; color: "#9399b2" }
    PanelLabel { visible: power.error.length > 0; Layout.fillWidth: true; text: power.error; color: "#f38ba8" }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: [
                { icon: "lock", name: "Lock", command: ["hyprlock"] },
                { icon: "hibernate", name: "Hibernate", command: ["systemctl", "hibernate"] },
                { icon: "logout", name: "Log out", command: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                { icon: "power", name: "Shut down", command: ["systemctl", "poweroff"] },
                { icon: "moon", name: "Suspend", command: ["systemctl", "suspend"] },
                { icon: "restart", name: "Restart", command: ["systemctl", "reboot"] }
            ]
            Rectangle {
                id: action
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 46
                radius: 10
                color: mouse.pressed ? "#585b70" : mouse.containsMouse ? "#45475a" : "#313244"
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name
                Accessible.onPressAction: {
                    power.app.closePopup();
                    power.app.run(modelData.command);
                }
                Icon {
                    anchors.centerIn: parent
                    name: action.modelData.icon
                    color: "#89b4fa"
                    size: 21
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        power.app.closePopup();
                        power.app.run(action.modelData.command);
                    }
                }
            }
        }
    }
}
