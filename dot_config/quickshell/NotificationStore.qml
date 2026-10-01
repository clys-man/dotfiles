import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: store
    property var entries: []
    property var toastKeys: []
    property bool doNotDisturb: false
    property bool ready: false
    readonly property int count: entries.filter(e => !e.transient).length
    readonly property var toasts: toastKeys.map(key => entries.find(e => e.key === key)).filter(e => !!e)
    readonly property string session: String(Date.now())
    property bool centerOpen: false
    function plain(text) {
        return String(text || "").replace(/<br\s*\/?\s*>/gi, "\n").replace(/<\/p>/gi, "\n").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, "&");
    }
    function live(entry) { return server.trackedNotifications.values.find(n => entry.liveId > 0 && n.id === entry.liveId) || null; }
    function receive(notification) {
        notification.tracked = true;
        update(notification);
        if (!notification.lastGeneration && !doNotDisturb && !centerOpen) {
            const entry = entries.find(e => e.liveId === notification.id);
            if (entry) toastKeys = toastKeys.filter(k => k !== entry.key).concat([entry.key]).slice(-3);
        }
    }
    function update(notification) {
        const old = entries.find(e => e.liveId === notification.id || notification.lastGeneration && e.nativeId === notification.id);
        const entry = {
            key: old ? old.key : session + ":" + notification.id,
            liveId: notification.id,
            nativeId: notification.id,
            appName: String(notification.appName || "Notification"),
            appIcon: String(notification.appIcon || ""),
            summary: String(notification.summary || ""),
            body: plain(notification.body),
            created: old ? old.created : Date.now(),
            transient: notification.transient,
            critical: notification.urgency === NotificationUrgency.Critical,
            timeout: notification.expireTimeout < 0 ? 5000 : notification.expireTimeout,
            actions: notification.actions.map(a => ({id: a.identifier, text: String(a.text)}))
        };
        entries = [entry].concat(entries.filter(e => e.key !== entry.key)).slice(0, 100);
        save.restart();
    }
    function hideToast(key) {
        toastKeys = toastKeys.filter(k => k !== key);
        const entry = entries.find(e => e.key === key);
        if (entry && entry.transient) dismiss(key);
    }
    function remove(key) {
        toastKeys = toastKeys.filter(k => k !== key);
        entries = entries.filter(e => e.key !== key);
        save.restart();
    }
    function dismiss(key) {
        const entry = entries.find(e => e.key === key);
        if (!entry) return;
        const notification = live(entry);
        if (notification) notification.dismiss();
        remove(key);
    }
    function clear() { entries.slice().forEach(e => dismiss(e.key)); }
    function invoke(key, actionId) {
        const entry = entries.find(e => e.key === key);
        if (!entry) return;
        const notification = live(entry);
        if (!notification) return;
        const action = notification.actions.find(a => a.identifier === actionId);
        if (action) { const resident = notification.resident; action.invoke(); hideToast(key); if (!resident) dismiss(key); }
    }
    function icon(entry) {
        if (entry.appIcon.startsWith("/") || entry.appIcon.startsWith("file:")) return entry.appIcon;
        return Quickshell.iconPath(entry.appIcon || "dialog-information", true);
    }
    onDoNotDisturbChanged: { if (ready) save.restart(); if (doNotDisturb) toastKeys = []; }
    onCenterOpenChanged: { if (centerOpen) toastKeys = []; }
    Component.onCompleted: {
        try {
            const state = JSON.parse(history.text());
            const restored = Array.isArray(state.entries) ? state.entries.filter(e => e && typeof e.key === "string" && typeof e.summary === "string").slice(0, 100).map(e => Object.assign({}, e, {liveId: 0, actions: []})) : [];
            entries = entries.concat(restored.filter(e => !entries.some(current => current.key === e.key))).slice(0, 100);
            doNotDisturb = !!state.doNotDisturb;
        } catch (e) { console.warn("Could not read notification history."); }
        ready = true;
    }
    FileView {
        id: history
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/notifications.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
    }
    Timer {
        id: save
        interval: 150
        onTriggered: {
            if (store.ready) history.setText(JSON.stringify({doNotDisturb: store.doNotDisturb, entries: store.entries.filter(e => !e.transient).map(e => Object.assign({}, e, {liveId: 0, actions: []}))}));
        }
    }
    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: false
        onNotification: notification => store.receive(notification)
    }
    Instantiator {
        model: server.trackedNotifications
        delegate: Connections {
            required property var modelData
            target: modelData
            function onClosed(reason) {
                const entry = store.entries.find(e => e.liveId === modelData.id);
                if (entry) store.remove(entry.key);
            }
            function onSummaryChanged() { store.update(modelData); }
            function onBodyChanged() { store.update(modelData); }
            function onActionsChanged() { store.update(modelData); }
        }
    }
}
