/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Window
import "MediaUtils.js" as MediaUtils
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    property var mediaItems: []
    property var randomQueue: []
    property var scanFolders: []
    property string visibleMedia: root.configuration.CurrentMedia || root.configuration.CurrentImage
    property var failedMediaPaths: ({})
    property string statusText: ""
    property var pendingCursorEntry: null
    property bool cursorLookupRunning: false
    property bool nextTriggerWatcherReady: false
    readonly property int visibleMediaIndex: root.indexOfMedia(root.visibleMedia)
    readonly property string visibleMediaKind: visibleMediaIndex >= 0 ? root.mediaItems[visibleMediaIndex].kind : "none"
    readonly property string cursorLookupCommand: "kdotool getmouselocation --shell"
    property var zhText: ({
        "Move to Trash": "移到回收站",
        "Next Wallpaper": "下一张壁纸",
        "No playable media": "没有可播放的媒体",
        "Open Current Media": "打开当前媒体"
    })

    function uiText(message) {
        var translated = i18nd("plasma_wallpaper_io.github.asikeida.wallshiftadvanced", message);
        if (Qt.locale().name.indexOf("zh") === 0 && zhText[message])
            translated = zhText[message];

        return translated;
    }

    function folderPaths() {
        var seen = {
        };
        return String(root.configuration.WallpaperPaths || "").split(/\r?\n/).map(function(path) {
            return String(path || "").trim();
        }).filter(function(path) {
            if (path.length === 0 || seen[path])
                return false;

            seen[path] = true;
            return true;
        });
    }

    function pathToUrl(path) {
        if (!path || path.length === 0)
            return "";

        if (String(path).indexOf("file://") === 0)
            return path;

        return "file://" + String(path).split("/").map(function(part) {
            return encodeURIComponent(part);
        }).join("/");
    }

    function normalizePath(path) {
        var text = String(path || "");
        if (text.indexOf("file://") === 0)
            return decodeURIComponent(text.substring(7));

        return text;
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
    }

    function resetScanFolders() {
        root.scanFolders = root.folderPaths();
        root.randomQueue = [];
        root.failedMediaPaths = {};
        root.statusText = "";
        rebuildTimer.restart();
    }

    function screenWidth() {
        return Math.max(1, Math.round(root.width * Screen.devicePixelRatio));
    }

    function screenHeight() {
        return Math.max(1, Math.round(root.height * Screen.devicePixelRatio));
    }

    function updateSourceSize() {
        if (root.configuration.FillMode === Image.Tile)
            wallpaperMedia.sourceSize = Qt.size(0, 0);
        else
            wallpaperMedia.sourceSize = Qt.size(root.screenWidth(), root.screenHeight());
    }

    function fileModifiedMs(value) {
        var date = new Date(value);
        var time = date.getTime();
        return isNaN(time) ? 0 : time;
    }

    function rebuildMedia() {
        var found = [];
        var seen = {
        };
        var folderSeen = {
        };
        var folders = root.scanFolders.slice();
        var addedFolder = false;
        for (var f = 0; f < folders.length; f++) {
            folderSeen[folders[f]] = true;
        }
        for (var i = 0; i < folderModels.count; i++) {
            var model = folderModels.objectAt(i);
            if (!model)
                continue;

            for (var j = 0; j < model.count; j++) {
                var path = root.normalizePath(model.get(j, "filePath"));
                if (!path || seen[path])
                    continue;

                if (model.get(j, "fileIsDir")) {
                    if (!folderSeen[path]) {
                        folderSeen[path] = true;
                        folders.push(path);
                        addedFolder = true;
                    }
                    continue;
                }
                if (!MediaUtils.isSupportedPath(path, root.configuration.IncludeImages, root.configuration.IncludeVideos))
                    continue;

                seen[path] = true;
                found.push(MediaUtils.makeEntry(path, String(model.get(j, "fileName") || path), root.fileModifiedMs(model.get(j, "fileModified")), root.pathToUrl(path)));
            }
        }
        var mode = String(root.configuration.RotationMode || "name_asc");
        if (mode === "mtime_desc")
            found.sort(function(a, b) {
            return b.modified - a.modified || a.name.localeCompare(b.name);
        });
        else if (mode === "mtime_asc")
            found.sort(function(a, b) {
            return a.modified - b.modified || a.name.localeCompare(b.name);
        });
        else
            found.sort(function(a, b) {
            return a.name.localeCompare(b.name) || a.path.localeCompare(b.path);
        });
        var previousVisible = root.visibleMedia;
        root.mediaItems = found;
        root.randomQueue = [];
        root.failedMediaPaths = {};
        if (addedFolder)
            root.scanFolders = folders;

        var visibleIndex = root.indexOfMedia(previousVisible);
        if (visibleIndex >= 0) {
            root.configuration.CurrentMedia = previousVisible;
            root.configuration.CurrentIndex = visibleIndex;
            root.configuration.writeConfig();
            return ;
        }
        root.showConfiguredOrFirstMedia();
    }

    function showConfiguredOrFirstMedia() {
        if (root.mediaItems.length === 0) {
            root.visibleMedia = "";
            root.configuration.CurrentMedia = "";
            root.configuration.CurrentIndex = -1;
            root.configuration.writeConfig();
            wallpaperMedia.setMedia(null, true);
            return ;
        }
        var current = root.normalizePath(root.configuration.CurrentMedia || root.configuration.CurrentImage);
        var index = root.indexOfMedia(current);
        if (index < 0) {
            index = 0;
            current = root.mediaItems[index].path;
        }
        root.showMedia(index, true);
    }

    function indexOfMedia(path) {
        for (var i = 0; i < root.mediaItems.length; i++) {
            if (root.mediaItems[i].path === path)
                return i;

        }
        return -1;
    }

    function shuffle(values) {
        var copy = values.slice();
        for (var i = copy.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = copy[i];
            copy[i] = copy[j];
            copy[j] = tmp;
        }
        return copy;
    }

    function nextIndex() {
        if (root.mediaItems.length === 0)
            return -1;

        if (String(root.configuration.RotationMode || "") === "random") {
            if (root.randomQueue.length === 0) {
                var indices = [];
                for (var i = 0; i < root.mediaItems.length; i++) {
                    if (!root.failedMediaPaths[root.mediaItems[i].path])
                        indices.push(i);
                }
                root.randomQueue = root.shuffle(indices);
            }
            var currentIndex = root.indexOfMedia(root.visibleMedia);
            var next = root.randomQueue.shift();
            if (root.randomQueue.length > 0 && next === currentIndex) {
                root.randomQueue.push(next);
                next = root.randomQueue.shift();
            }
            return next === undefined ? -1 : next;
        }
        var start = Math.max(0, root.indexOfMedia(root.visibleMedia));
        for (var offset = 1; offset <= root.mediaItems.length; ++offset) {
            var candidate = (start + offset) % root.mediaItems.length;
            if (!root.failedMediaPaths[root.mediaItems[candidate].path])
                return candidate;
        }
        return -1;
    }

    function randomTransitionOrigin() {
        var margin = 0.15;
        var span = 1 - margin * 2;
        return Qt.point(margin + Math.random() * span, margin + Math.random() * span);
    }

    function configuredTransitionOrigin() {
        var mode = String(root.configuration.OriginMode || "random");
        if (mode === "center")
            return Qt.point(0.5, 0.5);

        if (mode === "custom")
            return Qt.point(Math.max(0, Math.min(1, root.configuration.OriginX)), Math.max(0, Math.min(1, root.configuration.OriginY)));

        if (mode === "cursor")
            return Qt.point(0.5, 0.5);

        return root.randomTransitionOrigin();
    }

    function transitionUsesOrigin() {
        var type = Number(root.configuration.TransitionType);
        return type === 5 || type === 6 || type === 7 || type === 10 || type === 11;
    }

    function normalizedCursorOrigin(output) {
        var text = String(output || "");
        var xMatch = text.match(/^X=(-?[0-9]+(?:\.[0-9]+)?)$/m);
        var yMatch = text.match(/^Y=(-?[0-9]+(?:\.[0-9]+)?)$/m);
        if (!xMatch || !yMatch)
            return Qt.point(0.5, 0.5);

        var globalX = Number(xMatch[1]);
        var globalY = Number(yMatch[1]);
        var virtualX = Number(Screen.virtualX);
        var virtualY = Number(Screen.virtualY);
        if (!isFinite(globalX) || !isFinite(globalY))
            return Qt.point(0.5, 0.5);

        if (!isFinite(virtualX))
            virtualX = 0;

        if (!isFinite(virtualY))
            virtualY = 0;

        var normalizedX = (globalX - virtualX) / Math.max(1, root.width);
        var normalizedY = (globalY - virtualY) / Math.max(1, root.height);
        return Qt.point(Math.max(0, Math.min(1, normalizedX)), Math.max(0, Math.min(1, normalizedY)));
    }

    function cancelCursorLookup() {
        root.pendingCursorEntry = null;
        if (!root.cursorLookupRunning)
            return ;

        cursorExecutable.disconnectSource(root.cursorLookupCommand);
        root.cursorLookupRunning = false;
        cursorLookupTimeout.stop();
    }

    function requestCursorTransition(entry) {
        root.pendingCursorEntry = entry;
        if (root.cursorLookupRunning)
            return ;

        root.cursorLookupRunning = true;
        cursorLookupTimeout.restart();
        cursorExecutable.connectSource(root.cursorLookupCommand);
    }

    function showMedia(index, immediate) {
        if (index < 0 || index >= root.mediaItems.length)
            return ;

        var entry = root.mediaItems[index];
        var path = entry.path;
        root.visibleMedia = path;
        root.configuration.CurrentMedia = path;
        if (entry.kind === "image")
            root.configuration.CurrentImage = path;
        root.configuration.CurrentIndex = index;
        root.configuration.writeConfig();
        root.updateSourceSize();
        var useCursor = !immediate && root.transitionUsesOrigin() && String(root.configuration.OriginMode || "") === "cursor";
        if (useCursor) {
            root.requestCursorTransition(entry);
            return ;
        }
        root.cancelCursorLookup();
        wallpaperMedia.transitionOrigin = immediate ? Qt.point(0.5, 0.5) : root.configuredTransitionOrigin();
        wallpaperMedia.setMedia(entry, immediate || false);
    }

    function rotateNext(immediate) {
        root.showMedia(root.nextIndex(), immediate || false);
    }

    function advanceAfterPlayback() {
        var index = root.nextIndex();
        if (index < 0)
            return;

        if (root.mediaItems[index].path === wallpaperMedia.currentPath)
            wallpaperMedia.restartActiveVideo();
        else
            root.showMedia(index, false);
    }

    function trashCurrentMedia() {
        if (!root.visibleMedia)
            return ;

        var trashPath = root.visibleMedia;
        var currentIndex = root.indexOfMedia(trashPath);
        var remaining = [];
        for (var i = 0; i < root.mediaItems.length; i++) {
            if (root.mediaItems[i].path !== trashPath)
                remaining.push(root.mediaItems[i]);

        }
        root.mediaItems = remaining;
        root.randomQueue = [];
        if (root.mediaItems.length === 0) {
            root.visibleMedia = "";
            root.configuration.CurrentMedia = "";
            root.configuration.CurrentIndex = -1;
            root.configuration.writeConfig();
            wallpaperMedia.setMedia(null, true);
        } else {
            if (currentIndex < 0 || currentIndex >= root.mediaItems.length)
                currentIndex = 0;

            root.showMedia(currentIndex, false);
        }
        executable.connectSource("gio trash " + root.shellQuote(trashPath));
    }

    function handleMediaError(path, reason) {
        var failed = {};
        var count = 0;
        for (var existingPath in root.failedMediaPaths) {
            if (root.failedMediaPaths[existingPath]) {
                failed[existingPath] = true;
                count += 1;
            }
        }
        if (path && !failed[path]) {
            failed[path] = true;
            count += 1;
        }
        root.failedMediaPaths = failed;
        root.randomQueue = [];
        if (count >= root.mediaItems.length) {
            root.statusText = root.uiText("No playable media") + "\n" + reason;
            return;
        }
        if (path && path !== root.visibleMedia)
            return;

        Qt.callLater(function() {
            root.rotateNext(true);
        });
    }

    Component.onCompleted: {
        root.updateSourceSize();
        root.resetScanFolders();
    }
    contextualActions: [
        PlasmaCore.Action {
            text: root.uiText("Next Wallpaper")
            icon.name: "view-refresh"
            enabled: root.mediaItems.length > 1
            onTriggered: root.rotateNext(false)
        },
        PlasmaCore.Action {
            text: root.uiText("Open Current Media")
            icon.name: "document-open"
            enabled: root.visibleMedia.length > 0
            onTriggered: Qt.openUrlExternally(root.pathToUrl(root.visibleMedia))
        },
        PlasmaCore.Action {
            text: root.uiText("Move to Trash")
            icon.name: "user-trash"
            enabled: root.visibleMedia.length > 0
            onTriggered: root.trashCurrentMedia()
        }
    ]

    Timer {
        id: rebuildTimer

        interval: 100
        repeat: false
        onTriggered: root.rebuildMedia()
    }

    Timer {
        id: rotateTimer

        interval: Math.max(1, root.configuration.RotateSeconds || 1800) * 1000
        repeat: true
        running: root.mediaItems.length > 1 && root.visibleMediaKind !== "video"
        onTriggered: root.rotateNext(false)
    }

    Timer {
        id: cursorLookupTimeout

        interval: 1500
        repeat: false
        onTriggered: {
            cursorExecutable.disconnectSource(root.cursorLookupCommand);
            root.cursorLookupRunning = false;
            var pendingEntry = root.pendingCursorEntry;
            root.pendingCursorEntry = null;
            if (!pendingEntry)
                return ;

            wallpaperMedia.transitionOrigin = Qt.point(0.5, 0.5);
            wallpaperMedia.setMedia(pendingEntry, false);
        }
    }

    Instantiator {
        id: folderModels

        model: root.scanFolders
        onObjectAdded: rebuildTimer.restart()
        onObjectRemoved: rebuildTimer.restart()

        delegate: FolderListModel {
            folder: root.pathToUrl(modelData)
            nameFilters: MediaUtils.nameFilters(root.configuration.IncludeImages, root.configuration.IncludeVideos)
            showDirs: true
            showFiles: true
            showHidden: false
            sortField: FolderListModel.Name
            onCountChanged: rebuildTimer.restart()
            onStatusChanged: rebuildTimer.restart()
        }

    }

    Connections {
        function onWallpaperPathsChanged() {
            root.resetScanFolders();
        }

        function onRotationModeChanged() {
            rebuildTimer.restart();
        }

        function onFillModeChanged() {
            root.updateSourceSize();
            if (root.visibleMediaIndex >= 0)
                wallpaperMedia.setMedia(root.mediaItems[root.visibleMediaIndex], true);

        }

        function onIncludeImagesChanged() {
            root.resetScanFolders();
        }

        function onIncludeVideosChanged() {
            root.resetScanFolders();
        }

        function onRotateSecondsChanged() {
            rotateTimer.restart();
        }

        target: root.configuration
    }

    FolderListModel {
        id: nextTriggerModel

        folder: root.pathToUrl(StandardPaths.writableLocation(StandardPaths.RuntimeLocation))
        nameFilters: ["wallshift-advanced-next-*"]
        showDirs: false
        showFiles: true
        showHidden: true
    }

    Instantiator {
        model: nextTriggerModel
        onObjectAdded: function(index, object) {
            if (root.nextTriggerWatcherReady && root.mediaItems.length > 1)
                root.rotateNext(false);
        }

        delegate: QtObject {}
    }

    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: root.nextTriggerWatcherReady = true
    }

    Rectangle {
        anchors.fill: parent
        color: root.configuration.Color
    }

    Plasma5Support.DataSource {
        id: executable

        engine: "executable"
        connectedSources: []
        onNewData: function(source) {
            executable.disconnectSource(source);
            root.resetScanFolders();
        }
    }

    Plasma5Support.DataSource {
        id: cursorExecutable

        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            cursorExecutable.disconnectSource(source);
            root.cursorLookupRunning = false;
            cursorLookupTimeout.stop();
            var pendingEntry = root.pendingCursorEntry;
            root.pendingCursorEntry = null;
            if (!pendingEntry)
                return ;

            var mode = String(root.configuration.OriginMode || "");
            wallpaperMedia.transitionOrigin = mode === "cursor" ? root.normalizedCursorOrigin(data && data["stdout"] ? data["stdout"] : "") : root.configuredTransitionOrigin();
            wallpaperMedia.setMedia(pendingEntry, false);
        }
    }

    WallpaperTransition {
        id: wallpaperMedia

        anchors.fill: parent
        z: 1
        playbackEnabled: root.visible
        fillMode: root.configuration.FillMode
        transitionType: root.configuration.TransitionType
        transitionDuration: root.configuration.TransitionDuration
        wipeAngle: root.configuration.WipeAngle
        waveAngle: root.configuration.WaveAngle
        easingMode: root.configuration.EasingMode
        bezierX1: root.configuration.BezierX1
        bezierY1: root.configuration.BezierY1
        bezierX2: root.configuration.BezierX2
        bezierY2: root.configuration.BezierY2
        edgeSoftness: root.configuration.EdgeSoftness
        waveAmplitude: root.configuration.WaveAmplitude
        waveFrequency: root.configuration.WaveFrequency
        stripeCount: root.configuration.StripeCount
        stripeAngle: root.configuration.StripeAngle
        pixelSize: root.configuration.PixelSize
        irisScale: root.configuration.IrisScale
        portalTwist: root.configuration.PortalTwist
        randomPool: root.configuration.RandomPool
        onMediaError: function(path, reason) {
            root.handleMediaError(path, reason);
        }
        onImageReady: root.statusText = ""
        onPlaybackEnded: root.advanceAfterPlayback()
    }

    Text {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 640)
        z: 2
        visible: root.statusText.length > 0
        text: root.statusText
        color: "white"
        style: Text.Outline
        styleColor: "black"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

}
