import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: card
    required property var entry
    required property var store
    property bool expanded: false
    property bool toast: false
    implicitHeight: content.implicitHeight + 24
    radius: 12
    color: "#313244"
    border.width: entry.critical ? 1 : 0
    border.color: "#f38ba8"
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Image { source: card.store.icon(card.entry); Layout.preferredWidth: 20; Layout.preferredHeight: 20; visible: status === Image.Ready }
            PanelLabel { Layout.fillWidth: true; text: card.entry.appName; font.pixelSize: 11; color: "#a6adc8"; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            PanelLabel { text: Qt.formatDateTime(new Date(card.entry.created), "HH:mm"); font.pixelSize: 10; color: "#9399b2" }
            PanelAction { iconOnly: true; implicitWidth: 26; implicitHeight: 26; iconName: "close"; onClicked: card.store.dismiss(card.entry.key) }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: message.implicitHeight
            ColumnLayout {
                id: message
                width: parent.width
                spacing: 5
                PanelLabel { Layout.fillWidth: true; text: card.entry.summary; font.bold: true; maximumLineCount: card.expanded ? 30 : 2; elide: Text.ElideRight }
                PanelLabel { Layout.fillWidth: true; visible: card.entry.body.length > 0; text: card.entry.body; color: "#a6adc8"; maximumLineCount: card.expanded ? 50 : 3; elide: Text.ElideRight; font.pixelSize: 12 }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (card.entry.actions.some(a => a.id === "default")) card.store.invoke(card.entry.key, "default");
                    else card.expanded = !card.expanded;
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: actions.count > 0
            Repeater {
                id: actions
                model: card.entry.actions.filter(a => a.id !== "default")
                PanelAction {
                    required property var modelData
                    text: modelData.text
                    width: Math.min(implicitWidth, content.width)
                    onClicked: card.store.invoke(card.entry.key, modelData.id)
                }
            }
        }
    }
}
