/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import "EasingUtils.js" as EasingUtils
import QtQuick

Item {
    id: root

    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize: Qt.size(0, 0)
    property bool playbackEnabled: true
    property int duration: 400
    property int transitionType: 1
    property int transitionDuration: 400
    property real wipeAngle: 0
    property real waveAngle: 0
    property int randomPool: 1023
    property point transitionOrigin: Qt.point(0.5, 0.5)
    property string easingMode: "custom"
    property real bezierX1: 0.43
    property real bezierY1: 1.19
    property real bezierX2: 1
    property real bezierY2: 0.4
    property real edgeSoftness: 0.05
    property real waveAmplitude: 0.05
    property real waveFrequency: 40
    property real stripeCount: 12
    property real stripeAngle: 30
    property real pixelSize: 0.35
    property real irisScale: 0.2
    property real portalTwist: 1.2
    readonly property var easingCurve: EasingUtils.curve(easingMode, bezierX1, bezierY1, bezierX2, bezierY2)
    readonly property string currentKind: s.currentEntry ? String(s.currentEntry.kind || "image") : "none"
    readonly property string currentPath: _entryKey(s.currentEntry)

    signal imageReady()
    signal imageError()
    signal mediaError(string path, string reason)
    signal playbackEnded(string path)

    function _entryKey(entry) {
        return entry ? String(entry.path || entry.url || "") : "";
    }

    function _normalizedEntry(entry) {
        if (!entry)
            return null;
        if (typeof entry === "string") {
            return {
                "path": entry,
                "url": entry,
                "kind": "image"
            };
        }
        return {
            "path": String(entry.path || entry.url || ""),
            "url": String(entry.url || entry.path || ""),
            "kind": String(entry.kind || "image"),
            "name": String(entry.name || entry.path || "")
        };
    }

    function _handleReady(layer) {
        if (s.running && s.activeLayer !== layer) {
            if (s.effectiveShaderType === 0)
                _finishInstantTransition(layer);
            else if (s.useShader)
                _doShaderTransition();
            else
                _doCrossfade(layer);
        } else if (!s.running && s.activeLayer === layer) {
            root.imageReady();
        }
    }

    function _handleError(layer, reason) {
        if (s.running && s.activeLayer !== layer)
            _abort(reason);
        else if (!s.running && s.activeLayer === layer) {
            root.mediaError(root.currentPath, reason);
            root.imageError();
        }
    }

    function _handlePlaybackEnded(layer) {
        if (!s.running && s.activeLayer === layer)
            root.playbackEnded(root.currentPath);
    }

    function _finishInstantTransition(newLayer) {
        _completeTransition(newLayer);
    }

    function setImage(source, immediate) {
        setMedia({
            "path": String(source || ""),
            "url": String(source || ""),
            "kind": "image"
        }, immediate);
    }

    function setMedia(entry, immediate) {
        var normalized = _normalizedEntry(entry);
        var key = _entryKey(normalized);
        if (!key) {
            _clear();
            return;
        }
        if (immediate || !root.currentPath)
            _showImmediate(normalized);
        else if (s.running)
            s.queuedEntry = key === _entryKey(s.pendingEntry) ? null : normalized;
        else if (key !== root.currentPath)
            _beginTransition(normalized);
    }

    function restartActiveVideo() {
        if (s.activeLayer === "a")
            slotA.restartVideo();
        else
            slotB.restartVideo();
    }

    function _clear() {
        _stopAll();
        s.running = false;
        s.animating = false;
        s.currentEntry = null;
        s.pendingEntry = null;
        s.queuedEntry = null;
        s.activeLayer = "a";
        s.useShader = false;
        slotB.unload();
        slotB.opacity = 0;
        slotA.unload();
        slotA.opacity = 1;
        shaderLoader.active = false;
    }

    function _showImmediate(entry) {
        _stopAll();
        s.running = false;
        s.animating = false;
        s.useShader = false;
        s.currentEntry = entry;
        s.pendingEntry = null;
        s.queuedEntry = null;
        s.activeLayer = "a";
        shaderLoader.active = false;
        slotB.unload();
        slotB.opacity = 0;
        slotA.opacity = 1;
        slotA.load(entry);
    }

    function _beginTransition(entry) {
        s.running = true;
        s.animating = false;
        s.pendingEntry = entry;
        var effectiveType = root.transitionType;
        if (effectiveType === 7)
            effectiveType = _pickRandom();
        s.effectiveShaderType = effectiveType;
        s.effectiveAngle = 0;
        if (effectiveType === 3)
            s.effectiveAngle = root.wipeAngle;
        else if (effectiveType === 4)
            s.effectiveAngle = root.waveAngle;
        else if (effectiveType === 8)
            s.effectiveAngle = root.stripeAngle;
        s.effectiveOrigin = root.transitionOrigin;
        s.useShader = effectiveType !== 0 && effectiveType !== 1;
        if (s.activeLayer === "a") {
            slotB.opacity = 0;
            slotB.load(entry);
        } else {
            slotA.opacity = 0;
            slotA.load(entry);
        }
    }

    function _doCrossfade(newLayer) {
        s.animating = true;
        if (newLayer === "a")
            fadeA.start();
        else
            fadeB.start();
    }

    function _doShaderTransition() {
        s.animating = true;
        var oldSlot = s.activeLayer === "a" ? slotA : slotB;
        var newSlot = s.activeLayer === "a" ? slotB : slotA;
        slotA.opacity = 1;
        slotB.opacity = 1;
        shaderLoader.setSource(Qt.resolvedUrl("ShaderTransitionOverlay.qml"), {
            "oldSourceItem": oldSlot,
            "newSourceItem": newSlot,
            "transitionType": s.effectiveShaderType,
            "transitionDuration": root.transitionDuration,
            "transitionAngle": s.effectiveAngle,
            "transitionOrigin": s.effectiveOrigin,
            "easingCurve": root.easingCurve,
            "edgeSoftness": root.edgeSoftness,
            "waveAmplitude": root.waveAmplitude,
            "waveFrequency": root.waveFrequency,
            "stripeCount": root.stripeCount,
            "pixelSize": root.pixelSize,
            "irisScale": root.irisScale,
            "portalTwist": root.portalTwist
        });
        shaderLoader.active = true;
    }

    function _finishShaderTransition() {
        shaderLoader.active = false;
        _completeTransition(s.activeLayer === "a" ? "b" : "a");
    }

    function _pickRandom() {
        var pool = [];
        var mask = root.randomPool;
        if (mask & 1)
            pool.push(1);
        if (mask & 2)
            pool.push(2);
        if (mask & 4)
            pool.push(3);
        if (mask & 8)
            pool.push(4);
        if (mask & 16)
            pool.push(5);
        if (mask & 32)
            pool.push(6);
        if (mask & 64)
            pool.push(8);
        if (mask & 128)
            pool.push(9);
        if (mask & 256)
            pool.push(10);
        if (mask & 512)
            pool.push(11);
        return pool.length > 0 ? pool[Math.floor(Math.random() * pool.length)] : 1;
    }

    function _completeTransition(newActive) {
        var oldSlot = newActive === "a" ? slotB : slotA;
        s.activeLayer = newActive;
        s.currentEntry = s.pendingEntry;
        s.pendingEntry = null;
        s.running = false;
        s.animating = false;
        oldSlot.unload();
        if (newActive === "a") {
            slotB.opacity = 0;
            slotA.opacity = 1;
        } else {
            slotA.opacity = 0;
            slotB.opacity = 1;
        }
        root.imageReady();
        _startQueuedTransition();
    }

    function _startQueuedTransition() {
        var nextEntry = s.queuedEntry;
        s.queuedEntry = null;
        if (!nextEntry || _entryKey(nextEntry) === root.currentPath)
            return;
        Qt.callLater(function() {
            root._beginTransition(nextEntry);
        });
    }

    function _abort(reason) {
        var failedPath = _entryKey(s.pendingEntry);
        var nextEntry = s.queuedEntry;
        _stopAll();
        s.running = false;
        s.animating = false;
        s.pendingEntry = null;
        s.queuedEntry = null;
        s.useShader = false;
        shaderLoader.active = false;
        if (s.activeLayer === "a") {
            slotB.unload();
            slotB.opacity = 0;
            slotA.opacity = 1;
        } else {
            slotA.unload();
            slotA.opacity = 0;
            slotB.opacity = 1;
        }
        root.mediaError(failedPath, reason);
        root.imageError();
        if (nextEntry && _entryKey(nextEntry) !== root.currentPath) {
            Qt.callLater(function() {
                root._beginTransition(nextEntry);
            });
        }
    }

    function _stopAll() {
        fadeA.stop();
        fadeB.stop();
        if (shaderLoader.item)
            shaderLoader.item.stop();
    }

    QtObject {
        id: s

        property string activeLayer: "a"
        property var currentEntry: null
        property var pendingEntry: null
        property var queuedEntry: null
        property bool running: false
        property bool animating: false
        property bool useShader: false
        property int effectiveShaderType: 2
        property real effectiveAngle: 0
        property point effectiveOrigin: Qt.point(0.5, 0.5)
    }

    MediaSlot {
        id: slotA

        anchors.fill: parent
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        activePlayback: root.playbackEnabled && s.activeLayer === "a" && !s.animating
        opacity: 1
        z: 0
        onLoadFailed: function(reason) {
            root._handleError("a", reason);
        }
        onPlaybackEnded: root._handlePlaybackEnded("a")
        onReadyForTransition: root._handleReady("a")
    }

    MediaSlot {
        id: slotB

        anchors.fill: parent
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        activePlayback: root.playbackEnabled && s.activeLayer === "b" && !s.animating
        opacity: 0
        z: 1
        onLoadFailed: function(reason) {
            root._handleError("b", reason);
        }
        onPlaybackEnded: root._handlePlaybackEnded("b")
        onReadyForTransition: root._handleReady("b")
    }

    Loader {
        id: shaderLoader

        anchors.fill: parent
        z: 5
        active: false
    }

    ParallelAnimation {
        id: fadeA

        onFinished: root._completeTransition("a")

        NumberAnimation {
            target: slotB
            property: "opacity"
            to: 0
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }

        NumberAnimation {
            target: slotA
            property: "opacity"
            to: 1
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }
    }

    ParallelAnimation {
        id: fadeB

        onFinished: root._completeTransition("b")

        NumberAnimation {
            target: slotA
            property: "opacity"
            to: 0
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }

        NumberAnimation {
            target: slotB
            property: "opacity"
            to: 1
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }
    }

    Connections {
        target: shaderLoader.item
        enabled: shaderLoader.item !== null

        function onFinished() {
            root._finishShaderTransition();
        }
    }
}
