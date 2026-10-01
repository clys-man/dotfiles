import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: integration
    property bool active: false
    property date rangeStart: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property date rangeEnd: new Date(new Date().getFullYear(), new Date().getMonth() + 1, 1)
    property var events: []
    property string calendarState: "loading"
    property bool hasCalendars: false
    property var weather: ({state: "loading", location: "", forecasts: []})
    function request() {
        if (bridge.running) bridge.write(JSON.stringify({active: active, since: Math.floor(rangeStart.getTime() / 1000), until: Math.floor(rangeEnd.getTime() / 1000)}) + "\n");
    }
    function overlaps(event, day) {
        const begin = new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime() / 1000;
        const end = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1).getTime() / 1000;
        return event.start === event.end ? event.start >= begin && event.start < end : event.start < end && event.end > begin;
    }
    function eventsFor(day) { return events.filter(event => overlaps(event, day)); }
    Component.onCompleted: update.restart()
    onActiveChanged: update.restart()
    onRangeStartChanged: update.restart()
    onRangeEndChanged: update.restart()
    Timer { id: update; interval: 50; onTriggered: integration.request() }
    Process {
        id: bridge
        command: ["env", "LANGUAGE=en", "LC_MESSAGES=en_US.UTF-8", "/usr/bin/python3", "-u", "-B", Quickshell.shellPath("gnome-integration.py")]
        running: true
        stdinEnabled: true
        onStarted: integration.request()
        onExited: {
            integration.calendarState = "unavailable";
            integration.weather = Object.assign({}, integration.weather, {state: "unavailable"});
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    const state = JSON.parse(data);
                    integration.events = state.events || [];
                    integration.calendarState = state.calendarState;
                    integration.hasCalendars = !!state.hasCalendars;
                    integration.weather = state.weather;
                } catch (error) { console.warn("Could not read calendar and weather data."); }
            }
        }
    }
}
