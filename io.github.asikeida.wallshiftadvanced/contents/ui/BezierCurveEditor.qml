/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import "EasingUtils.js" as EasingUtils
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var curve: [0.43, 1.19, 1, 0.4, 1, 1]
    property bool editable: true
    property real previewTime: 0
    property string instructionText: qsTr("Drag P1 or P2 across the extended grid, or enter exact values below.")
    property string previewText: qsTr("Preview")

    signal curveEdited(var curve)

    function clamp01(value) {
        return EasingUtils.clamp(value, 0, 1);
    }

    function chartX(value) {
        var visibleValue = EasingUtils.clamp(value, chart.minimumX, chart.maximumX);
        return chart.plotLeft + (visibleValue - chart.minimumX) / (chart.maximumX - chart.minimumX) * chart.plotSize;
    }

    function chartY(value) {
        var visibleValue = EasingUtils.clamp(value, chart.minimumY, chart.maximumY);
        return chart.plotTop + (chart.maximumY - visibleValue) / (chart.maximumY - chart.minimumY) * chart.plotSize;
    }

    function constrainedCoordinate(curveValue, coordinate, target) {
        var current = Number(curveValue[coordinate]);
        var candidate = curveValue.slice();
        candidate[coordinate] = target;
        if (EasingUtils.isValidCurve(candidate))
            return target;

        candidate[coordinate] = current;
        if (!EasingUtils.isValidCurve(candidate))
            return current;

        var valid = current;
        var invalid = target;
        for (var step = 0; step < 24; ++step) {
            var middle = (valid + invalid) * 0.5;
            candidate[coordinate] = middle;
            if (EasingUtils.isValidCurve(candidate))
                valid = middle;
            else
                invalid = middle;
        }
        return valid;
    }

    function curvePoint(index, x, y) {
        var next = root.curve.slice(0, 4);
        next.push(1, 1);
        var xCoordinate = index * 2;
        var yCoordinate = xCoordinate + 1;
        var targetX = root.clamp01(x);
        var targetY = EasingUtils.clamp(y, chart.minimumY, chart.maximumY);
        next[xCoordinate] = root.constrainedCoordinate(next, xCoordinate, targetX);
        next[yCoordinate] = root.constrainedCoordinate(next, yCoordinate, targetY);
        if (EasingUtils.isValidCurve(next))
            root.curveEdited(next);

    }

    spacing: Kirigami.Units.smallSpacing

    Canvas {
        id: chart

        readonly property real leftPadding: 28
        readonly property real rightPadding: 16
        readonly property real topPadding: 16
        readonly property real bottomPadding: 24
        readonly property real minimumX: -1
        readonly property real maximumX: 2
        readonly property real minimumY: -1
        readonly property real maximumY: 2
        readonly property real plotSize: Math.max(1, Math.min(width - leftPadding - rightPadding, height - topPadding - bottomPadding))
        readonly property real plotLeft: Math.round((width - plotSize) * 0.5)
        readonly property real plotTop: topPadding

        function drawHandle(context, x, y) {
            context.beginPath();
            context.arc(root.chartX(x), root.chartY(y), 6, 0, Math.PI * 2);
            context.fillStyle = Kirigami.Theme.highlightColor;
            context.fill();
            context.lineWidth = 2;
            context.strokeStyle = Kirigami.Theme.highlightedTextColor;
            context.stroke();
        }

        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Kirigami.Theme.backgroundColor;
            ctx.fillRect(0, 0, width, height);
            ctx.lineWidth = 1;
            ctx.strokeStyle = Kirigami.Theme.disabledTextColor;
            for (var i = 0; i <= 6; ++i) {
                var gridValueX = chart.minimumX + i * 0.5;
                var gridX = root.chartX(gridValueX);
                ctx.beginPath();
                ctx.moveTo(gridX, plotTop);
                ctx.lineTo(gridX, plotTop + plotSize);
                ctx.stroke();
            }
            for (var j = 0; j <= 6; ++j) {
                var gridValueY = chart.minimumY + j * 0.5;
                var gridY = root.chartY(gridValueY);
                ctx.beginPath();
                ctx.moveTo(plotLeft, gridY);
                ctx.lineTo(plotLeft + plotSize, gridY);
                ctx.stroke();
            }
            ctx.strokeRect(plotLeft, plotTop, plotSize, plotSize);
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = Kirigami.Theme.disabledTextColor;
            ctx.beginPath();
            ctx.moveTo(root.chartX(0), plotTop);
            ctx.lineTo(root.chartX(0), plotTop + plotSize);
            ctx.moveTo(plotLeft, root.chartY(0));
            ctx.lineTo(plotLeft + plotSize, root.chartY(0));
            ctx.stroke();
            var x1 = root.curve[0];
            var y1 = root.curve[1];
            var x2 = root.curve[2];
            var y2 = root.curve[3];
            ctx.strokeStyle = Kirigami.Theme.disabledTextColor;
            ctx.beginPath();
            ctx.moveTo(root.chartX(0), root.chartY(0));
            ctx.lineTo(root.chartX(x1), root.chartY(y1));
            ctx.moveTo(root.chartX(1), root.chartY(1));
            ctx.lineTo(root.chartX(x2), root.chartY(y2));
            ctx.stroke();
            ctx.lineWidth = 3;
            ctx.strokeStyle = Kirigami.Theme.highlightColor;
            ctx.beginPath();
            for (var step = 0; step <= 80; ++step) {
                var t = step / 80;
                var x = EasingUtils.cubic(0, x1, x2, 1, t);
                var y = EasingUtils.cubic(0, y1, y2, 1, t);
                if (step === 0)
                    ctx.moveTo(root.chartX(x), root.chartY(y));
                else
                    ctx.lineTo(root.chartX(x), root.chartY(y));
            }
            ctx.stroke();
            drawHandle(ctx, x1, y1);
            drawHandle(ctx, x2, y2);
            ctx.font = "bold 11px sans-serif";
            ctx.fillStyle = Kirigami.Theme.textColor;
            ctx.fillText("P1", root.chartX(x1) + 9, root.chartY(y1) - 8);
            ctx.fillText("P2", root.chartX(x2) + 9, root.chartY(y2) - 8);
            var previewY = EasingUtils.valueAtTime(root.curve, root.previewTime);
            ctx.beginPath();
            ctx.arc(root.chartX(root.previewTime), root.chartY(previewY), 5, 0, Math.PI * 2);
            ctx.fillStyle = Kirigami.Theme.positiveTextColor;
            ctx.fill();
        }

        Connections {
            function onCurveChanged() {
                chart.requestPaint();
            }

            function onPreviewTimeChanged() {
                chart.requestPaint();
            }

            target: root
        }

        MouseArea {
            id: dragArea

            property int activePoint: -1
            property int hoveredPoint: -1

            function nearestPoint(x, y) {
                var firstDistance = Math.hypot(x - root.chartX(root.curve[0]), y - root.chartY(root.curve[1]));
                var secondDistance = Math.hypot(x - root.chartX(root.curve[2]), y - root.chartY(root.curve[3]));
                var threshold = 24;
                if (Math.min(firstDistance, secondDistance) > threshold)
                    return -1;

                return firstDistance <= secondDistance ? 0 : 1;
            }

            function updatePoint(mouse) {
                if (activePoint < 0)
                    return ;

                var x = chart.minimumX + (mouse.x - chart.plotLeft) / chart.plotSize * (chart.maximumX - chart.minimumX);
                var y = chart.maximumY - (mouse.y - chart.plotTop) / chart.plotSize * (chart.maximumY - chart.minimumY);
                root.curvePoint(activePoint, x, y);
            }

            anchors.fill: parent
            enabled: root.editable
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            cursorShape: activePoint >= 0 ? Qt.ClosedHandCursor : hoveredPoint >= 0 ? Qt.OpenHandCursor : Qt.ArrowCursor
            onPressed: function(mouse) {
                activePoint = nearestPoint(mouse.x, mouse.y);
                mouse.accepted = activePoint >= 0;
                updatePoint(mouse);
            }
            onPositionChanged: function(mouse) {
                if (activePoint < 0)
                    hoveredPoint = nearestPoint(mouse.x, mouse.y);

                updatePoint(mouse);
            }
            onReleased: function(mouse) {
                activePoint = -1;
                hoveredPoint = nearestPoint(mouse.x, mouse.y);
            }
            onCanceled: activePoint = -1
            onExited: hoveredPoint = -1
        }

    }

    QQC2.Label {
        Layout.fillWidth: true
        text: root.instructionText
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            color: Kirigami.Theme.disabledTextColor
            text: "cubic-bezier(%1, %2, %3, %4)".arg(Number(root.curve[0]).toFixed(3)).arg(Number(root.curve[1]).toFixed(3)).arg(Number(root.curve[2]).toFixed(3)).arg(Number(root.curve[3]).toFixed(3))
        }

        QQC2.Button {
            text: root.previewText
            icon.name: "media-playback-start"
            onClicked: previewAnimation.restart()
        }

    }

    NumberAnimation {
        id: previewAnimation

        target: root
        property: "previewTime"
        from: 0
        to: 1
        duration: 1200
        easing.type: Easing.Linear
    }

}
