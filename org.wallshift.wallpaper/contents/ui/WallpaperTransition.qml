/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

Item {
    id: root

    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize: Qt.size(0, 0)
    property int duration: 400
    property int transitionType: 1
    property int transitionDuration: 400
    property real wipeAngle: 0.0
    property real waveAngle: 0.0
    property int randomPool: 63
    property point transitionOrigin: Qt.point(0.5, 0.5)

    signal imageReady()
    signal imageError()

    QtObject {
        id: s
        property string activeLayer: "a"
        property string currentSource: ""
        property string pendingSource: ""
        property bool running: false
        property bool useShader: false
        property int effectiveShaderType: 2
        property real effectiveAngle: 0
    }

    // ---- image layers ----

    Image {
        id: imageA
        anchors.fill: parent
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        asynchronous: true
        cache: false
        autoTransform: true
        smooth: true
        opacity: 1.0
        z: 0
        onStatusChanged: _handleStatus("a", status)
    }

    Image {
        id: imageB
        anchors.fill: parent
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        asynchronous: true
        cache: false
        autoTransform: true
        smooth: true
        opacity: 0.0
        z: 1
        onStatusChanged: _handleStatus("b", status)
    }

    // ---- shader overlay (lazy-loaded) ----

    Loader {
        id: shaderLoader
        anchors.fill: parent
        z: 5
        active: false
    }

    // ---- image status handler ----

    function _handleStatus(layer, status) {
        if (s.running && s.activeLayer !== layer && status === Image.Ready) {
            if (s.effectiveShaderType === 0) {
                _finishInstantTransition(layer);
            } else if (s.useShader) {
                _doShaderTransition();
            } else {
                _doCrossfade(layer);
            }
        } else if (s.running && s.activeLayer !== layer && status === Image.Error) {
            _abort();
        } else if (!s.running && s.activeLayer === layer && status === Image.Ready) {
            root.imageReady();
        } else if (!s.running && status === Image.Error) {
            root.imageError();
        }
    }

    function _finishInstantTransition(newLayer) {
        var oldLayer = newLayer === "a" ? "b" : "a";
        s.activeLayer = newLayer;
        s.currentSource = s.pendingSource;
        s.pendingSource = "";
        s.running = false;

        if (oldLayer === "a") {
            imageA.source = "";
            imageA.opacity = 0.0;
            imageB.opacity = 1.0;
        } else {
            imageB.source = "";
            imageB.opacity = 0.0;
            imageA.opacity = 1.0;
        }

        root.imageReady();
    }

    // ---- public API ----

    function setImage(source, immediate) {
        if (!source) {
            _clear();
            return;
        }
        if (immediate || !s.currentSource) {
            _showImmediate(source);
        } else if (source === s.currentSource) {
            return;
        } else if (!s.running) {
            _beginTransition(source);
        }
    }

    // ---- clear ----

    function _clear() {
        _stopAll();
        s.running = false;
        s.currentSource = "";
        s.pendingSource = "";
        s.activeLayer = "a";
        s.useShader = false;
        imageB.source = "";
        imageB.opacity = 0;
        imageA.source = "";
        imageA.opacity = 1;
        shaderLoader.active = false;
    }

    // ---- immediate show ----

    function _showImmediate(source) {
        _stopAll();
        s.running = false;
        s.useShader = false;
        s.currentSource = source;
        s.pendingSource = "";
        s.activeLayer = "a";
        shaderLoader.active = false;
        imageB.source = "";
        imageB.opacity = 0;
        imageA.source = source;
        imageA.opacity = 1;
    }

    // ---- begin transition ----

    function _beginTransition(source) {
        s.running = true;
        s.pendingSource = source;
        var effectiveType = root.transitionType;
        if (effectiveType === 7) {
            effectiveType = _pickRandom();
            s.effectiveShaderType = effectiveType;
        } else {
            s.effectiveShaderType = effectiveType;
        }
        // Resolve per-effect angle
        s.effectiveAngle = 0;
        if (effectiveType === 3) s.effectiveAngle = root.wipeAngle;
        if (effectiveType === 4) s.effectiveAngle = root.waveAngle;
        s.useShader = effectiveType >= 2;
        if (s.activeLayer === "a") {
            imageB.source = source;
            imageB.opacity = 0;
        } else {
            imageA.source = source;
            imageA.opacity = 0;
        }
    }

    // ---- crossfade (type 1) ----

    function _doCrossfade(newLayer) {
        if (newLayer === "a") {
            fadeA.start();
        } else {
            fadeB.start();
        }
    }

    // ---- shader transition (types 2-6) ----

    function _doShaderTransition() {
        var oldImage = s.activeLayer === "a" ? imageA : imageB;
        var newImage = s.activeLayer === "a" ? imageB : imageA;

        imageA.opacity = 1.0;
        imageB.opacity = 1.0;

        shaderLoader.setSource(Qt.resolvedUrl("ShaderTransitionOverlay.qml"), {
            "oldSourceItem": oldImage,
            "newSourceItem": newImage,
            "transitionType": s.effectiveShaderType,
            "transitionDuration": root.transitionDuration,
            "transitionAngle": s.effectiveAngle,
            "transitionOrigin": root.transitionOrigin
        });
        shaderLoader.active = true;
    }

    function _finishShaderTransition() {
        shaderLoader.active = false;

        var newActive = s.activeLayer === "a" ? "b" : "a";
        s.activeLayer = newActive;
        s.currentSource = s.pendingSource;
        s.pendingSource = "";
        s.running = false;

        // Clean up the now-inactive layer
        if (newActive === "a") {
            imageB.source = "";
            imageB.opacity = 0.0;
            imageA.opacity = 1.0;
        } else {
            imageA.source = "";
            imageA.opacity = 0.0;
            imageB.opacity = 1.0;
        }

        root.imageReady();
    }

    function _pickRandom() {
        // Build list from bitmask: bit 0=fade(1), bit1=simple(2), bit2=wipe(3), bit3=wave(4), bit4=grow(5), bit5=outer(6)
        var pool = [];
        var mask = root.randomPool;
        if (mask & 1)  pool.push(1);
        if (mask & 2)  pool.push(2);
        if (mask & 4)  pool.push(3);
        if (mask & 8)  pool.push(4);
        if (mask & 16) pool.push(5);
        if (mask & 32) pool.push(6);
        if (pool.length === 0) return Math.floor(Math.random() * 6) + 1;
        return pool[Math.floor(Math.random() * pool.length)];
    }

    // ---- abort ----

    function _abort() {
        _stopAll();
        s.running = false;
        s.pendingSource = "";
        s.useShader = false;
        shaderLoader.active = false;
        root.imageError();
    }

    function _stopAll() {
        fadeOutA.stop(); fadeInA.stop();
        fadeOutB.stop(); fadeInB.stop();
        if (shaderLoader.item) {
            shaderLoader.item.stop();
        }
    }

    // ---- crossfade animations ----

    ParallelAnimation {
        id: fadeA
        NumberAnimation { id: fadeOutB; target: imageB; property: "opacity"; to: 0; duration: root.transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { id: fadeInA;  target: imageA; property: "opacity"; to: 1; duration: root.transitionDuration; easing.type: Easing.InOutQuad }
        onFinished: {
            imageB.source = "";
            s.activeLayer = "a";
            s.currentSource = s.pendingSource;
            s.pendingSource = "";
            s.running = false;
            root.imageReady();
        }
    }

    ParallelAnimation {
        id: fadeB
        NumberAnimation { id: fadeOutA; target: imageA; property: "opacity"; to: 0; duration: root.transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { id: fadeInB;  target: imageB; property: "opacity"; to: 1; duration: root.transitionDuration; easing.type: Easing.InOutQuad }
        onFinished: {
            imageA.source = "";
            s.activeLayer = "b";
            s.currentSource = s.pendingSource;
            s.pendingSource = "";
            s.running = false;
            root.imageReady();
        }
    }

    // ---- connection to loader item ----

    Connections {
        id: shaderConns
        target: shaderLoader.item
        enabled: shaderLoader.item !== null
        function onFinished() { _finishShaderTransition(); }
    }
}
