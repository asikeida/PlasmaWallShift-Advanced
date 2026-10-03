/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import "EasingUtils.js" as EasingUtils
import "MediaUtils.js" as MediaUtils
import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQC2

Item {
    id: root

    property var configDialog
    property var wallpaperConfiguration
    property string cfg_WallpaperPaths
    property bool cfg_IncludeImages
    property bool cfg_IncludeVideos
    property string cfg_RotationMode
    property int cfg_RotateSeconds
    property int cfg_FillMode
    property alias cfg_Color: colorButton.color
    property int cfg_TransitionType
    property int cfg_TransitionDuration
    property double cfg_WipeAngle
    property double cfg_WaveAngle
    property int cfg_RandomPool
    property string cfg_EasingMode
    property double cfg_BezierX1
    property double cfg_BezierY1
    property double cfg_BezierX2
    property double cfg_BezierY2
    property double cfg_EdgeSoftness
    property double cfg_WaveAmplitude
    property double cfg_WaveFrequency
    property string cfg_OriginMode
    property double cfg_OriginX
    property double cfg_OriginY
    property int cfg_StripeCount
    property double cfg_StripeAngle
    property double cfg_PixelSize
    property double cfg_IrisScale
    property double cfg_PortalTwist
    property int rotateHoursPart: 0
    property int rotateMinutesPart: 0
    property int rotateSecondsPart: 0
    property int imageCount: 0
    property int videoCount: 0
    property var scanFolders: []
    property var zhText: ({
        "%1 degrees": "%1 度",
        "%1 images": "%1 张图像",
        "%1 images, %2 videos": "%1 张图像，%2 个视频",
        "%1 ms": "%1 毫秒",
        "Add one or more wallpaper folders.": "添加一个或多个壁纸文件夹。",
        "Add...": "添加...",
        "Angle:": "角度：",
        "Background color:": "背景颜色：",
        "Bézier curve:": "贝塞尔曲线：",
        "Circular": "圆形",
        "Centered": "居中",
        "Choose Wallpaper Folder": "选择壁纸文件夹",
        "Cubic": "三次方",
        "Custom": "自定义",
        "Custom position": "自定义位置",
        "Edge softness:": "边缘柔度：",
        "Easing:": "动态曲线：",
        "Exponential": "指数",
        "Fade": "淡入淡出",
        "Fade (crossfade)": "淡入淡出（交叉淡化）",
        "Folders": "文件夹",
        "Grow": "扩张",
        "Grow (expanding)": "扩张（向外展开）",
        "Iris bloom": "虹膜绽放",
        "Iris opening:": "虹膜开度：",
        "Images": "图像",
        "Images and videos": "图像与视频",
        "Include images": "包含图像",
        "Include videos (experimental)": "包含视频（实验性）",
        "Drag P1 or P2 across the extended grid, or enter exact values below.": "可在扩展网格中拖动 P1 或 P2，也可以在下方输入精确参数。",
        "Linear": "线性",
        "Mouse cursor (KWin)": "鼠标位置（KWin）",
        "Modified time (newest first)": "按修改时间（最新在前）",
        "Modified time (oldest first)": "按修改时间（最旧在前）",
        "Name": "名称",
        "No images found in the configured folders.": "配置的文件夹中没有找到图像。",
        "No media found in the configured folders.": "配置的文件夹中没有找到媒体文件。",
        "None (instant)": "无（瞬切）",
        "Order:": "顺序：",
        "Outer": "收缩",
        "Outer (shrinking)": "收缩（向内收拢）",
        "Origin:": "扩散原点：",
        "Pixelate": "像素化",
        "Pixel size:": "像素尺寸：",
        "Portal": "传送门",
        "Portal twist:": "传送门扭曲：",
        "Positioning:": "定位方式：",
        "Preview": "预览",
        "Quadratic": "二次方",
        "Quartic": "四次方",
        "Quintic": "五次方",
        "Random": "随机",
        "Random position": "随机位置",
        "Random pool:": "随机池：",
        "Scaled and cropped": "缩放并裁剪",
        "Scaled, keep proportions": "缩放并保持比例",
        "Select Background Color": "选择背景颜色",
        "Simple": "简单",
        "Simple (dissolve)": "简单（溶解）",
        "Sine": "正弦",
        "Stretched": "拉伸",
        "Stripe count:": "条纹数量：",
        "Stripes": "条纹",
        "Switch every:": "切换间隔：",
        "Video audio is disabled. Videos play once, then advance.": "视频音频已禁用。视频播放一次后自动切换。",
        "Tiled": "平铺",
        "Transition:": "动画：",
        "Wave": "波浪",
        "Wave amplitude:": "波浪振幅：",
        "Wave frequency:": "波浪频率：",
        "Wave (sinusoidal)": "波浪（正弦）",
        "Wipe": "擦除",
        "Wipe (directional)": "擦除（方向）",
        "h": "时",
        "m": "分",
        "s": "秒"
    })

    function uiText(message, value) {
        var hasValue = arguments.length > 1;
        var translated = hasValue ? i18nd("plasma_wallpaper_io.github.asikeida.wallshiftadvanced", message, value) : i18nd("plasma_wallpaper_io.github.asikeida.wallshiftadvanced", message);
        if (Qt.locale().name.indexOf("zh") === 0 && zhText[message]) {
            translated = zhText[message];
            if (hasValue)
                translated = String(translated).replace("%1", value);

        }
        return translated;
    }

    function mediaCountText() {
        var translated = i18nd("plasma_wallpaper_io.github.asikeida.wallshiftadvanced", "%1 images, %2 videos", root.imageCount, root.videoCount);
        if (Qt.locale().name.indexOf("zh") === 0)
            translated = "%1 张图像，%2 个视频";
        return String(translated).replace("%1", root.imageCount).replace("%2", root.videoCount);
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
        if (text.indexOf("file://") === 0)
            return decodeURIComponent(text.substring(7));

        return text;
    }

    function pathToUrl(path) {
        if (!path || path.length === 0)
            return "";

        if (String(path).indexOf("file://") === 0)
            return path;

        return "file://" + String(path).split("/").map(function(part) {
            return encodeURIComponent(part);
        }).join("/");
    }

    function videoThumbnailUrls(path) {
        var cacheRoot = String(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)).replace(/\/$/, "");
        var hash = Qt.md5(root.pathToUrl(path));
        return ["x-large", "large", "xx-large", "normal"].map(function(size) {
            return cacheRoot + "/thumbnails/" + size + "/" + hash + ".png";
        });
    }

    function folderPaths() {
        var seen = {
        };
        return String(cfg_WallpaperPaths || "").split(/\r?\n/).map(function(item) {
            return String(item || "").trim();
        }).filter(function(path) {
            if (path.length === 0 || seen[path])
                return false;

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
        if (!path || path.length === 0)
            return ;

        if (root.folderPaths().indexOf(path) >= 0)
            return ;

        folderList.append({
            "path": path,
            "name": root.folderName(path)
        });
        root.writeFolderPathsFromModel();
    }

    function removeFolder(index) {
        if (index < 0 || index >= folderList.count)
            return ;

        folderList.remove(index);
        root.writeFolderPathsFromModel();
    }

    function fileModifiedMs(value) {
        var date = new Date(value);
        var time = date.getTime();
        return isNaN(time) ? 0 : time;
    }

    function resetScanFolders() {
        root.scanFolders = root.folderPaths();
        rebuildPreviewTimer.restart();
    }

    function rebuildPreviewImages() {
        var found = [];
        var seen = {
        };
        var folderSeen = {
        };
        var folders = root.scanFolders.slice();
        var addedFolder = false;
        for (var f = 0; f < folders.length; f++) {
            folderSeen[folders[f]] = true;
        }
        for (var i = 0; i < folderModels.count; i++) {
            var model = folderModels.objectAt(i);
            if (!model)
                continue;

            for (var j = 0; j < model.count; j++) {
                var path = root.fileUrlToPath(model.get(j, "filePath"));
                if (!path || seen[path])
                    continue;

                if (model.get(j, "fileIsDir")) {
                    if (!folderSeen[path]) {
                        folderSeen[path] = true;
                        folders.push(path);
                        addedFolder = true;
                    }
                    continue;
                }
                if (!MediaUtils.isSupportedPath(path, cfg_IncludeImages, cfg_IncludeVideos))
                    continue;

                seen[path] = true;
                found.push(MediaUtils.makeEntry(path, String(model.get(j, "fileName") || path), root.fileModifiedMs(model.get(j, "fileModified")), root.pathToUrl(path)));
            }
        }
        var mode = String(cfg_RotationMode || "name_asc");
        if (mode === "mtime_desc")
            found.sort(function(a, b) {
            return b.modified - a.modified || a.name.localeCompare(b.name);
        });
        else if (mode === "mtime_asc")
            found.sort(function(a, b) {
            return a.modified - b.modified || a.name.localeCompare(b.name);
        });
        else if (mode !== "random")
            found.sort(function(a, b) {
            return a.name.localeCompare(b.name) || a.path.localeCompare(b.path);
        });
        previewImages.clear();
        var images = 0;
        var videos = 0;
        for (var k = 0; k < found.length; k++) {
            previewImages.append(found[k]);
            if (found[k].kind === "video")
                videos += 1;
            else
                images += 1;
        }
        root.imageCount = images;
        root.videoCount = videos;
        if (addedFolder)
            root.scanFolders = folders;

    }

    function setComboToValue(combo, value) {
        for (var i = 0; i < combo.model.length; i++) {
            if (combo.model[i].value === value || combo.model[i].fillMode === value) {
                combo.currentIndex = i;
                break;
            }
        }
    }

    function effectiveCurve() {
        return EasingUtils.curve(cfg_EasingMode, cfg_BezierX1, cfg_BezierY1, cfg_BezierX2, cfg_BezierY2);
    }

    function setCustomCurve(curve) {
        if (!EasingUtils.isValidCurve(curve))
            return ;

        cfg_BezierX1 = curve[0];
        cfg_BezierY1 = curve[1];
        cfg_BezierX2 = curve[2];
        cfg_BezierY2 = curve[3];
    }

    function applyCustomCurve(curve) {
        if (!EasingUtils.isValidCurve(curve))
            return ;

        root.setCustomCurve(curve);
        cfg_EasingMode = "custom";
        root.setComboToValue(easingCombo, cfg_EasingMode);
    }

    function setCurveCoordinate(index, value) {
        var next = root.effectiveCurve().slice(0, 4);
        next[index] = value;
        next.push(1, 1);
        root.applyCustomCurve(next);
    }

    implicitWidth: Kirigami.Units.gridUnit * 58
    implicitHeight: Kirigami.Units.gridUnit * 42
    onCfg_RotateSecondsChanged: syncRotatePartsFromConfig()
    onCfg_WallpaperPathsChanged: syncFolderModel()
    onCfg_IncludeImagesChanged: rebuildPreviewTimer.restart()
    onCfg_IncludeVideosChanged: rebuildPreviewTimer.restart()
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
        onObjectAdded: rebuildPreviewTimer.restart()
        onObjectRemoved: rebuildPreviewTimer.restart()

        delegate: FolderListModel {
            folder: root.pathToUrl(modelData)
            nameFilters: MediaUtils.nameFilters(cfg_IncludeImages, cfg_IncludeVideos)
            showDirs: true
            showFiles: true
            showHidden: false
            sortField: FolderListModel.Name
            onCountChanged: rebuildPreviewTimer.restart()
            onStatusChanged: rebuildPreviewTimer.restart()
        }

    }

    FolderDialog {
        id: folderDialog

        title: root.uiText("Choose Wallpaper Folder")
        onAccepted: root.addFolder(selectedFolder)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        QQC2.ScrollView {
            id: settingsScroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 14
            clip: true
            contentWidth: availableWidth
            contentHeight: settingsForm.implicitHeight + Kirigami.Units.largeSpacing * 2
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            Kirigami.FormLayout {
                id: settingsForm

                x: Kirigami.Units.largeSpacing
                y: Kirigami.Units.largeSpacing
                width: Math.max(0, settingsScroll.availableWidth - Kirigami.Units.largeSpacing * 2)
                height: implicitHeight

            Flow {
                Kirigami.FormData.label: root.uiText("Images and videos") + ":"
                spacing: Kirigami.Units.smallSpacing

                QQC2.CheckBox {
                    text: root.uiText("Include images")
                    checked: cfg_IncludeImages
                    onToggled: cfg_IncludeImages = checked
                }

                QQC2.CheckBox {
                    text: root.uiText("Include videos (experimental)")
                    checked: cfg_IncludeVideos
                    onToggled: cfg_IncludeVideos = checked
                }
            }

            QQC2.Label {
                Kirigami.FormData.label: ""
                visible: cfg_IncludeVideos
                color: Kirigami.Theme.disabledTextColor
                text: root.uiText("Video audio is disabled. Videos play once, then advance.")
                wrapMode: Text.WordWrap
            }

            QQC2.ComboBox {
                id: fillModeCombo

                Kirigami.FormData.label: root.uiText("Positioning:")
                textRole: "label"
                valueRole: "fillMode"
                model: [{
                    "label": root.uiText("Scaled and cropped"),
                    "fillMode": Image.PreserveAspectCrop
                }, {
                    "label": root.uiText("Scaled, keep proportions"),
                    "fillMode": Image.PreserveAspectFit
                }, {
                    "label": root.uiText("Stretched"),
                    "fillMode": Image.Stretch
                }, {
                    "label": root.uiText("Centered"),
                    "fillMode": Image.Pad
                }, {
                    "label": root.uiText("Tiled"),
                    "fillMode": Image.Tile
                }]
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

                QQC2.Label {
                    text: root.uiText("h")
                }

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

                QQC2.Label {
                    text: root.uiText("m")
                }

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

                QQC2.Label {
                    text: root.uiText("s")
                }

            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Order:")
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: rotationModeCombo

                    textRole: "label"
                    valueRole: "value"
                    model: [{
                        "label": root.uiText("Name"),
                        "value": "name_asc"
                    }, {
                        "label": root.uiText("Modified time (newest first)"),
                        "value": "mtime_desc"
                    }, {
                        "label": root.uiText("Modified time (oldest first)"),
                        "value": "mtime_asc"
                    }, {
                        "label": root.uiText("Random"),
                        "value": "random"
                    }]
                    onActivated: cfg_RotationMode = currentValue
                    Component.onCompleted: root.setComboToValue(rotationModeCombo, cfg_RotationMode)
                }

                QQC2.Label {
                    color: Kirigami.Theme.disabledTextColor
                    text: root.mediaCountText()
                }

            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Transition:")
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: transitionTypeCombo

                    textRole: "label"
                    valueRole: "value"
                    model: [{
                        "label": root.uiText("None (instant)"),
                        "value": 0
                    }, {
                        "label": root.uiText("Fade (crossfade)"),
                        "value": 1
                    }, {
                        "label": root.uiText("Simple (dissolve)"),
                        "value": 2
                    }, {
                        "label": root.uiText("Wipe (directional)"),
                        "value": 3
                    }, {
                        "label": root.uiText("Wave (sinusoidal)"),
                        "value": 4
                    }, {
                        "label": root.uiText("Grow (expanding)"),
                        "value": 5
                    }, {
                        "label": root.uiText("Outer (shrinking)"),
                        "value": 6
                    }, {
                        "label": root.uiText("Stripes"),
                        "value": 8
                    }, {
                        "label": root.uiText("Pixelate"),
                        "value": 9
                    }, {
                        "label": root.uiText("Iris bloom"),
                        "value": 10
                    }, {
                        "label": root.uiText("Portal"),
                        "value": 11
                    }, {
                        "label": root.uiText("Random"),
                        "value": 7
                    }]
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

            QQC2.ComboBox {
                id: easingCombo

                Kirigami.FormData.label: root.uiText("Easing:")
                textRole: "label"
                valueRole: "value"
                enabled: cfg_TransitionType !== 0
                model: [{
                    "label": root.uiText("Linear"),
                    "value": "linear"
                }, {
                    "label": root.uiText("Quadratic"),
                    "value": "quad"
                }, {
                    "label": root.uiText("Cubic"),
                    "value": "cubic"
                }, {
                    "label": root.uiText("Quartic"),
                    "value": "quart"
                }, {
                    "label": root.uiText("Quintic"),
                    "value": "quint"
                }, {
                    "label": root.uiText("Sine"),
                    "value": "sine"
                }, {
                    "label": root.uiText("Exponential"),
                    "value": "expo"
                }, {
                    "label": root.uiText("Circular"),
                    "value": "circ"
                }, {
                    "label": root.uiText("Custom"),
                    "value": "custom"
                }]
                onActivated: cfg_EasingMode = currentValue
                Component.onCompleted: root.setComboToValue(easingCombo, cfg_EasingMode)
            }

            BezierCurveEditor {
                Kirigami.FormData.label: root.uiText("Bézier curve:")
                Layout.fillWidth: true
                visible: cfg_TransitionType !== 0
                editable: true
                instructionText: root.uiText("Drag P1 or P2 across the extended grid, or enter exact values below.")
                previewText: root.uiText("Preview")
                curve: root.effectiveCurve()
                onCurveEdited: function(curve) {
                    root.applyCustomCurve(curve);
                }
            }

            RowLayout {
                Kirigami.FormData.label: "P1 / P2:"
                visible: cfg_TransitionType !== 0
                spacing: Kirigami.Units.smallSpacing

                QQC2.SpinBox {
                    from: 0
                    to: 1000
                    stepSize: 10
                    editable: true
                    value: Math.round(root.effectiveCurve()[0] * 1000)
                    textFromValue: function(value) {
                        return "x1 " + (value / 1000).toFixed(2);
                    }
                    valueFromText: function(text) {
                        return Math.round(Number(String(text).replace(/[^0-9.-]/g, "")) * 1000);
                    }
                    onValueModified: root.setCurveCoordinate(0, value / 1000)
                }

                QQC2.SpinBox {
                    from: -4000
                    to: 4000
                    stepSize: 10
                    editable: true
                    value: Math.round(root.effectiveCurve()[1] * 1000)
                    textFromValue: function(value) {
                        return "y1 " + (value / 1000).toFixed(2);
                    }
                    valueFromText: function(text) {
                        return Math.round(Number(String(text).replace(/[^0-9.-]/g, "")) * 1000);
                    }
                    onValueModified: root.setCurveCoordinate(1, value / 1000)
                }

                QQC2.SpinBox {
                    from: 0
                    to: 1000
                    stepSize: 10
                    editable: true
                    value: Math.round(root.effectiveCurve()[2] * 1000)
                    textFromValue: function(value) {
                        return "x2 " + (value / 1000).toFixed(2);
                    }
                    valueFromText: function(text) {
                        return Math.round(Number(String(text).replace(/[^0-9.-]/g, "")) * 1000);
                    }
                    onValueModified: root.setCurveCoordinate(2, value / 1000)
                }

                QQC2.SpinBox {
                    from: -4000
                    to: 4000
                    stepSize: 10
                    editable: true
                    value: Math.round(root.effectiveCurve()[3] * 1000)
                    textFromValue: function(value) {
                        return "y2 " + (value / 1000).toFixed(2);
                    }
                    valueFromText: function(text) {
                        return Math.round(Number(String(text).replace(/[^0-9.-]/g, "")) * 1000);
                    }
                    onValueModified: root.setCurveCoordinate(3, value / 1000)
                }

            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Angle:")
                visible: cfg_TransitionType === 3 || cfg_TransitionType === 4 || cfg_TransitionType === 8

                QQC2.SpinBox {
                    from: 0
                    to: 360
                    value: cfg_TransitionType === 3 ? cfg_WipeAngle : cfg_TransitionType === 4 ? cfg_WaveAngle : cfg_StripeAngle
                    textFromValue: function(value) {
                        return root.uiText("%1 degrees", value);
                    }
                    valueFromText: function(text) {
                        return Number(String(text).replace(/\D/g, ""));
                    }
                    onValueModified: {
                        if (cfg_TransitionType === 3)
                            cfg_WipeAngle = value;
                        else if (cfg_TransitionType === 4)
                            cfg_WaveAngle = value;
                        else
                            cfg_StripeAngle = value;
                    }
                }

            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Edge softness:")
                visible: [3, 4, 5, 6, 8, 10, 11].indexOf(cfg_TransitionType) >= 0

                QQC2.Slider {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    from: 0.001
                    to: 0.25
                    stepSize: 0.001
                    value: cfg_EdgeSoftness
                    onMoved: cfg_EdgeSoftness = value
                }

                QQC2.Label {
                    text: Number(cfg_EdgeSoftness).toFixed(3)
                }

            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Wave amplitude:")
                visible: cfg_TransitionType === 4

                QQC2.Slider {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    from: 0
                    to: 0.2
                    stepSize: 0.005
                    value: cfg_WaveAmplitude
                    onMoved: cfg_WaveAmplitude = value
                }

                QQC2.Label {
                    text: Number(cfg_WaveAmplitude).toFixed(3)
                }

            }

            QQC2.SpinBox {
                Kirigami.FormData.label: root.uiText("Wave frequency:")
                visible: cfg_TransitionType === 4
                from: 2
                to: 100
                value: Math.round(cfg_WaveFrequency)
                onValueModified: cfg_WaveFrequency = value
            }

            QQC2.ComboBox {
                id: originModeCombo

                Kirigami.FormData.label: root.uiText("Origin:")
                visible: [5, 6, 7, 10, 11].indexOf(cfg_TransitionType) >= 0
                textRole: "label"
                valueRole: "value"
                model: [{
                    "label": root.uiText("Random position"),
                    "value": "random"
                }, {
                    "label": root.uiText("Centered"),
                    "value": "center"
                }, {
                    "label": root.uiText("Mouse cursor (KWin)"),
                    "value": "cursor"
                }, {
                    "label": root.uiText("Custom position"),
                    "value": "custom"
                }]
                onActivated: cfg_OriginMode = currentValue
                Component.onCompleted: root.setComboToValue(originModeCombo, cfg_OriginMode)
            }

            RowLayout {
                Kirigami.FormData.label: "X / Y:"
                visible: [5, 6, 7, 10, 11].indexOf(cfg_TransitionType) >= 0 && cfg_OriginMode === "custom"

                QQC2.SpinBox {
                    from: 0
                    to: 100
                    value: Math.round(cfg_OriginX * 100)
                    textFromValue: function(value) {
                        return "X " + value + "%";
                    }
                    onValueModified: cfg_OriginX = value / 100
                }

                QQC2.SpinBox {
                    from: 0
                    to: 100
                    value: Math.round(cfg_OriginY * 100)
                    textFromValue: function(value) {
                        return "Y " + value + "%";
                    }
                    onValueModified: cfg_OriginY = value / 100
                }

            }

            QQC2.SpinBox {
                Kirigami.FormData.label: root.uiText("Stripe count:")
                visible: cfg_TransitionType === 8
                from: 2
                to: 64
                value: cfg_StripeCount
                onValueModified: cfg_StripeCount = value
            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Pixel size:")
                visible: cfg_TransitionType === 9

                QQC2.Slider {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    from: 0.05
                    to: 0.8
                    stepSize: 0.01
                    value: cfg_PixelSize
                    onMoved: cfg_PixelSize = value
                }

                QQC2.Label {
                    text: Math.round(cfg_PixelSize * 100) + "%"
                }

            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Iris opening:")
                visible: cfg_TransitionType === 10

                QQC2.Slider {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    from: 0.05
                    to: 0.8
                    stepSize: 0.01
                    value: cfg_IrisScale
                    onMoved: cfg_IrisScale = value
                }

                QQC2.Label {
                    text: Number(cfg_IrisScale).toFixed(2)
                }

            }

            RowLayout {
                Kirigami.FormData.label: root.uiText("Portal twist:")
                visible: cfg_TransitionType === 11

                QQC2.Slider {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    from: 0
                    to: 4
                    stepSize: 0.1
                    value: cfg_PortalTwist
                    onMoved: cfg_PortalTwist = value
                }

                QQC2.Label {
                    text: Number(cfg_PortalTwist).toFixed(1)
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

                QQC2.CheckBox {
                    text: root.uiText("Stripes")
                    checked: cfg_RandomPool & 64
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 64) : (cfg_RandomPool & ~64)
                }

                QQC2.CheckBox {
                    text: root.uiText("Pixelate")
                    checked: cfg_RandomPool & 128
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 128) : (cfg_RandomPool & ~128)
                }

                QQC2.CheckBox {
                    text: root.uiText("Iris bloom")
                    checked: cfg_RandomPool & 256
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 256) : (cfg_RandomPool & ~256)
                }

                QQC2.CheckBox {
                    text: root.uiText("Portal")
                    checked: cfg_RandomPool & 512
                    onToggled: cfg_RandomPool = checked ? (cfg_RandomPool | 512) : (cfg_RandomPool & ~512)
                }

            }

            KQC2.ColorButton {
                id: colorButton

                Kirigami.FormData.label: root.uiText("Background color:")
                dialogTitle: root.uiText("Select Background Color")
            }

            }

        }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.35
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 14
                Layout.preferredHeight: Kirigami.Units.gridUnit * 20
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

                    QQC2.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        visible: folderList.count === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Kirigami.Theme.disabledTextColor
                        text: root.uiText("Add one or more wallpaper folders.")
                    }

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

                }

            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.35
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
                        text: root.uiText("Images and videos")
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

                    QQC2.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        visible: previewImages.count === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Kirigami.Theme.disabledTextColor
                        text: root.uiText("No media found in the configured folders.")
                    }

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
                                border.color: Kirigami.Theme.disabledTextColor
                                radius: Kirigami.Units.cornerRadius

                                Image {
                                    id: thumbnailImage

                                    property var candidates: kind === "video" ? root.videoThumbnailUrls(path) : [root.pathToUrl(path)]
                                    property int candidateIndex: 0

                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: candidateIndex < candidates.length ? candidates[candidateIndex] : ""
                                    visible: status === Image.Ready
                                    asynchronous: true
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    onCandidatesChanged: candidateIndex = 0
                                    onStatusChanged: {
                                        if (status === Image.Error && candidateIndex + 1 < candidates.length)
                                            candidateIndex += 1;
                                    }
                                }

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) * 0.42
                                    height: width
                                    source: "video-symbolic"
                                    visible: kind === "video" && thumbnailImage.status !== Image.Ready
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    width: Kirigami.Units.gridUnit * 1.8
                                    height: width
                                    radius: width * 0.5
                                    color: Qt.rgba(0, 0, 0, 0.58)
                                    visible: kind === "video" && thumbnailImage.status === Image.Ready

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.58
                                        height: width
                                        source: "media-playback-start"
                                        color: "white"
                                    }
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

                }

            }

        }
    }

}
