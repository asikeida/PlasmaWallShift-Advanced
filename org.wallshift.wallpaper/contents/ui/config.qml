/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import org.kde.kquickcontrols as KQC2
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string cfg_WallpaperPaths
    property string cfg_RotationMode
    property int cfg_RotateSeconds
    property int cfg_FillMode
    property alias cfg_Color: colorButton.color
    property int cfg_TransitionType
    property int cfg_TransitionDuration
    property double cfg_WipeAngle
    property double cfg_WaveAngle
    property int cfg_RandomPool

    property int rotateHoursPart: 0
    property int rotateMinutesPart: 0
    property int rotateSecondsPart: 0
    property int imageCount: previewImages.count
    property var scanFolders: []
    property var zhText: ({
        "%1 degrees": "%1 度",
        "%1 images": "%1 张图像",
        "%1 ms": "%1 毫秒",
        "Add one or more wallpaper folders.": "添加一个或多个壁纸文件夹。",
        "Add...": "添加...",
        "Angle:": "角度：",
        "Background color:": "背景颜色：",
        "Centered": "居中",
        "Choose Wallpaper Folder": "选择壁纸文件夹",
        "Fade": "淡入淡出",
        "Fade (crossfade)": "淡入淡出（交叉淡化）",
        "Folders": "文件夹",
        "Grow": "扩张",
        "Grow (expanding)": "扩张（向外展开）",
        "Images": "图像",
        "Modified time (newest first)": "按修改时间（最新在前）",
        "Modified time (oldest first)": "按修改时间（最旧在前）",
        "Name": "名称",
        "No images found in the configured folders.": "配置的文件夹中没有找到图像。",
        "None (instant)": "无（瞬切）",
        "Order:": "顺序：",
        "Outer": "收缩",
        "Outer (shrinking)": "收缩（向内收拢）",
        "Positioning:": "定位方式：",
        "Random": "随机",
        "Random pool:": "随机池：",
        "Scaled and cropped": "缩放并裁剪",
        "Scaled, keep proportions": "缩放并保持比例",
        "Select Background Color": "选择背景颜色",
        "Simple": "简单",
        "Simple (dissolve)": "简单（溶解）",
        "Stretched": "拉伸",
        "Switch every:": "切换间隔：",
        "Tiled": "平铺",
        "Transition:": "动画：",
        "Wave": "波浪",
        "Wave (sinusoidal)": "波浪（正弦）",
        "Wipe": "擦除",
        "Wipe (directional)": "擦除（方向）",
        "h": "时",
        "m": "分",
        "s": "秒"
    })

    implicitWidth: Kirigami.Units.gridUnit * 58
    implicitHeight: Kirigami.Units.gridUnit * 42

    function uiText(message, value) {
        var translated = i18nd("plasma_wallpaper_org.wallshift.wallpaper", message);
        if (Qt.locale().name.indexOf("zh") === 0 && zhText[message]) {
            translated = zhText[message];
        }
        if (arguments.length > 1) {
            translated = String(translated).replace("%1", value);
        }
        return translated;
    }

    function splitSeconds(totalSeconds) {
        var total = Math.max(1, Math.round(Number(totalSeconds || 1800)));
        return {
            "hours": Math.floor(total / 3600),
            "minutes": Math.floor((total % 3600) / 60),
            "seconds": total % 60
        };
    }

    function syncRotatePartsFromConfig() {
        var parts = root.splitSeconds(cfg_RotateSeconds);
        rotateHoursPart = parts.hours;
        rotateMinutesPart = parts.minutes;
        rotateSecondsPart = parts.seconds;
    }

    function applyRotateParts() {
        cfg_RotateSeconds = Math.max(1, rotateHoursPart * 3600 + rotateMinutesPart * 60 + rotateSecondsPart);
    }

    function fileUrlToPath(url) {
        var text = String(url || "");
        if (text.indexOf("file://") === 0) {
            return decodeURIComponent(text.substring(7));
        }
        return text;
    }

    function pathToUrl(path) {
        if (!path || path.length === 0) {
            return "";
        }
        if (String(path).indexOf("file://") === 0) {
            return path;
        }
        return "file://" + String(path).split("/").map(function(part) {
            return encodeURIComponent(part);
        }).join("/");
    }

    function folderPaths() {
        var seen = {};
        return String(cfg_WallpaperPaths || "").split(/\r?\n/).map(function(item) {
            return String(item || "").trim();
        }).filter(function(path) {
            if (path.length === 0 || seen[path]) {
                return false;
            }
            seen[path] = true;
            return true;
        });
    }

    function folderName(path) {
        var parts = String(path || "").split("/");
        return parts.length > 0 && parts[parts.length - 1].length > 0 ? parts[parts.length - 1] : path;
    }

    function syncFolderModel() {
        folderList.clear();
        var paths = root.folderPaths();
        for (var i = 0; i < paths.length; i++) {
            folderList.append({
                "path": paths[i],
                "name": root.folderName(paths[i])
            });
        }
        root.resetScanFolders();
    }

    function writeFolderPathsFromModel() {
        var paths = [];
        for (var i = 0; i < folderList.count; i++) {
            paths.push(folderList.get(i).path);
        }
        cfg_WallpaperPaths = paths.join("\n");
    }

    function addFolder(path) {
        path = root.fileUrlToPath(path);
        if (!path || path.length === 0) {
            return;
        }
        if (root.folderPaths().indexOf(path) >= 0) {
            return;
        }
        folderList.append({
            "path": path,
            "name": root.folderName(path)
        });
        root.writeFolderPathsFromModel();
    }

    function removeFolder(index) {
        if (index < 0 || index >= folderList.count) {
            return;
        }
        folderList.remove(index);
        root.writeFolderPathsFromModel();
    }

    function fileModifiedMs(value) {
        var date = new Date(value);
        var time = date.getTime();
        return isNaN(time) ? 0 : time;
    }

    function isImagePath(path) {
        return /\.(jpe?g|png|webp|bmp)$/i.test(String(path || ""));
    }

    function resetScanFolders() {
        root.scanFolders = root.folderPaths();
        rebuildPreviewTimer.restart();
    }

    function rebuildPreviewImages() {
        var found = [];
        var seen = {};
        var folderSeen = {};
        var folders = root.scanFolders.slice();
        var addedFolder = false;
        for (var f = 0; f < folders.length; f++) {
            folderSeen[folders[f]] = true;
        }
        for (var i = 0; i < folderModels.count; i++) {
            var model = folderModels.objectAt(i);
            if (!model) {
                continue;
            }
            for (var j = 0; j < model.count; j++) {
                var path = root.fileUrlToPath(model.get(j, "filePath"));
                if (!path || seen[path]) {
                    continue;
                }
                if (model.get(j, "fileIsDir")) {
                    if (!folderSeen[path]) {
                        folderSeen[path] = true;
                        folders.push(path);
                        addedFolder = true;
                    }
                    continue;
                }
                if (!root.isImagePath(path)) {
                    continue;
                }
                seen[path] = true;
                found.push({
                    "path": path,
                    "name": String(model.get(j, "fileName") || path),
                    "modified": root.fileModifiedMs(model.get(j, "fileModified"))
                });
            }
        }

        var mode = String(cfg_RotationMode || "name_asc");
        if (mode === "mtime_desc") {
            found.sort(function(a, b) { return b.modified - a.modified || a.name.localeCompare(b.name); });
        } else if (mode === "mtime_asc") {
            found.sort(function(a, b) { return a.modified - b.modified || a.name.localeCompare(b.name); });
        } else if (mode !== "random") {
            found.sort(function(a, b) { return a.name.localeCompare(b.name) || a.path.localeCompare(b.path); });
        }

        previewImages.clear();
        for (var k = 0; k < found.length; k++) {
            previewImages.append(found[k]);
        }
        if (addedFolder) {
            root.scanFolders = folders;
        }
    }

    function setComboToValue(combo, value) {
        for (var i = 0; i < combo.model.length; i++) {
            if (combo.model[i].value === value || combo.model[i].fillMode === value) {
                combo.currentIndex = i;
                break;
            }
        }
    }

    onCfg_RotateSecondsChanged: syncRotatePartsFromConfig()
    onCfg_WallpaperPathsChanged: syncFolderModel()
    onCfg_RotationModeChanged: rebuildPreviewTimer.restart()

    Component.onCompleted: {
        syncRotatePartsFromConfig();
        syncFolderModel();
    }

    ListModel {
        id: folderList
    }

    ListModel {
        id: previewImages
    }

    Timer {
        id: rebuildPreviewTimer
        interval: 120
        repeat: false
        onTriggered: root.rebuildPreviewImages()
    }

    Instantiator {
        id: folderModels
        model: root.scanFolders

        delegate: FolderListModel {
            folder: root.pathToUrl(modelData)
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.BMP"]
            showDirs: true
            showFiles: true
            showHidden: false
            sortField: FolderListModel.Name
            onCountChanged: rebuildPreviewTimer.restart()
            onStatusChanged: rebuildPreviewTimer.restart()
        }

        onObjectAdded: rebuildPreviewTimer.restart()
        onObjectRemoved: rebuildPreviewTimer.restart()
    }

    FolderDialog {
        id: folderDialog
        title: root.uiText("Choose Wallpaper Folder")
        onAccepted: root.addFolder(selectedFolder)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Kirigami.FormLayout {
            id: settingsForm
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing

            QQC2.ComboBox {
                id: fillModeCombo
                Kirigami.FormData.label: root.uiText("Positioning:")
                textRole: "label"
                valueRole: "fillMode"
                model: [
                    { "label": root.uiText("Scaled and cropped"), "fillMode": Image.PreserveAspectCrop },
                    { "label": root.uiText("Scaled, keep proportions"), "fillMode": Image.PreserveAspectFit },
                    { "label": root.uiText("Stretched"), "fillMode": Image.Stretch },
                    { "label": root.uiText("Centered"), "fillMode": Image.Pad },
                    { "label": root.uiText("Tiled"), "fillMode": Image.Tile }
                ]
                onActivated: cfg_FillMode = currentValue
                Component.onCompleted: root.setComboToValue(fillModeCombo, cfg_FillMode)
            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Switch every:")
                spacing: Kirigami.Units.smallSpacing

                QQC2.SpinBox {
                    from: 0
                    to: 999
                    value: rotateHoursPart
                    editable: true
                    onValueModified: {
                        rotateHoursPart = value;
                        root.applyRotateParts();
                    }
                }
                QQC2.Label { text: root.uiText("h") }

                QQC2.SpinBox {
                    from: 0
                    to: 59
                    value: rotateMinutesPart
                    editable: true
                    onValueModified: {
                        rotateMinutesPart = value;
                        root.applyRotateParts();
                    }
                }
                QQC2.Label { text: root.uiText("m") }

                QQC2.SpinBox {
                    from: 0
                    to: 59
                    value: rotateSecondsPart
                    editable: true
                    onValueModified: {
                        rotateSecondsPart = value;
                        root.applyRotateParts();
                    }
                }
                QQC2.Label { text: root.uiText("s") }
            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Order:")
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: rotationModeCombo
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { "label": root.uiText("Name"), "value": "name_asc" },
                        { "label": root.uiText("Modified time (newest first)"), "value": "mtime_desc" },
                        { "label": root.uiText("Modified time (oldest first)"), "value": "mtime_asc" },
                        { "label": root.uiText("Random"), "value": "random" }
                    ]
                    onActivated: cfg_RotationMode = currentValue
                    Component.onCompleted: root.setComboToValue(rotationModeCombo, cfg_RotationMode)
                }

                QQC2.Label {
                    color: Kirigami.Theme.disabledTextColor
                    text: root.uiText("%1 images", root.imageCount)
                }
            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Transition:")
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: transitionTypeCombo
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { "label": root.uiText("None (instant)"), "value": 0 },
                        { "label": root.uiText("Fade (crossfade)"), "value": 1 },
                        { "label": root.uiText("Simple (dissolve)"), "value": 2 },
                        { "label": root.uiText("Wipe (directional)"), "value": 3 },
                        { "label": root.uiText("Wave (sinusoidal)"), "value": 4 },
                        { "label": root.uiText("Grow (expanding)"), "value": 5 },
                        { "label": root.uiText("Outer (shrinking)"), "value": 6 },
                        { "label": root.uiText("Random"), "value": 7 }
                    ]
                    onActivated: cfg_TransitionType = currentValue
                    Component.onCompleted: root.setComboToValue(transitionTypeCombo, cfg_TransitionType)
                }

                QQC2.SpinBox {
                    from: 100
                    to: 5000
                    stepSize: 100
                    value: cfg_TransitionDuration
                    textFromValue: function(value) {
                        return root.uiText("%1 ms", value);
                    }
                    valueFromText: function(text) {
                        return Number(String(text).replace(/\D/g, ""));
                    }
                    onValueModified: cfg_TransitionDuration = value
                }
            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Angle:")
                visible: cfg_TransitionType === 3 || cfg_TransitionType === 4

                QQC2.SpinBox {
                    from: 0
                    to: 360
                    value: cfg_TransitionType === 3 ? cfg_WipeAngle : cfg_WaveAngle
                    textFromValue: function(value) {
                        return root.uiText("%1 degrees", value);
                    }
                    valueFromText: function(text) {
                        return Number(String(text).replace(/\D/g, ""));
                    }
                    onValueModified: {
                        if (cfg_TransitionType === 3) {
                            cfg_WipeAngle = value;
                        } else {
                            cfg_WaveAngle = value;
                        }
                    }
                }
            }

            Flow {
                Kirigami.FormData.label: root.uiText("Random pool:")
                visible: cfg_TransitionType === 7
                spacing: Kirigami.Units.smallSpacing

                QQC2.CheckBox {
                    text: root.uiText("Fade")
                    checked: cfg_RandomPool & 1
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 1) : (cfg_RandomPool & ~1)
                }
                QQC2.CheckBox {
                    text: root.uiText("Simple")
                    checked: cfg_RandomPool & 2
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 2) : (cfg_RandomPool & ~2)
                }
                QQC2.CheckBox {
                    text: root.uiText("Wipe")
                    checked: cfg_RandomPool & 4
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 4) : (cfg_RandomPool & ~4)
                }
                QQC2.CheckBox {
                    text: root.uiText("Wave")
                    checked: cfg_RandomPool & 8
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 8) : (cfg_RandomPool & ~8)
                }
                QQC2.CheckBox {
                    text: root.uiText("Grow")
                    checked: cfg_RandomPool & 16
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 16) : (cfg_RandomPool & ~16)
                }
                QQC2.CheckBox {
                    text: root.uiText("Outer")
                    checked: cfg_RandomPool & 32
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 32) : (cfg_RandomPool & ~32)
                }
            }

            KQC2.ColorButton {
                id: colorButton
                Kirigami.FormData.label: root.uiText("Background color:")
                dialogTitle: root.uiText("Select Background Color")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Kirigami.Theme.separatorColor
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ColumnLayout {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.uiText("Folders")
                        font.weight: Font.DemiBold
                    }

                    QQC2.ToolButton {
                        icon.name: "list-add"
                        text: root.uiText("Add...")
                        display: QQC2.AbstractButton.TextBesideIcon
                        onClicked: folderDialog.open()
                    }
                }

                ListView {
                    id: folderView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: folderList
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        width: folderView.width
                        height: Kirigami.Units.gridUnit * 3.8

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: name
                                    elide: Text.ElideRight
                                }

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: path
                                    color: Kirigami.Theme.disabledTextColor
                                    elide: Text.ElideMiddle
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                }
                            }

                            QQC2.ToolButton {
                                icon.name: "edit-delete-remove"
                                onClicked: root.removeFolder(index)
                            }
                        }
                    }

                    QQC2.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        visible: folderList.count === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Kirigami.Theme.disabledTextColor
                        text: root.uiText("Add one or more wallpaper folders.")
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Kirigami.Theme.separatorColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.uiText("Images")
                        font.weight: Font.DemiBold
                    }
                }

                GridView {
                    id: imageGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: previewImages
                    cellWidth: Math.max(Kirigami.Units.gridUnit * 13, Math.floor(width / Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 15)))))
                    cellHeight: Kirigami.Units.gridUnit * 10
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        width: imageGrid.cellWidth
                        height: imageGrid.cellHeight

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(width * 0.58)
                                color: Kirigami.Theme.alternateBackgroundColor
                                border.color: Kirigami.Theme.separatorColor
                                radius: Kirigami.Units.cornerRadius

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: root.pathToUrl(path)
                                    asynchronous: true
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                }
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: name
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    QQC2.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        visible: previewImages.count === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Kirigami.Theme.disabledTextColor
                        text: root.uiText("No images found in the configured folders.")
                    }
                }
            }
        }
    }
}
