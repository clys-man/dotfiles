import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: toasts
    required property var app
    readonly property var store: app.notifications
    visible: store.toasts.length > 0 && !store.centerOpen && !store.doNotDisturb
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
    anchors { top: true; right: true }
    margins.top: 54
    margins.right: 16
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    implicitWidth: 380
    implicitHeight: stack.implicitHeight
    color: "transparent"
    ColumnLayout {
        id: stack
        width: parent.width
        spacing: 8
        Repeater {
            model: toasts.store.toasts
            NotificationCard {
                required property var modelData
                Layout.fillWidth: true
                entry: modelData
                store: toasts.store
                toast: true
                Timer {
                    interval: Math.max(1000, parent.entry.timeout)
                    running: !parent.entry.critical && parent.entry.timeout !== 0
                    onTriggered: toasts.store.hideToast(parent.entry.key)
                }
            }
        }
    }
}
