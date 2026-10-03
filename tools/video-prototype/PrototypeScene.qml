/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import "../../io.github.asikeida.wallshiftadvanced/contents/ui" as WallShift
import QtMultimedia
import QtQuick

Item {
    id: root

    property string sourceUrl
    property string outputDirectory
    property int pausedPosition: 0
    property int resumePosition: 0
    property int currentShader: 0
    property var shaderTypes: [2, 3, 4, 5, 6, 8, 9, 10, 11]
    property var shaderNames: ["simple", "wipe", "wave", "grow", "outer", "stripes", "pixelate", "iris", "portal"]
    property bool testStarted: false
    property bool failed: false

    signal testPassed()
    signal testFailed(string reason)

    function fail(message) {
        if (failed)
            return;

        failed = true;
        video.unload();
        testFailed(message);
    }

    function saveFrame(name, callback) {
        stage.grabToImage(function(result) {
            var path = outputDirectory + "/" + name + ".png";
            if (!result.saveToFile(path)) {
                fail("could not save " + path);
                return;
            }
            console.log("PROTOTYPE_FRAME " + path);
            if (callback)
                callback();
        });
    }

    function beginPlaybackChecks() {
        if (testStarted)
            return;

        testStarted = true;
        console.log("PROTOTYPE_FIRST_FRAME method=" + video.firstFrameMethod + " position=" + video.position + " hasAudio=" + video.hasAudio + " activeAudioTrack=" + video.activeAudioTrack);
        if (video.activeAudioTrack !== -1) {
            fail("audio track was not disabled");
            return;
        }
        saveFrame("first-frame", function() {
            pausedPosition = video.position;
            pauseCheck.restart();
        });
    }

    function beginFadeCheck() {
        oldFrame.visible = true;
        video.opacity = 0;
        video.visible = true;
        fadeAnimation.restart();
        fadeCapture.restart();
    }

    function beginNextShader() {
        if (currentShader >= shaderTypes.length) {
            video.unload();
            releaseCheck.restart();
            return;
        }
        shaderLoader.setSource(Qt.resolvedUrl("../../io.github.asikeida.wallshiftadvanced/contents/ui/ShaderTransitionOverlay.qml"), {
            "oldSourceItem": oldFrame,
            "newSourceItem": video,
            "transitionType": shaderTypes[currentShader],
            "transitionDuration": 600
        });
        shaderLoader.active = true;
        shaderCapture.restart();
    }

    Component.onCompleted: {
        if (!sourceUrl || !outputDirectory) {
            fail("sourceUrl and outputDirectory are required");
            return;
        }
        console.log("PROTOTYPE_SOURCE " + sourceUrl);
        video.load(sourceUrl);
    }

    Item {
        id: stage

        anchors.fill: parent

        Rectangle {
            id: oldFrame

            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#0b3d91"
                }
                GradientStop {
                    position: 1
                    color: "#f97316"
                }
            }
        }

        WallShift.VideoSurface {
            id: video

            anchors.fill: parent
            desiredPlaying: false
            firstFrameTimeout: 10000
            onReadyForTransition: root.beginPlaybackChecks()
            onLoadFailed: function(reason) {
                root.fail(reason);
            }
        }

        Loader {
            id: shaderLoader

            anchors.fill: parent
            z: 5
            active: false
        }
    }

    Timer {
        id: pauseCheck

        interval: 700
        onTriggered: {
            var drift = Math.abs(video.position - pausedPosition);
            console.log("PROTOTYPE_PAUSE position=" + video.position + " drift=" + drift);
            if (drift > 150) {
                root.fail("position advanced while paused: " + drift + "ms");
                return;
            }
            resumePosition = video.position;
            video.play();
            resumeCheck.restart();
        }
    }

    Timer {
        id: resumeCheck

        interval: 900
        onTriggered: {
            var advance = video.position - resumePosition;
            console.log("PROTOTYPE_RESUME position=" + video.position + " advance=" + advance);
            if (advance < 200) {
                root.fail("position did not advance after resume: " + advance + "ms");
                return;
            }
            video.pause();
            settleBeforeEffects.restart();
        }
    }

    Timer {
        id: settleBeforeEffects

        interval: 250
        onTriggered: root.beginFadeCheck()
    }

    NumberAnimation {
        id: fadeAnimation

        target: video
        property: "opacity"
        from: 0
        to: 1
        duration: 600
        onFinished: {
            console.log("PROTOTYPE_EFFECT fade finished");
            root.beginNextShader();
        }
    }

    Timer {
        id: fadeCapture

        interval: 300
        onTriggered: root.saveFrame("fade-midpoint", null)
    }

    Timer {
        id: shaderCapture

        interval: 300
        onTriggered: root.saveFrame(shaderNames[currentShader] + "-midpoint", null)
    }

    Connections {
        target: shaderLoader.item
        enabled: shaderLoader.item !== null

        function onFinished() {
            console.log("PROTOTYPE_EFFECT " + shaderNames[currentShader] + " finished");
            shaderLoader.active = false;
            currentShader += 1;
            Qt.callLater(root.beginNextShader);
        }
    }

    Timer {
        id: releaseCheck

        interval: 500
        onTriggered: {
            console.log("PROTOTYPE_RELEASE source=" + video.source + " mediaStatus=" + video.mediaStatus + " playbackState=" + video.playbackState);
            if (String(video.source) !== "" || video.mediaStatus !== MediaPlayer.NoMedia) {
                root.fail("player did not release its source");
                return;
            }
            root.testPassed();
        }
    }
}
