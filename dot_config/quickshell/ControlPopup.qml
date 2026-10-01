import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: popup
    required property var app
    required property var bar
    readonly property string kind: app.popupOwner === bar ? app.popupKind : ""
    visible: kind.length > 0 && app.shown
    screen: bar.screen
    anchors { top: true; left: true }
    margins.left: Math.max(8, Math.min(bar.width - width - 8, app.popupX - width / 2))
    margins.top: bar.height + 8
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    implicitWidth: kind === "calendar" ? Math.min(780, bar.width - 32) : 380
    implicitHeight: card.implicitHeight + 16
    color: "transparent"
    HyprlandFocusGrab {
        active: popup.visible
        windows: [bar, popup]
        onCleared: { if (popup.app.popupOwner === popup.bar) popup.app.closePopup(); }
    }
    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 8
        implicitHeight: content.implicitHeight + 32
        color: "#1e1e2e"
        radius: 16
        border.color: "#45475a"
        border.width: 1
        focus: true
        Keys.onEscapePressed: popup.app.closePopup()
        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 16
            RowLayout {
                visible: popup.kind !== "calendar"
                Layout.fillWidth: true
                PanelLabel { Layout.fillWidth: true; font.pixelSize: 18; font.bold: true; text: ({calendar: "Notifications and calendar", wifi: "Network", bluetooth: "Bluetooth", tray: "System tray", audio: "Audio", display: "Display", power: "Power"})[popup.kind] || "" }
                PanelAction {
                    visible: ["audio", "bluetooth", "wifi"].indexOf(popup.kind) >= 0
                    iconName: "settings"
                    iconOnly: true
                    implicitWidth: 34
                    Accessible.name: "Settings"
                    onClicked: popup.app.widgetSettings(popup.kind)
                }
                PanelAction { iconName: "close"; iconOnly: true; implicitWidth: 34; Accessible.name: "Close"; onClicked: popup.app.closePopup() }
            }
            Loader {
                id: body
                Layout.fillWidth: true
                Layout.preferredHeight: item ? item.implicitHeight : 0
                active: popup.visible
                sourceComponent: ({calendar: calendar, wifi: wifi, bluetooth: bluetooth, tray: tray, audio: audio, display: display, power: power})[popup.kind] || null
            }
        }
    }
    Component { id: calendar; NotificationCenterWidget { app: popup.app; availableHeight: Math.min(700, popup.bar.screen.height - 150) } }
    Component { id: wifi; WifiWidget { app: popup.app } }
    Component { id: bluetooth; BluetoothWidget { app: popup.app } }
    Component { id: tray; TrayWidget { app: popup.app } }
    Component { id: audio; AudioWidget { app: popup.app } }
    Component { id: display; DisplayWidget { app: popup.app } }
    Component { id: power; PowerWidget { app: popup.app } }
}
