import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Io

ColumnLayout {
    id: wifi
    required property var app
    property var connectionInfo: []
    readonly property var connectedInfo: connectionInfo.filter(info => devices.concat(wiredDevices).some(device => device.connected && device.name === info.interface))
    Process {
        id: addresses
        command: ["python3", Quickshell.shellPath("network-info.py")]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try { wifi.connectionInfo = JSON.parse(data); }
                catch (error) { wifi.connectionInfo = []; }
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: { if (!addresses.running) addresses.running = true; } }
    property var selected: null
    property string message: ""
    readonly property var devices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var networks: devices.reduce((all, d) => all.concat(d.networks.values), []).sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength)
    spacing: 12
    function usesPassword(n) { return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].indexOf(n.security) >= 0; }
    function choose(n) {
        message = "";
        selected = n;
        password.text = "";
        if (n.connected) n.disconnect();
        else if (n.known || n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe) n.connect();
        else if (usesPassword(n)) password.forceActiveFocus();
        else message = "Configure this network in Settings.";
    }
    function connectPassword() {
        if (!selected || !password.text.length || selected.stateChanging) return;
        selected.connectWithPsk(password.text);
        password.text = "";
    }
    Component.onCompleted: devices.forEach(d => d.scannerEnabled = true)
    Component.onDestruction: devices.forEach(d => d.scannerEnabled = false)
    Connections {
        target: wifi.selected
        function onConnectionFailed(reason) { wifi.message = "Could not connect. Check the password and try again."; }
        function onConnectedChanged() { if (wifi.selected && wifi.selected.connected) { wifi.message = ""; wifi.selected = null; } }
    }
    PanelLabel { visible: wifi.wiredDevices.length > 0; text: "Wired connection"; color: "#a6adc8" }
    Repeater {
        model: wifi.wiredDevices
        Rectangle {
            id: wired
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 64
            radius: 10
            color: "#313244"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Icon { name: "ethernet"; size: 19; color: wired.modelData.connected ? "#a6e3a1" : "#9399b2" }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    PanelLabel { Layout.fillWidth: true; text: wired.modelData.network ? wired.modelData.network.name : wired.modelData.name; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                    PanelLabel {
                        Layout.fillWidth: true
                        font.pixelSize: 10
                        color: "#9399b2"
                        text: wired.modelData.name + " · " + (wired.modelData.connected ? "Connected" : wired.modelData.hasLink ? "Disconnected" : "Cable unplugged") + (wired.modelData.hasLink && wired.modelData.linkSpeed ? " · " + wired.modelData.linkSpeed + " Mbps" : "")
                    }
                }
                PanelSwitch {
                    checked: wired.modelData.connected
                    enabled: wired.modelData.hasLink && !(wired.modelData.network && wired.modelData.network.stateChanging)
                    Accessible.name: "Wired connection " + wired.modelData.name
                    onToggled: {
                        if (!checked) wired.modelData.disconnect();
                        else if (wired.modelData.network) wired.modelData.network.connect();
                        else wifi.app.run(["nmcli", "device", "connect", wired.modelData.name]);
                    }
                }
            }
        }
    }
    Rectangle { visible: wifi.wiredDevices.length > 0; Layout.fillWidth: true; height: 1; color: "#313244" }
    RowLayout {
        Layout.fillWidth: true
        PanelLabel { Layout.fillWidth: true; text: "Wi-Fi"; color: "#a6adc8" }
        PanelSwitch { checked: Networking.wifiEnabled; enabled: Networking.wifiHardwareEnabled && wifi.devices.length > 0; Accessible.name: "Wi-Fi"; onToggled: Networking.wifiEnabled = checked }
    }
    PanelLabel { visible: !Networking.wifiHardwareEnabled || !wifi.devices.length; Layout.fillWidth: true; text: wifi.devices.length ? "Wi-Fi blocked by airplane mode." : "No Wi-Fi adapter found."; color: "#f9e2af" }
    ScrollView {
        visible: Networking.wifiEnabled && wifi.devices.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(320, Math.max(64, list.implicitHeight))
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6
            Repeater {
                model: wifi.networks
                Rectangle {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 60
                    radius: 10
                    color: networkMouse.containsMouse ? "#45475a" : "#313244"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Icon {
                            name: "wifi-signal-" + (row.modelData.signalStrength >= 0.75 ? 3 : row.modelData.signalStrength >= 0.5 ? 2 : row.modelData.signalStrength >= 0.25 ? 1 : 0) + (row.modelData.security !== WifiSecurityType.Open ? "-secure" : "")
                            size: 22
                            color: row.modelData.connected ? "#a6e3a1" : "#89b4fa"
                            Accessible.name: Math.round(row.modelData.signalStrength * 100) + "% · " + (row.modelData.security === WifiSecurityType.Open ? "Open network" : "Secured network")
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            PanelLabel { Layout.fillWidth: true; text: row.modelData.name || "Hidden network"; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            PanelLabel { visible: row.modelData.stateChanging || row.modelData.connected || row.modelData.known; Layout.fillWidth: true; font.pixelSize: 10; color: "#9399b2"; text: row.modelData.stateChanging ? "Connecting…" : row.modelData.connected ? "Connected · click to disconnect" : row.modelData.known ? "Saved" : "" }
                        }
                        Icon { name: row.modelData.connected ? "check" : "chevron-right"; color: "#a6e3a1" }
                    }
                    MouseArea { id: networkMouse; anchors.fill: parent; hoverEnabled: true; enabled: !row.modelData.stateChanging; onClicked: wifi.choose(row.modelData) }
                }
            }
            PanelLabel { visible: wifi.networks.length === 0; Layout.fillWidth: true; text: "Scanning for nearby networks…"; color: "#9399b2" }
        }
    }
    ColumnLayout {
        visible: wifi.connectedInfo.length > 0
        Layout.fillWidth: true
        spacing: 10
        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }
        PanelLabel { text: "Connection details"; color: "#a6adc8" }
        Repeater {
            model: wifi.connectedInfo
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 4
                PanelLabel { Layout.fillWidth: true; text: parent.modelData.interface; font.bold: true; font.pixelSize: 12 }
                PanelLabel { Layout.fillWidth: true; visible: parent.modelData.ipv4.length > 0; text: "IPv4: " + parent.modelData.ipv4.join(", "); font.pixelSize: 11 }
                PanelLabel { Layout.fillWidth: true; visible: parent.modelData.gateway.length > 0; text: "Gateway: " + parent.modelData.gateway.join(", "); font.pixelSize: 11 }
                PanelLabel { Layout.fillWidth: true; visible: parent.modelData.dns.length > 0; text: "DNS: " + parent.modelData.dns.join(", "); font.pixelSize: 11 }
                PanelLabel { Layout.fillWidth: true; visible: parent.modelData.ipv6.length > 0; text: "IPv6: " + parent.modelData.ipv6.join(", "); font.pixelSize: 11 }
            }
        }
    }
    ColumnLayout {
        visible: !!wifi.selected && !wifi.selected.connected && wifi.usesPassword(wifi.selected)
        Layout.fillWidth: true
        PanelLabel { Layout.fillWidth: true; text: "Password for " + (wifi.selected ? wifi.selected.name : "") }
        TextField {
            id: password
            Layout.fillWidth: true
            placeholderText: "Network password"
            echoMode: TextInput.Password
            color: "#cdd6f4"
            placeholderTextColor: "#9399b2"
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 13
            background: Rectangle { radius: 8; color: "#313244"; border.color: password.activeFocus ? "#89b4fa" : "#45475a" }
            onAccepted: wifi.connectPassword()
        }
        PanelAction { Layout.fillWidth: true; text: wifi.selected && wifi.selected.stateChanging ? "Connecting…" : "Connect"; accent: true; enabled: password.text.length > 0 && !!wifi.selected && !wifi.selected.stateChanging; onClicked: wifi.connectPassword() }
    }
    PanelLabel { visible: wifi.message.length > 0; Layout.fillWidth: true; text: wifi.message; color: "#f38ba8" }
}
