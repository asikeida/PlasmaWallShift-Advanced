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
    property real transitionAngle: 0.0

    property point transitionOrigin: Qt.point(0.5, 0.5)

    signal finished()

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
        anchors.fill: parent
        z: 5

        property var source: srcOld
        property var to: srcNew
        property real t: 0.0
        property real angle: root.transitionAngle * Math.PI / 180.0
        property point origin: root.transitionOrigin

        fragmentShader: Qt.resolvedUrl(
            root.transitionType === 2 ? "shaders/simple.frag.qsb" :
            root.transitionType === 3 ? "shaders/wipe.frag.qsb" :
            root.transitionType === 4 ? "shaders/wave.frag.qsb" :
            root.transitionType === 5 ? "shaders/grow.frag.qsb" :
            root.transitionType === 6 ? "shaders/outer.frag.qsb" :
            "shaders/crossfade.frag.qsb"
        )
    }

    NumberAnimation {
        id: anim
        target: shader
        property: "t"
        from: 0.0
        to: 1.0
        duration: root.transitionDuration
        easing.type: Easing.InOutQuad
        onFinished: root.finished()
    }

    Component.onCompleted: {
        srcOld.scheduleUpdate();
        srcNew.scheduleUpdate();
        Qt.callLater(anim.start);
    }

    function stop() { anim.stop(); }
}
