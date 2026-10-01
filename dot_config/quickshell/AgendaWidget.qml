import QtQuick
import QtQuick.Layouts

Rectangle {
    id: agenda
    required property var app
    required property date selectedDate
    readonly property var integration: app.gnome
    readonly property var events: integration.eventsFor(selectedDate)
    implicitHeight: content.implicitHeight + 24
    radius: 12
    color: "#313244"
    function eventTime(event) {
        const begin = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate());
        const end = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + 1);
        const startDate = new Date(event.start * 1000);
        const endDate = new Date(event.end * 1000);
        if (startDate <= begin && endDate >= end) return "All day";
        const start = startDate < begin ? begin : startDate;
        const finish = endDate > end ? end : endDate;
        const from = Qt.formatTime(start, "HH:mm");
        return event.start === event.end ? from : from + " – " + (endDate >= end ? "24:00" : Qt.formatTime(finish, "HH:mm"));
    }
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            PanelLabel {
                Layout.fillWidth: true
                text: selectedDate.toDateString() === new Date().toDateString() ? "Today" : selectedDate.toLocaleDateString(Qt.locale("en_US"), "MMMM d")
                font.bold: true
                font.pixelSize: 14
            }
            Icon { name: "external"; color: "#9399b2"; size: 14 }
        }
        PanelLabel {
            Layout.fillWidth: true
            visible: agenda.events.length === 0
            text: agenda.integration.calendarState === "loading" ? "Loading events…" : agenda.integration.calendarState === "unavailable" ? "Could not access your calendars." : !agenda.integration.hasCalendars ? "No calendars configured." : "No events"
            color: "#a6adc8"
            font.pixelSize: 12
        }
        Repeater {
            model: agenda.events
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 3
                PanelLabel { Layout.fillWidth: true; text: parent.modelData.summary || "Untitled"; font.pixelSize: 12; font.bold: true }
                PanelLabel { Layout.fillWidth: true; text: agenda.eventTime(parent.modelData); color: "#a6adc8"; font.pixelSize: 11 }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: agenda.app.openCalendar(agenda.selectedDate)
        Accessible.role: Accessible.Button
        Accessible.name: "Open Calendar"
    }
}
