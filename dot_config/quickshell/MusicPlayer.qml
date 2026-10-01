import QtQuick
import QtQuick.Layouts

Rectangle {
    id: music
    required property var player
    property real availableWidth: 420
    visible: !!player && availableWidth >= 150
    implicitWidth: Math.min(availableWidth, Math.min(480, title.implicitWidth + 116))
    implicitHeight: 32
    radius: 12
    color: "#313244"
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 10
        spacing: 4
        Repeater {
            model: ["previous", "play", "next"]
            Rectangle {
                required property string modelData
                Layout.preferredWidth: 28
                Layout.preferredHeight: 26
                radius: 8
                color: controlMouse.containsMouse ? "#45475a" : "transparent"
                Icon {
                    anchors.centerIn: parent
                    name: modelData === "previous" ? "previous" : modelData === "next" ? "next" : music.player && music.player.isPlaying ? "pause" : "play"
                }
                MouseArea {
                    id: controlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (!music.player) return;
                        if (modelData === "previous" && music.player.canGoPrevious) music.player.previous();
                        else if (modelData === "next" && music.player.canGoNext) music.player.next();
                        else if (modelData === "play" && music.player.canTogglePlaying) music.player.togglePlaying();
                    }
                }
            }
        }
        Item {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 4
            clip: true
            Text {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                text: music.player ? music.player.trackTitle || music.player.identity : ""
                color: "#cdd6f4"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 14
                onTextChanged: { scroll.restart(); x = 0; }
            }
            SequentialAnimation {
                id: scroll
                running: music.visible && title.implicitWidth > viewport.width
                loops: Animation.Infinite
                PauseAnimation { duration: 2000 }
                NumberAnimation { target: title; property: "x"; from: 0; to: Math.min(0, viewport.width - title.implicitWidth); duration: Math.max(1000, (title.implicitWidth - viewport.width) * 28) }
                PauseAnimation { duration: 2000 }
                NumberAnimation { target: title; property: "x"; to: 0; duration: 250 }
                onRunningChanged: { if (!running) title.x = 0; }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { if (music.player && music.player.canRaise) music.player.raise(); }
            }
        }
    }
}
