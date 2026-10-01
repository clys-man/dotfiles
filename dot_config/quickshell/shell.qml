import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth

ShellRoot {
    id: root
    property alias gnome: gnomeIntegration
    GnomeIntegration { id: gnomeIntegration; active: root.popupKind === "calendar" && root.shown }
    property alias notifications: notificationStore
    NotificationStore { id: notificationStore; centerOpen: root.popupKind === "calendar" }
    NotificationToasts { app: root }
    property bool shown: true
    property string popupKind: ""
    property var popupOwner: null
    property real popupX: 0
    property var panels: []
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool bluetoothOutput: !!audioSink && (audioSink.name.startsWith("bluez_output.") || audioSink.properties["device.api"] === "bluez5" || audioSink.properties["api.bluez5.address"] !== undefined)
    readonly property string audioOutputIcon: bluetoothOutput ? "bluetooth" : audioSink && status.audioDevices ? status.audioDevices[audioSink.name] || "volume" : "volume"
    PwObjectTracker { objects: root.audioSink ? [root.audioSink] : [] }
    readonly property var connectedDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) || Networking.devices.values.find(d => d.type === DeviceType.Wifi && d.connected) || null
    readonly property var connectedNetwork: connectedDevice ? connectedDevice.networks.values.find(n => n.connected) || (connectedDevice.type === DeviceType.Wired ? connectedDevice.network : null) : null
    function closePopup() { popupKind = ""; popupOwner = null; }
    function openPopup(kind, bar, item) {
        if (popupKind === kind && popupOwner === bar) { closePopup(); return; }
        popupX = item ? item.mapToItem(bar.contentItem, item.width / 2, 0).x : bar.width / 2;
        popupOwner = bar;
        popupKind = kind;
    }
    property var status: ({})
    property date now: new Date()
    readonly property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    function run(args) { Quickshell.execDetached(args); }
    function widgetSettings(kind) {
        if (kind === "bluetooth") { bluetoothSettings(); return; }
        if (kind === "audio") run(["pavucontrol"]);
        else if (kind === "wifi") run(["nm-connection-editor"]);
        else return;
        closePopup();
    }
    function openCalendar(day) {
        run(["gnome-calendar", "--date", Qt.formatDate(day, "yyyy-MM-dd")]);
        closePopup();
    }
    function openWeather() {
        run(["gnome-weather"]);
        closePopup();
    }
    function bluetoothSettings() {
        Hyprland.dispatch('hl.dsp.exec_cmd("alacritty --class bluetui,bluetui --title bluetui -e bluetui")');
        closePopup();
    }
    function workspace(monitor, id) {
        if (!Hyprland.monitors.values.some(m => m.name === monitor) || id < 1) return;
        const name = JSON.stringify(monitor);
        Hyprland.dispatch("hl.dsp.focus({monitor=" + name + "})");
        Hyprland.dispatch("hl.dsp.focus({workspace=" + id + "})");
    }
    function workspaceIds(monitor) {
        const all = Hyprland.workspaces.values.filter(w => w.id > 0);
        const ids = all.filter(w => w.monitor && w.monitor.name === monitor).map(w => w.id);
        for (let i = 1; i <= 5; i++) {
            if (!all.some(w => w.id === i) && ids.indexOf(i) < 0) ids.push(i);
        }
        return ids.sort((a, b) => a - b);
    }
    function volume(target, up) {
        run(up ? ["wpctl", "set-volume", "-l", "1", target, "5%+"] : ["wpctl", "set-volume", target, "5%-"]);
    }
    Process {
        id: stats
        command: ["python3", "-u", "-B", Quickshell.shellPath("status.py")]
        running: true
        stdout: SplitParser { onRead: data => { try { root.status = JSON.parse(data); } catch (e) { console.warn(e); } } }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    IpcHandler {
        target: "bar"
        function toggle(): void { root.closePopup(); root.shown = !root.shown; }
        function open(kind: string, monitor: string): void {
            if (["calendar", "wifi", "bluetooth", "tray", "audio", "display", "power"].indexOf(kind) < 0) return;
            const bar = root.panels.find(p => p.screen.name === monitor);
            if (bar) root.openPopup(kind, bar, null);
        }
        function close(): void { root.closePopup(); }
        function openFocused(kind: string): void {
            if (["calendar", "wifi", "bluetooth", "tray", "audio", "display", "power"].indexOf(kind) < 0) return;
            const bar = root.panels.find(p => Hyprland.focusedMonitor && p.screen.name === Hyprland.focusedMonitor.name);
            if (bar) root.openPopup(kind, bar, null);
        }
        function inspect(): string {
            return JSON.stringify({popup: root.popupKind, notifications: notificationStore.count, doNotDisturb: notificationStore.doNotDisturb, panels: root.panels.map(p => p.screen.name), wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi).length, bluetooth: !!Bluetooth.defaultAdapter, trayItems: SystemTray.items.values.length});
        }
        function workspace(monitor: string, id: int): void { root.workspace(monitor, id); }
        function workspaces(monitor: string): string { return JSON.stringify(root.workspaceIds(monitor)); }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            visible: root.shown
            anchors { top: true; left: true; right: true }
            implicitHeight: 42
            color: "#cc1e1e2e"
            readonly property var monitor: Hyprland.monitorFor(screen)
            Component.onCompleted: root.panels = root.panels.concat([panel])
            Component.onDestruction: {
                if (root.popupOwner === panel) root.closePopup();
                root.panels = root.panels.filter(p => p !== panel);
            }
            ControlPopup { app: root; bar: panel }
            RowLayout {
                id: left
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                BarButton { text: ""; foreground: "#89b4fa"; tooltip: "Applications"; onClicked: root.run(["fuzzel"]) }
                Repeater {
                    model: root.workspaceIds(panel.screen.name)
                    BarButton {
                        required property int modelData
                        readonly property bool active: panel.monitor && panel.monitor.activeWorkspace && panel.monitor.activeWorkspace.id === modelData
                        text: String(modelData)
                        background: active ? "#89b4fa" : "#313244"
                        foreground: active ? "#1e1e2e" : "#cdd6f4"
                        tooltip: "Workspace " + modelData
                        onClicked: root.workspace(panel.screen.name, modelData)
                        onScrolled: up => {
                            const ids = root.workspaceIds(panel.screen.name);
                            const current = panel.monitor && panel.monitor.activeWorkspace ? panel.monitor.activeWorkspace.id : ids[0];
                            const index = ids.indexOf(current);
                            root.workspace(panel.screen.name, ids[(index + (up ? -1 : 1) + ids.length) % ids.length]);
                        }
                    }
                }
                MusicPlayer {
                    player: root.player
                    availableWidth: panel.width / 2 - clockButton.implicitWidth / 2 - (root.workspaceIds(panel.screen.name).length * 45 + 55) - 20
                }
            }
            RowLayout {
                anchors.centerIn: parent
                spacing: 5
                visible: left.width < panel.width / 2 - width / 2 - 10 && right.width < panel.width / 2 - width / 2 - 10
                BarButton {
                    id: clockButton
                    implicitWidth: clockContent.implicitWidth + 20
                    RowLayout {
                        id: clockContent
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            text: Qt.formatDateTime(root.now, "HH:mm  dd·MM·yy")
                            color: clockButton.foreground
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 14
                        }
                        Image {
                            source: Quickshell.shellPath(root.notifications.doNotDisturb ? "icons/bell-muted.svg" : "icons/bell.svg")
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            Layout.alignment: Qt.AlignVCenter
                            sourceSize.width: 14
                            sourceSize.height: 14
                        }
                        Text {
                            visible: root.notifications.count > 0
                            text: root.notifications.count
                            color: clockButton.foreground
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 14
                        }
                    }
                    background: root.popupKind === "calendar" && root.popupOwner === panel ? "#45475a" : "#313244"
                    onClicked: button => {
                        if (button === Qt.RightButton) root.notifications.doNotDisturb = !root.notifications.doNotDisturb;
                        else root.openPopup("calendar", panel, clockButton);
                    }
                }
            }
            RowLayout {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                BarButton { id: trayButton; visible: SystemTray.items.values.length > 0; iconName: "chevron-right"; text: String(SystemTray.items.values.length); tooltip: "System tray"; background: root.popupKind === "tray" && root.popupOwner === panel ? "#45475a" : "#313244"; onClicked: root.openPopup("tray", panel, trayButton) }
                SystemStatus { status: root.status; onClicked: Hyprland.dispatch('hl.dsp.exec_cmd("alacritty --class btop,btop --title btop -e btop")') }
                Rectangle {
                    implicitWidth: controls.implicitWidth + 8
                    implicitHeight: 32
                    radius: 12
                    color: "#313244"
                    RowLayout {
                        id: controls
                        anchors.centerIn: parent
                        spacing: 0
                        BarButton { grouped: true; id: wifiButton; iconName: root.connectedDevice && root.connectedDevice.type === DeviceType.Wired ? "ethernet" : root.connectedDevice ? "wifi" : "wifi-off"; tooltip: root.connectedNetwork ? root.connectedNetwork.name : "Network"; onClicked: root.openPopup("wifi", panel, wifiButton) }
                        BarButton { grouped: true; id: bluetoothButton; iconName: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "bluetooth" : "bluetooth-muted"; tooltip: "Bluetooth"; onClicked: button => { if (button === Qt.RightButton && Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled; else root.openPopup("bluetooth", panel, bluetoothButton); } }
                        BarButton { grouped: true; id: displayButton; visible: root.status.brightness !== null && root.status.brightness !== undefined; iconName: root.status.night ? "moon" : "sun"; text: root.status.brightness + "%"; tooltip: "Brightness and display"; onClicked: root.openPopup("display", panel, displayButton); onScrolled: up => root.run(["brightnessctl", "-e4", "-n2", "set", up ? "5%+" : "5%-"]) }
                        BarButton { grouped: true; id: audioButton; implicitWidth: volumeContent.implicitWidth + 20
                            RowLayout {
                                id: volumeContent
                                anchors.centerIn: parent
                                spacing: 7
                                Image {
                                    source: Quickshell.shellPath("icons/" + root.audioOutputIcon + (root.status.volume && root.status.volume.muted ? "-muted" : "") + ".svg")
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    Layout.alignment: Qt.AlignVCenter
                                    sourceSize.width: 28
                                    sourceSize.height: 28
                                }
                                Text {
                                    visible: !(root.status.volume && root.status.volume.muted)
                                    text: (root.status.volume ? root.status.volume.percent : 0) + "%"
                                    color: audioButton.foreground
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 14
                                }
                            }
                            tooltip: "Volume"; onClicked: button => { if (button === Qt.RightButton) root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); else root.openPopup("audio", panel, audioButton); }; onScrolled: up => root.volume("@DEFAULT_AUDIO_SINK@", up) }
                        BarButton {
                            grouped: true
                            id: micButton
                            iconName: root.status.mic && root.status.mic.muted ? "microphone-muted" : "microphone"
                            text: root.status.mic && !root.status.mic.muted ? root.status.mic.percent + "%" : ""
                            tooltip: "Microphone"
                            onClicked: button => {
                                if (button === Qt.RightButton) root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
                                else if (button === Qt.MiddleButton) root.openPopup("audio", panel, micButton);
                            }
                            onScrolled: up => root.volume("@DEFAULT_AUDIO_SOURCE@", up)
                        }
                        BarButton { grouped: true; id: batteryButton; visible: !!root.status.battery; iconName: root.status.battery && root.status.battery.charging ? "plug" : "battery"; text: (root.status.battery ? root.status.battery.percent : "") + "%"; foreground: root.status.battery && Number(root.status.battery.percent) <= 20 ? "#f38ba8" : "#cdd6f4"; tooltip: "Battery and power"; onClicked: root.openPopup("power", panel, batteryButton) }
                        BarButton { grouped: true; id: powerButton; iconName: "power"; foreground: "#89b4fa"; tooltip: "Power"; onClicked: root.openPopup("power", panel, powerButton) }
                    }
                }
            }
        }
    }
}
