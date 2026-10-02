/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    property var images: []
    property var randomQueue: []
    property var scanFolders: []
    property string visibleImage: root.configuration.CurrentImage
    property string statusText: ""
    property string pendingCursorSource: ""
    property bool cursorLookupRunning: false
    readonly property string cursorLookupCommand: "kdotool getmouselocation --shell"
    property var zhText: ({
        "Move to Trash": "移到回收站",
        "Next Wallpaper": "下一张壁纸",
        "Open Current Image": "打开当前图片"
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

    function isImagePath(path) {
        return /\.(jpe?g|png|webp|bmp)$/i.test(String(path || ""));
    }

    function resetScanFolders() {
        root.scanFolders = root.folderPaths();
        root.randomQueue = [];
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
            wallpaperImage.sourceSize = Qt.size(0, 0);
        else
            wallpaperImage.sourceSize = Qt.size(root.screenWidth(), root.screenHeight());
    }

    function fileModifiedMs(value) {
        var date = new Date(value);
        var time = date.getTime();
        return isNaN(time) ? 0 : time;
    }

    function rebuildImages() {
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
                if (!root.isImagePath(path))
                    continue;

                seen[path] = true;
                found.push({
                    "path": path,
                    "name": String(model.get(j, "fileName") || path),
                    "modified": root.fileModifiedMs(model.get(j, "fileModified"))
                });
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
        var previousVisible = root.visibleImage;
        root.images = found;
        root.randomQueue = [];
        if (addedFolder)
            root.scanFolders = folders;

        var visibleIndex = root.indexOfImage(previousVisible);
        if (visibleIndex >= 0) {
            root.configuration.CurrentImage = previousVisible;
            root.configuration.CurrentIndex = visibleIndex;
            root.configuration.writeConfig();
            return ;
        }
        root.showConfiguredOrFirstImage();
    }

    function showConfiguredOrFirstImage() {
        if (root.images.length === 0) {
            root.visibleImage = "";
            root.configuration.CurrentImage = "";
            root.configuration.CurrentIndex = -1;
            root.configuration.writeConfig();
            wallpaperImage.setImage("", true);
            return ;
        }
        var current = root.normalizePath(root.configuration.CurrentImage);
        var index = root.indexOfImage(current);
        if (index < 0) {
            index = 0;
            current = root.images[index].path;
        }
        root.showImage(index, true);
    }

    function indexOfImage(path) {
        for (var i = 0; i < root.images.length; i++) {
            if (root.images[i].path === path)
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
        if (root.images.length === 0)
            return -1;

        if (String(root.configuration.RotationMode || "") === "random") {
            if (root.randomQueue.length === 0) {
                var indices = [];
                for (var i = 0; i < root.images.length; i++) {
                    indices.push(i);
                }
                root.randomQueue = root.shuffle(indices);
            }
            var currentIndex = root.indexOfImage(root.visibleImage);
            var next = root.randomQueue.shift();
            if (root.images.length > 1 && next === currentIndex) {
                root.randomQueue.push(next);
                next = root.randomQueue.shift();
            }
            return next;
        }
        return (Math.max(0, root.indexOfImage(root.visibleImage)) + 1) % root.images.length;
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
        root.pendingCursorSource = "";
        if (!root.cursorLookupRunning)
            return ;

        cursorExecutable.disconnectSource(root.cursorLookupCommand);
        root.cursorLookupRunning = false;
        cursorLookupTimeout.stop();
    }

    function requestCursorTransition(source) {
        root.pendingCursorSource = source;
        if (root.cursorLookupRunning)
            return ;

        root.cursorLookupRunning = true;
        cursorLookupTimeout.restart();
        cursorExecutable.connectSource(root.cursorLookupCommand);
    }

    function showImage(index, immediate) {
        if (index < 0 || index >= root.images.length)
            return ;

        var path = root.images[index].path;
        root.visibleImage = path;
        root.configuration.CurrentImage = path;
        root.configuration.CurrentIndex = index;
        root.configuration.writeConfig();
        root.updateSourceSize();
        var source = root.pathToUrl(path);
        var useCursor = !immediate && root.transitionUsesOrigin() && String(root.configuration.OriginMode || "") === "cursor";
        if (useCursor) {
            root.requestCursorTransition(source);
            return ;
        }
        root.cancelCursorLookup();
        wallpaperImage.transitionOrigin = immediate ? Qt.point(0.5, 0.5) : root.configuredTransitionOrigin();
        wallpaperImage.setImage(source, immediate || false);
    }

    function rotateNext(immediate) {
        root.showImage(root.nextIndex(), immediate || false);
    }

    function trashCurrentImage() {
        if (!root.visibleImage)
            return ;

        var trashPath = root.visibleImage;
        var currentIndex = root.indexOfImage(trashPath);
        var remaining = [];
        for (var i = 0; i < root.images.length; i++) {
            if (root.images[i].path !== trashPath)
                remaining.push(root.images[i]);

        }
        root.images = remaining;
        root.randomQueue = [];
        if (root.images.length === 0) {
            root.visibleImage = "";
            root.configuration.CurrentImage = "";
            root.configuration.CurrentIndex = -1;
            root.configuration.writeConfig();
            wallpaperImage.setImage("", true);
        } else {
            if (currentIndex < 0 || currentIndex >= root.images.length)
                currentIndex = 0;

            root.showImage(currentIndex, false);
        }
        executable.connectSource("gio trash " + root.shellQuote(trashPath));
    }

    Component.onCompleted: {
        root.updateSourceSize();
        root.resetScanFolders();
    }
    contextualActions: [
        PlasmaCore.Action {
            text: root.uiText("Next Wallpaper")
            icon.name: "view-refresh"
            enabled: root.images.length > 1
            onTriggered: root.rotateNext(false)
        },
        PlasmaCore.Action {
            text: root.uiText("Open Current Image")
            icon.name: "document-open"
            enabled: root.visibleImage.length > 0
            onTriggered: Qt.openUrlExternally(root.pathToUrl(root.visibleImage))
        },
        PlasmaCore.Action {
            text: root.uiText("Move to Trash")
            icon.name: "user-trash"
            enabled: root.visibleImage.length > 0
            onTriggered: root.trashCurrentImage()
        }
    ]

    Timer {
        id: rebuildTimer

        interval: 100
        repeat: false
        onTriggered: root.rebuildImages()
    }

    Timer {
        id: rotateTimer

        interval: Math.max(1, root.configuration.RotateSeconds || 1800) * 1000
        repeat: true
        running: root.images.length > 1
        onTriggered: root.rotateNext(false)
    }

    Timer {
        id: cursorLookupTimeout

        interval: 1500
        repeat: false
        onTriggered: {
            cursorExecutable.disconnectSource(root.cursorLookupCommand);
            root.cursorLookupRunning = false;
            var pendingSource = root.pendingCursorSource;
            root.pendingCursorSource = "";
            if (!pendingSource)
                return ;

            wallpaperImage.transitionOrigin = Qt.point(0.5, 0.5);
            wallpaperImage.setImage(pendingSource, false);
        }
    }

    Instantiator {
        id: folderModels

        model: root.scanFolders
        onObjectAdded: rebuildTimer.restart()
        onObjectRemoved: rebuildTimer.restart()

        delegate: FolderListModel {
            folder: root.pathToUrl(modelData)
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.BMP"]
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
            if (root.visibleImage.length > 0)
                wallpaperImage.setImage(root.pathToUrl(root.visibleImage), true);

        }

        function onRotateSecondsChanged() {
            rotateTimer.restart();
        }

        target: root.configuration
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
            var pendingSource = root.pendingCursorSource;
            root.pendingCursorSource = "";
            if (!pendingSource)
                return ;

            var mode = String(root.configuration.OriginMode || "");
            wallpaperImage.transitionOrigin = mode === "cursor" ? root.normalizedCursorOrigin(data && data["stdout"] ? data["stdout"] : "") : root.configuredTransitionOrigin();
            wallpaperImage.setImage(pendingSource, false);
        }
    }

    WallpaperTransition {
        id: wallpaperImage

        anchors.fill: parent
        z: 1
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
        onImageError: root.rotateNext(true)
    }

}
