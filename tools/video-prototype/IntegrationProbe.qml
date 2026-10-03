/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

QtObject {
    id: probe

    required property var targetRoot
    required property var targetTransition
    required property string outputDirectory
    required property string corruptPath
    required property string recoveryPath
    required property string singleVideoPath
    property int step: 0
    property int waitAttempts: 0
    property var observedKinds: []
    readonly property var expectedKinds: ["image", "video", "image", "video", "image", "image", "video", "video"]
    readonly property var expectedNames: ["01-image.png", "02-video.mp4", "03-image.png", "04-video.webm", "03-image.png", "06-recovery.png", "02-video.mp4", "02-video.mp4"]

    function fail(reason) {
        timer.stop();
        console.error("MEDIA_INTEGRATION_FAIL " + reason);
    }

    function checkStep() {
        if ((step < 5 && targetRoot.mediaItems.length < 4) || !targetTransition.currentPath) {
            waitAttempts += 1;
            if (waitAttempts > 20) {
                fail("media scan timed out; count=" + targetRoot.mediaItems.length);
                return;
            }
            timer.interval = 500;
            timer.restart();
            return;
        }

        var kind = targetTransition.currentKind;
        var expected = expectedKinds[step];
        console.log("MEDIA_INTEGRATION_STEP step=" + step + " kind=" + kind + " path=" + targetTransition.currentPath);
        if (kind !== expected) {
            fail("step " + step + " expected " + expected + " but got " + kind);
            return;
        }
        if (!String(targetTransition.currentPath).endsWith(expectedNames[step])) {
            fail("step " + step + " expected " + expectedNames[step] + " but got " + targetTransition.currentPath);
            return;
        }
        observedKinds.push(kind);
        targetRoot.grabToImage(function(result) {
            var path = outputDirectory + "/step-" + step + "-" + kind + ".png";
            if (!result.saveToFile(path)) {
                fail("could not save " + path);
                return;
            }
            console.log("MEDIA_INTEGRATION_FRAME " + path);
            if (step === expectedKinds.length - 1) {
                console.log("MEDIA_INTEGRATION_PASS kinds=" + observedKinds.join(","));
                return;
            }
            step += 1;
            if (step === 2) {
                // The short MP4 must advance naturally via playbackEnded.
                timer.interval = 3500;
            } else if (step === 4) {
                // Three rapid requests should keep only the final destination:
                // 04-video -> 01-image -> 02-video -> 03-image.
                targetRoot.rotateNext(false);
                targetRoot.rotateNext(false);
                targetRoot.rotateNext(false);
                timer.interval = 2500;
            } else if (step === 5) {
                // Replace the catalog with the current item, a corrupt video,
                // and a valid recovery image. Queue recovery while the corrupt
                // video loads; failure must not discard that latest request.
                var current = targetRoot.mediaItems[targetRoot.visibleMediaIndex];
                targetRoot.mediaItems = [current, {
                    "path": corruptPath,
                    "url": "file://" + corruptPath,
                    "name": "05-corrupt.mp4",
                    "modified": 0,
                    "kind": "video"
                }, {
                    "path": recoveryPath,
                    "url": "file://" + recoveryPath,
                    "name": "06-recovery.png",
                    "modified": 0,
                    "kind": "image"
                }];
                targetRoot.rotateNext(false);
                targetRoot.rotateNext(false);
                timer.interval = 2500;
            } else if (step === 6) {
                // Switch to a catalog containing one video. It must restart
                // after reaching the end instead of remaining paused.
                targetRoot.failedMediaPaths = {};
                targetRoot.mediaItems = [{
                    "path": singleVideoPath,
                    "url": "file://" + singleVideoPath,
                    "name": "02-video.mp4",
                    "modified": 0,
                    "kind": "video"
                }];
                targetRoot.showMedia(0, false);
                timer.interval = 1500;
            } else if (step === 7) {
                timer.interval = 4500;
            } else {
                targetRoot.rotateNext(false);
                timer.interval = 1500;
            }
            timer.restart();
        });
    }

    property Timer timer: Timer {
        interval: 2500
        repeat: false
        running: true
        onTriggered: probe.checkStep()
    }
}
