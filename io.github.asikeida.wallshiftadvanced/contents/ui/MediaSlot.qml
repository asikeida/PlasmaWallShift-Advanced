/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

Item {
    id: root

    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize: Qt.size(0, 0)
    property bool activePlayback: false
    readonly property string mediaKind: state.mediaKind
    readonly property string sourcePath: state.sourcePath
    readonly property string sourceUrl: state.sourceUrl
    readonly property bool ready: state.ready
    readonly property bool failed: state.failed

    signal readyForTransition()
    signal loadFailed(string reason)
    signal playbackEnded()

    function load(entry) {
        unload();
        if (!entry)
            return;

        state.sourcePath = String(entry.path || "");
        state.sourceUrl = String(entry.url || entry.path || "");
        state.mediaKind = String(entry.kind || "image");
        state.failed = false;
        if (state.mediaKind === "video") {
            videoLoader.setSource(Qt.resolvedUrl("VideoSurface.qml"), {
                "desiredPlaying": root.activePlayback,
                "fillMode": root.videoFillMode()
            });
            videoLoader.active = true;
        } else {
            image.source = state.sourceUrl;
        }
    }

    function unload() {
        image.source = "";
        if (videoLoader.item)
            videoLoader.item.unload();
        videoLoader.active = false;
        state.sourcePath = "";
        state.sourceUrl = "";
        state.mediaKind = "none";
        state.ready = false;
        state.failed = false;
    }

    function restartVideo() {
        if (state.mediaKind === "video" && videoLoader.item)
            videoLoader.item.restart();
    }

    function videoFillMode() {
        if (root.fillMode === Image.Stretch)
            return 0;
        if (root.fillMode === Image.PreserveAspectFit)
            return 1;
        return 2;
    }

    function syncVideoProperties() {
        if (!videoLoader.item)
            return;

        videoLoader.item.desiredPlaying = root.activePlayback;
        videoLoader.item.fillMode = root.videoFillMode();
    }

    onActivePlaybackChanged: syncVideoProperties()
    onFillModeChanged: syncVideoProperties()

    QtObject {
        id: state

        property string sourcePath: ""
        property string sourceUrl: ""
        property string mediaKind: "none"
        property bool ready: false
        property bool failed: false
    }

    Image {
        id: image

        anchors.fill: parent
        visible: state.mediaKind === "image"
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        asynchronous: true
        cache: false
        autoTransform: true
        smooth: true
        onStatusChanged: {
            if (status === Image.Ready) {
                state.ready = true;
                root.readyForTransition();
            } else if (status === Image.Error) {
                state.failed = true;
                root.loadFailed("image-load-error");
            }
        }
    }

    Loader {
        id: videoLoader

        anchors.fill: parent
        visible: state.mediaKind === "video"
        active: false
        onLoaded: {
            root.syncVideoProperties();
            item.load(state.sourceUrl);
        }
    }

    Connections {
        target: videoLoader.item
        enabled: videoLoader.item !== null

        function onLoadFailed(reason) {
            state.failed = true;
            root.loadFailed(reason);
        }

        function onPlaybackEnded() {
            root.playbackEnded();
        }

        function onReadyForTransition() {
            state.ready = true;
            root.readyForTransition();
        }
    }
}
