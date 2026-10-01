import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: display
    required property var app
    spacing: 12
    PanelLabel { text: "Display brightness"; color: "#a6adc8" }
    RowLayout {
        Layout.fillWidth: true
        PanelSlider {
            id: brightness
            Layout.fillWidth: true
            from: 2
            enabled: display.app.status.brightness !== null && display.app.status.brightness !== undefined
            value: display.app.status.brightness || 2
            onPressedChanged: { if (!pressed && enabled) display.app.run(["brightnessctl", "set", Math.round(value) + "%"]); }
        }
        PanelLabel { text: Math.round(brightness.value) + "%" }
    }
    RowLayout {
        Layout.fillWidth: true
        PanelLabel { Layout.fillWidth: true; text: "Night light" }
        PanelSwitch {
            checked: !!display.app.status.night
            Accessible.name: "Night light"
            onToggled: {
                display.app.run(checked ? ["gammastep", "-O", "3500"] : ["pkill", "-x", "gammastep"]);
                display.app.status = Object.assign({}, display.app.status, {night: checked});
            }
        }
    }
}
