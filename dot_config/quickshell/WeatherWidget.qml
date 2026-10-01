import QtQuick
import QtQuick.Layouts

Rectangle {
    id: weather
    required property var app
    readonly property var weatherInfo: app.gnome.weather
    implicitHeight: content.implicitHeight + 24
    radius: 12
    color: "#313244"
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            PanelLabel { text: "Weather"; font.bold: true; font.pixelSize: 14 }
            PanelLabel { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: weather.weatherInfo.location || ""; color: "#a6adc8"; font.pixelSize: 11; wrapMode: Text.NoWrap; elide: Text.ElideRight }
            Icon { name: "external"; color: "#9399b2" }
        }
        PanelLabel {
            Layout.fillWidth: true
            visible: weather.weatherInfo.state !== "ready"
            text: ({loading: "Loading forecast…", "no-location": "Select a location in Weather.", offline: "Go online for weather information.", unavailable: "Weather information unavailable."})[weather.weatherInfo.state] || "Weather information unavailable."
            color: "#a6adc8"
            font.pixelSize: 12
        }
        RowLayout {
            Layout.fillWidth: true
            visible: weather.weatherInfo.state === "ready"
            spacing: 8
            Icon { name: weather.weatherInfo.icon || "sun"; size: 22; color: "#89b4fa" }
            PanelLabel { text: weather.weatherInfo.temperature || ""; font.pixelSize: 17; font.bold: true }
            PanelLabel { Layout.fillWidth: true; text: weather.weatherInfo.conditions || ""; color: "#a6adc8"; font.pixelSize: 11 }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: weather.weatherInfo.state === "ready" && weather.weatherInfo.forecasts.length > 0
            spacing: 6
            Repeater {
                model: weather.weatherInfo.forecasts || []
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 7
                    PanelLabel { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: Qt.formatTime(new Date(parent.modelData.time * 1000), "HH:mm"); color: "#a6adc8"; font.pixelSize: 10 }
                    Icon { Layout.alignment: Qt.AlignHCenter; name: parent.modelData.icon; size: 22 }
                    PanelLabel { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: parent.modelData.temperature + "°"; font.pixelSize: 12 }
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: weather.app.openWeather()
        Accessible.role: Accessible.Button
        Accessible.name: "Open Weather"
    }
}
