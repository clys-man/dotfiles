import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: calendar
    property bool compact: false
    property var integration: null
    property date today: new Date()
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    property date selected: today
    spacing: 12
    readonly property var cells: {
        const first = (month.getDay() + 6) % 7;
        const values = [];
        for (let i = 0; i < 42; i++) values.push(new Date(month.getFullYear(), month.getMonth(), i - first + 1));
        return values;
    }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function stepMonth(offset) { month = new Date(month.getFullYear(), month.getMonth() + offset, 1); }
    RowLayout {
        Layout.fillWidth: true
        PanelAction { iconName: "chevron-left"; onClicked: calendar.stepMonth(-1) }
        PanelLabel { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: calendar.month.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy"); font.pixelSize: 16; font.bold: true }
        PanelAction { iconName: "chevron-right"; onClicked: calendar.stepMonth(1) }
    }
    GridLayout {
        columns: 7
        columnSpacing: 4
        rowSpacing: 4
        Layout.fillWidth: true
        Repeater {
            model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            PanelLabel { required property string modelData; text: modelData; color: "#9399b2"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
        }
        Repeater {
            model: calendar.cells
            Rectangle {
                required property var modelData
                readonly property bool isToday: calendar.sameDay(modelData, calendar.today)
                readonly property bool isSelected: calendar.sameDay(modelData, calendar.selected)
                Layout.fillWidth: true
                implicitHeight: calendar.compact ? 26 : 34
                radius: 8
                color: isToday ? "#89b4fa" : dayMouse.containsMouse ? "#45475a" : isSelected ? "#313244" : "transparent"
                border.width: isSelected && !isToday ? 1 : 0
                border.color: "#89b4fa"
                PanelLabel { anchors.centerIn: parent; text: parent.modelData.getDate(); color: parent.isToday ? "#1e1e2e" : parent.modelData.getMonth() === calendar.month.getMonth() ? "#cdd6f4" : "#585b70" }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 3
                    height: 3
                    radius: 2
                    visible: !!calendar.integration && calendar.integration.eventsFor(parent.modelData).length > 0
                    color: parent.isToday ? "#1e1e2e" : "#89b4fa"
                }
                MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true; onClicked: calendar.selected = parent.modelData }
            }
        }
    }
    Rectangle { visible: !calendar.compact; Layout.fillWidth: true; height: 1; color: "#313244" }
    PanelLabel { visible: !calendar.compact; Layout.fillWidth: true; text: calendar.selected.toLocaleDateString(Qt.locale("en_US"), "dddd, MMMM d"); color: "#a6adc8" }
    PanelAction { visible: !calendar.compact; Layout.fillWidth: true; text: "Today"; onClicked: { calendar.month = new Date(calendar.today.getFullYear(), calendar.today.getMonth(), 1); calendar.selected = calendar.today; } }
}
