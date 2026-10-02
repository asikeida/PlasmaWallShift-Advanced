/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

Item {
    id: root

    property Item oldSourceItem
    property Item newSourceItem
    property int transitionType: 2
    property int transitionDuration: 400
    property real transitionAngle: 0
    property var easingCurve: [0.43, 1.19, 1, 0.4, 1, 1]
    property point transitionOrigin: Qt.point(0.5, 0.5)
    property real edgeSoftness: 0.05
    property real waveAmplitude: 0.05
    property real waveFrequency: 40
    property real stripeCount: 12
    property real pixelSize: 0.35
    property real irisScale: 0.2
    property real portalTwist: 1.2

    signal finished()

    function stop() {
        anim.stop();
    }

    Component.onCompleted: {
        srcOld.scheduleUpdate();
        srcNew.scheduleUpdate();
        Qt.callLater(anim.start);
    }

    ShaderEffectSource {
        id: srcOld

        sourceItem: root.oldSourceItem
        live: false
        hideSource: true
    }

    ShaderEffectSource {
        id: srcNew

        sourceItem: root.newSourceItem
        live: false
        hideSource: true
    }

    ShaderEffect {
        id: shader

        property var source: srcOld
        property var to: srcNew
        property real t: 0
        property real angle: root.transitionAngle * Math.PI / 180
        property point origin: root.transitionOrigin
        property real softness: root.edgeSoftness
        property real waveAmplitude: root.waveAmplitude
        property real waveFrequency: root.waveFrequency
        property real stripeCount: root.stripeCount
        property real pixelSize: root.pixelSize
        property real irisScale: root.irisScale
        property real portalTwist: root.portalTwist
        property size screenSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))

        anchors.fill: parent
        z: 5
        fragmentShader: Qt.resolvedUrl(root.transitionType === 2 ? "shaders/simple.frag.qsb" : root.transitionType === 3 ? "shaders/wipe.frag.qsb" : root.transitionType === 4 ? "shaders/wave.frag.qsb" : root.transitionType === 5 ? "shaders/grow.frag.qsb" : root.transitionType === 6 ? "shaders/outer.frag.qsb" : root.transitionType === 8 ? "shaders/stripes.frag.qsb" : root.transitionType === 9 ? "shaders/pixelate.frag.qsb" : root.transitionType === 10 ? "shaders/iris.frag.qsb" : root.transitionType === 11 ? "shaders/portal.frag.qsb" : "shaders/crossfade.frag.qsb")
    }

    NumberAnimation {
        id: anim

        target: shader
        property: "t"
        from: 0
        to: 1
        duration: root.transitionDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.easingCurve
        onFinished: root.finished()
    }

}
