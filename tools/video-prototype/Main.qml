/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Window

Window {
    id: window

    width: 640
    height: 360
    visible: true
    color: "black"
    title: "WallShift Video Prototype"

    function argumentValue(prefix) {
        var args = Qt.application.arguments;
        for (var i = 0; i < args.length; ++i) {
            if (String(args[i]).indexOf(prefix) === 0)
                return String(args[i]).substring(prefix.length);
        }
        return "";
    }

    PrototypeScene {
        anchors.fill: parent
        sourceUrl: window.argumentValue("--source=")
        outputDirectory: window.argumentValue("--output=")
        onTestFailed: function(reason) {
            console.error("PROTOTYPE_FAIL " + reason);
            Qt.callLater(function() {
                Qt.exit(2);
            });
        }
        onTestPassed: {
            console.log("PROTOTYPE_PASS");
            Qt.exit(0);
        }
    }
}
