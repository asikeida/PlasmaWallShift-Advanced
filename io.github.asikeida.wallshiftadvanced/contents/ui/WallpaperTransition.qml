/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import "EasingUtils.js" as EasingUtils
import QtQuick

Item {
    // ---- image layers ----
    // ---- shader overlay (lazy-loaded) ----
    // ---- image status handler ----
    // ---- public API ----
    // ---- clear ----
    // ---- immediate show ----
    // ---- begin transition ----
    // ---- crossfade (type 1) ----
    // ---- shader transition (types 2-6) ----
    // ---- abort ----
    // ---- crossfade animations ----
    // ---- connection to loader item ----

    id: root

    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize: Qt.size(0, 0)
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

    signal imageReady()
    signal imageError()

    function _handleStatus(layer, status) {
        if (s.running && s.activeLayer !== layer && status === Image.Ready) {
            if (s.effectiveShaderType === 0)
                _finishInstantTransition(layer);
            else if (s.useShader)
                _doShaderTransition();
            else
                _doCrossfade(layer);
        } else if (s.running && s.activeLayer !== layer && status === Image.Error)
            _abort();
        else if (!s.running && s.activeLayer === layer && status === Image.Ready)
            root.imageReady();
        else if (!s.running && status === Image.Error)
            root.imageError();
    }

    function _finishInstantTransition(newLayer) {
        _completeTransition(newLayer);
    }

    function setImage(source, immediate) {
        if (!source) {
            _clear();
            return ;
        }
        if (immediate || !s.currentSource)
            _showImmediate(source);
        else if (source === s.currentSource || source === s.pendingSource)
            return ;
        else if (s.running)
            s.queuedSource = source;
        else
            _beginTransition(source);
    }

    function _clear() {
        _stopAll();
        s.running = false;
        s.currentSource = "";
        s.pendingSource = "";
        s.queuedSource = "";
        s.activeLayer = "a";
        s.useShader = false;
        imageB.source = "";
        imageB.opacity = 0;
        imageA.source = "";
        imageA.opacity = 1;
        shaderLoader.active = false;
    }

    function _showImmediate(source) {
        _stopAll();
        s.running = false;
        s.useShader = false;
        s.currentSource = source;
        s.pendingSource = "";
        s.queuedSource = "";
        s.activeLayer = "a";
        shaderLoader.active = false;
        imageB.source = "";
        imageB.opacity = 0;
        imageA.source = source;
        imageA.opacity = 1;
    }

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
        if (effectiveType === 3)
            s.effectiveAngle = root.wipeAngle;

        if (effectiveType === 4)
            s.effectiveAngle = root.waveAngle;

        if (effectiveType === 8)
            s.effectiveAngle = root.stripeAngle;

        s.effectiveOrigin = root.transitionOrigin;
        s.useShader = effectiveType !== 0 && effectiveType !== 1;
        if (s.activeLayer === "a") {
            imageB.source = source;
            imageB.opacity = 0;
        } else {
            imageA.source = source;
            imageA.opacity = 0;
        }
    }

    function _doCrossfade(newLayer) {
        if (newLayer === "a")
            fadeA.start();
        else
            fadeB.start();
    }

    function _doShaderTransition() {
        var oldImage = s.activeLayer === "a" ? imageA : imageB;
        var newImage = s.activeLayer === "a" ? imageB : imageA;
        imageA.opacity = 1;
        imageB.opacity = 1;
        shaderLoader.setSource(Qt.resolvedUrl("ShaderTransitionOverlay.qml"), {
            "oldSourceItem": oldImage,
            "newSourceItem": newImage,
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
        var newActive = s.activeLayer === "a" ? "b" : "a";
        _completeTransition(newActive);
    }

    function _pickRandom() {
        // Bits map to fade, simple, wipe, wave, grow, outer, stripes,
        // pixelate, iris and portal, respectively.
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

        if (pool.length === 0)
            return 1;

        return pool[Math.floor(Math.random() * pool.length)];
    }

    function _completeTransition(newActive) {
        s.activeLayer = newActive;
        s.currentSource = s.pendingSource;
        s.pendingSource = "";
        s.running = false;
        if (newActive === "a") {
            imageB.source = "";
            imageB.opacity = 0;
            imageA.opacity = 1;
        } else {
            imageA.source = "";
            imageA.opacity = 0;
            imageB.opacity = 1;
        }
        root.imageReady();
        _startQueuedTransition();
    }

    function _startQueuedTransition() {
        var nextSource = s.queuedSource;
        s.queuedSource = "";
        if (!nextSource || nextSource === s.currentSource)
            return ;

        Qt.callLater(function() {
            root._beginTransition(nextSource);
        });
    }

    function _abort() {
        _stopAll();
        s.running = false;
        s.pendingSource = "";
        s.useShader = false;
        shaderLoader.active = false;
        if (s.activeLayer === "a") {
            imageB.source = "";
            imageB.opacity = 0;
            imageA.opacity = 1;
        } else {
            imageA.source = "";
            imageA.opacity = 0;
            imageB.opacity = 1;
        }
        if (s.queuedSource)
            _startQueuedTransition();
        else
            root.imageError();
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
        property string currentSource: ""
        property string pendingSource: ""
        property string queuedSource: ""
        property bool running: false
        property bool useShader: false
        property int effectiveShaderType: 2
        property real effectiveAngle: 0
        property point effectiveOrigin: Qt.point(0.5, 0.5)
    }

    Image {
        id: imageA

        anchors.fill: parent
        fillMode: root.fillMode
        sourceSize: root.sourceSize
        asynchronous: true
        cache: false
        autoTransform: true
        smooth: true
        opacity: 1
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
        opacity: 0
        z: 1
        onStatusChanged: _handleStatus("b", status)
    }

    Loader {
        id: shaderLoader

        anchors.fill: parent
        z: 5
        active: false
    }

    ParallelAnimation {
        id: fadeA

        onFinished: {
            root._completeTransition("a");
        }

        NumberAnimation {
            target: imageB
            property: "opacity"
            to: 0
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }

        NumberAnimation {
            target: imageA
            property: "opacity"
            to: 1
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }

    }

    ParallelAnimation {
        id: fadeB

        onFinished: {
            root._completeTransition("b");
        }

        NumberAnimation {
            target: imageA
            property: "opacity"
            to: 0
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }

        NumberAnimation {
            target: imageB
            property: "opacity"
            to: 1
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.easingCurve
        }

    }

    Connections {
        id: shaderConns

        function onFinished() {
            _finishShaderTransition();
        }

        target: shaderLoader.item
        enabled: shaderLoader.item !== null
    }

}
