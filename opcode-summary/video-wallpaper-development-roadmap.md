# PlasmaWallShift Advanced 视频壁纸开发路线

> 文档状态：`v0.4.0` 实验发布候选；首轮实现和混合媒体原型已在当前开发机通过
> 面向版本：`v0.4.0` 首次提供实验性视频支持，稳定后再考虑默认开放
> 设计基线：`v0.2.0`；当前实现状态见第 23、24 节
> 适用平台：KDE Plasma 6、Qt 6.4 及以上、Wayland 优先  
> 最后更新：2026-10-03

> 对标调研：见 [`video-wallpaper-reference-study.md`](video-wallpaper-reference-study.md)。该文档分析了 Smart Video Wallpaper Reborn、Wallpaper Engine for KDE、linux-wallpaperengine、Fresco 及 Qt 6.4 官方 API；本路线已吸收其后端隔离、首帧检测、播放裁决、资源释放和性能经验。

## 1. 执行摘要

WallShift Advanced `v0.2.0` 只扫描 JPG、JPEG、PNG、WebP 和 BMP，并使用两个 QML `Image` 图层完成预加载、双缓冲和 Shader 转场。视频支持不能通过简单增加扩展名实现，因为视频还涉及解码器、首帧就绪判断、播放生命周期、音频、视频结束事件、暂停恢复、双解码器资源占用和不同后端的兼容性。

推荐采用以下总体方案：

1. 将“图片条目”抽象为统一的“媒体条目”，支持图片和本地视频。
2. 将 `WallpaperTransition.qml` 内部的两个 `Image` 图层重构为两个统一的 `MediaSlot`。
3. 每个 `MediaSlot` 根据媒体类型按需加载 `Image` 或 `MediaPlayer + VideoOutput`。
4. 第一版高级 Shader 转场采用“冻结两端画面后做转场”的方式，转场期间不要求视频持续运动。
5. 视频默认静音；首版不播放壁纸音频。
6. 视频默认播放一次，播放结束后切换下一项；同时提供最长播放时长保护。
7. 继续沿用“最后目标优先”的转场合并策略，不建立无限 FIFO 动画队列。
8. 视频功能初始默认关闭，让旧配置、纯图片用户和缺少多媒体组件的系统保持原行为。
9. `VideoSurface.qml` 作为明确的播放器后端边界；首版仅实现 QtMultimedia，但转场控制器不直接依赖其枚举。
10. 所有暂停来源由单一播放裁决器归并，只在目标状态变化时调用播放器。

首版应优先保证：不会崩溃、不会后台持续解码、不会产生音频、损坏视频可自动跳过、图片功能无回归。动态视频穿过所有 Shader 的效果可以放到后续版本。

---

## 2. `v0.2.0` 历史实现基线

### 2.1 当前扫描流程

- `contents/ui/main.qml`
  - 使用 `FolderListModel` 递归发现目录和文件。
  - `isImagePath()` 只接受 `jpg/jpeg/png/webp/bmp`。
  - 条目结构目前只有 `path`、`name`、`modified`。
  - `visibleImage`、`CurrentImage` 和 `CurrentIndex` 都以“图片”为语义。
- `contents/ui/config.qml`
  - 设置页重复实现了一套目录扫描和图片预览逻辑。
  - `isImagePath()` 同样只接受静态图片。

### 2.2 当前渲染与转场流程

- `contents/ui/WallpaperTransition.qml`
  - 内置 `imageA` 和 `imageB` 两个 `Image`。
  - 新图片先加载到非活动层，`Image.Ready` 后才开始动画。
  - 动画进行期间只保留最后一个目标源。
  - 转场完成后释放旧图层的 `source`。
- `contents/ui/ShaderTransitionOverlay.qml`
  - 通过两个 `ShaderEffectSource` 捕获旧图层和新图层。
  - 当前 `live: false`，实际是对转场起点画面进行静态采样。
  - 这一特性适合首版视频支持：视频可以在转场前暂停并以当前帧参与 Shader。

### 2.3 当前配置与包依赖

- `contents/config/main.xml` 没有任何视频配置项。
- Arch 包依赖包含 `plasma-workspace`、`qt6-declarative`，尚未包含 `qt6-multimedia`。
- 项目最低 Qt 版本为 6.4，因此设计不能依赖只在较新 Qt 中存在的接口。

### 2.4 必须保持的现有行为

- 图片目录、排序、随机不重复队列和定时轮换保持兼容。
- 所有现有 Shader、Bézier 曲线和鼠标扩散原点继续工作。
- `wallshift-next` 和 `Meta+F5` 对图片、视频和混合列表使用同一套“下一项”语义。
- 动画期间连续切换继续采用最后目标优先，不积压长动画队列。
- 旧配置无需迁移脚本即可继续运行。

---

## 3. 产品目标与非目标

### 3.1 首版目标

- 支持本地视频文件与图片混合轮换。
- 支持纯视频目录。
- 视频默认静音播放。
- 支持视频播放一次后自动切换下一项。
- 支持手动下一项、定时切换和视频自然结束切换。
- 支持视频与图片之间的瞬切、淡入淡出和冻结帧高级 Shader 转场。
- 损坏文件、无解码器、加载超时和首帧失败时自动跳过。
- 离开当前桌面、壁纸不可见或 Plasma Shell 关闭时停止无意义播放。
- 保持多屏独立配置和独立轮换。

### 3.2 首版明确不做

- 网络视频 URL、直播流、HLS、YouTube 等远程源。
- DRM 视频。
- 壁纸音频输出。
- 视频剪辑、时间轴、播放列表编辑器。
- 将视频自动转码为统一格式。
- 对所有 Linux 发行版承诺完全一致的编解码器集合。
- 多屏共享同一个解码器实例。
- HDR 色彩管理和音视频同步高级控制。
- 在设置页同时播放多个视频缩略图。

### 3.3 后续可选能力

- 视频片段起止点。
- 播放速度。
- 按显示器刷新率或节能状态限制帧率。
- 视频音频显式开启、音量和淡入淡出。
- 动态视频 Shader 转场，即转场时两端视频继续播放。
- 缓存缺失时主动生成视频缩略图。
- 按分辨率、时长、方向、编码过滤。
- 活动、虚拟桌面或显示器之间共享播放进度。

---

## 4. 核心设计决策

### 4.1 统一媒体模型

把当前条目从：

```js
{
    path: "/path/a.jpg",
    name: "a.jpg",
    modified: 123456789
}
```

扩展为：

```js
{
    path: "/path/a.mp4",
    url: "file:///path/a.mp4",
    name: "a.mp4",
    modified: 123456789,
    kind: "video",
    extension: "mp4"
}
```

第一阶段不要在扫描时读取时长、编码、分辨率等昂贵元数据。相关信息由即将播放的 `MediaPlayer` 按需提供，避免扫描大型目录时同时打开大量文件。

建议统一命名：

- `images` → `mediaItems`
- `visibleImage` → `selectedMediaPath` 或 `visibleMediaPath`
- `showImage()` → `showMedia()`
- `indexOfImage()` → `indexOfMedia()`
- `isImagePath()` → `mediaKindForPath()`
- `WallpaperTransition` 文件名可以暂时保留，以减少外部改动；内部 API 改为媒体语义。

### 4.2 首版扩展名范围

建议默认识别：

- 图片：`.jpg`、`.jpeg`、`.png`、`.webp`、`.bmp`
- 视频：`.mp4`、`.m4v`、`.webm`、`.mkv`、`.mov`

扩展名只用于候选分类，不代表系统一定能够解码。实际可播放能力由 Qt Multimedia 后端、FFmpeg/GStreamer 和系统编解码器决定。

首版不建议默认加入 GIF：Qt `Image` 对动图和静态图行为不同，而且它既不属于完整视频管线，也不适合直接套用视频结束策略。GIF/APNG 可以单独设计。

### 4.3 视频轮换语义

推荐首版默认策略：

- 图片：继续按 `RotateSeconds` 轮换。
- 视频：从头播放一次，收到 `EndOfMedia` 后切到下一项。
- 视频最长播放时间：可选保护值，默认 `0` 表示不额外限制。
- 视频加载失败：立即跳过。
- 手动按下一项：立即请求切换，不等待视频结束。

后续可增加三种模式：

1. `play_once`：播放一次后切换，推荐默认值。
2. `fixed_interval`：视频和图片都按统一间隔切换；视频不足时循环。
3. `loop_until_interval`：视频循环，直到定时器到期。

不要在首版同时实现过多模式。`play_once` 最符合“动态壁纸播放完再换下一张”的直觉，也最容易验证。

### 4.4 音频策略

首版强制：

- 优先设置 `MediaPlayer.activeAudioTrack: -1`，从源头禁用音轨。
- 默认不连接 `AudioOutput`；若特定后端必须创建，则同时使用 `AudioOutput.muted: true` 和 `volume: 0`。
- 配置页明确显示“视频壁纸默认静音”。
- 切换、暂停、错误和清理时确保不会残留音频。

后续若开放音频：

- 默认仍必须静音。
- 提供总开关和 `0–100%` 音量。
- 在锁屏、勿扰、视频不可见或系统休眠时立即静音。
- 多屏只允许一个明确指定的屏幕输出音频，避免每个屏幕同时播放。

### 4.5 转场期间的视频策略

建议分两级实现：

#### 首版：冻结帧转场

1. 旧视频暂停在当前帧。
2. 新视频解码出首帧后暂停。
3. `ShaderEffectSource` 以 `live: false` 捕获两端。
4. 执行现有 Shader 转场。
5. 转场结束后只恢复新活动视频。
6. 旧视频停止并释放资源。

优点：

- 与现有 Shader 架构天然兼容。
- 转场时不会同时执行双路解码和 Shader 动画。
- Qt 6.4 上风险更低。
- 转场画面可重复、容易测试。

#### 后续：动态视频转场

- 根据媒体类型把 `ShaderEffectSource.live` 设为 `true`。
- 转场期间两个播放器同时运行。
- 需要验证 `VideoOutput` 在各图形后端上能稳定作为纹理源。
- 需要性能降级策略：解码压力过高时自动切换到冻结帧或普通淡入淡出。

动态转场不能作为首版阻塞项。

---

## 5. 建议架构

### 5.1 新增 `MediaUtils.js`

职责：

- 根据扩展名判断 `image`、`video` 或 `unsupported`。
- 集中维护扩展名集合，避免 `main.qml` 和 `config.qml` 重复。
- 生成统一媒体条目。
- 提供填充模式映射和策略辅助函数。
- 提供纯函数，便于单元测试。

建议 API：

```js
function extension(path)
function kindForPath(path)
function isSupportedPath(path, includeImages, includeVideos)
function makeEntry(path, name, modified)
function nextDeadline(kind, duration, policy, configuredSeconds)
```

### 5.2 新增 `MediaSlot.qml`

`MediaSlot` 是双缓冲槽位，替代直接使用的 `Image`。

建议公开属性：

```qml
property string source
property string mediaKind       // image | video | none
property int fillMode
property size sourceSize
property bool active
property bool muted: true
property real volume: 0
property bool ready
property bool firstFrameReady
property bool failed
property bool playing
property int duration
property int position
readonly property Item visualItem
```

建议公开信号：

```qml
signal readyForTransition()
signal playbackEnded()
signal loadFailed(string reason)
signal playbackStateChanged()
```

建议公开方法：

```qml
function load(entry)
function play()
function pause()
function stop()
function unload()
function seekToStart()
```

实现原则：

- 图片分支使用 `Image`。
- 视频分支通过 `Loader` 按需加载 `VideoSurface.qml`。
- 非视频场景不应创建 `MediaPlayer`。
- `MediaSlot` 本身是一个 `Item`，可以直接作为 `ShaderEffectSource.sourceItem`。
- 任意时刻每个屏幕最多存在两个媒体槽位，最多两个播放器。
- 转场结束后立即卸载旧槽位的视频源，不能让旧解码器继续运行。

### 5.3 新增 `VideoSurface.qml`

建议组成：

```qml
import QtMultimedia
import QtQuick

Item {
    MediaPlayer {
        activeAudioTrack: -1
        /* source、状态和生命周期；显式 play() */
    }
    VideoOutput { /* fillMode、orientation、videoSink */ }
}
```

需要处理：

- `MediaPlayer.mediaStatus`
- `MediaPlayer.errorOccurred`
- `MediaPlayer.playbackState`
- `MediaPlayer.position`
- `MediaPlayer.duration`
- `EndOfMedia`
- `VideoOutput.videoSink` 的首帧信号

`VideoSurface.qml` 同时是后端适配边界。它对外暴露项目自己的 `readyForTransition`、`playbackEnded`、`loadFailed` 和播放控制接口，上层不得直接读取 QtMultimedia 枚举。未来只有在 QtMultimedia 出现无法规避的问题时，才评估增加 mpv 后端。

首帧就绪不能只看 `LoadedMedia` 或 `BufferedMedia`，因为“媒体已加载/缓冲”不一定表示 GPU 上已经有可显示的视频帧。采用以下分层策略：

1. 优先监听 `videoSink.videoFrameChanged`，收到第一个有效 `QVideoFrame` 后设置 `firstFrameReady`。
2. 若目标 Qt 6.4 环境无法可靠从 QML 接收该信号，以显式开始播放后 `position > 0` 作为兼容回退。
3. 两条路径都必须受首帧超时保护；超时后停止、清源并报告失败。

Qt 6.4 官方 QML 文档包含 `videoSink`、`activeAudioTrack` 和 `playbackState`，但没有较新 Qt 代码常用的 `MediaPlayer.autoPlay` 与 `playing`。最低版本实现必须显式调用 `play()`，并以 `playbackState === MediaPlayer.PlayingState` 判断状态。

### 5.4 重构 `WallpaperTransition.qml`

将：

```qml
Image { id: imageA }
Image { id: imageB }
```

替换为：

```qml
MediaSlot { id: slotA }
MediaSlot { id: slotB }
```

状态对象建议改为：

```qml
property string activeSlot: "a"
property var currentEntry
property var pendingEntry
property var queuedEntry
property string phase: "idle"
property bool transitionRunning: false
```

建议显式状态：

- `empty`
- `loading-current`
- `playing`
- `loading-next`
- `transitioning`
- `paused-hidden`
- `error-recovery`

不一定必须使用 QML `State` 类型，但代码中的状态值和允许的状态转换必须明确。

### 5.5 状态转换

#### 初始加载

```text
empty
  → load current entry
  → first frame/image ready
  → show immediately
  → playing
```

#### 正常切换

```text
playing
  → request next
  → load next into inactive slot
  → wait for image ready / video first frame
  → pause both video slots if using frozen-frame transition
  → transitioning
  → activate new slot
  → release old slot
  → play new video if applicable
  → playing
```

#### 连续请求

```text
transitioning + request X
  → replace queuedEntry with X
  → current transition continues
  → transition ends
  → if queuedEntry differs from active entry, start one follow-up transition
```

必须保留已实现的边界行为：如果最终目标绕回正在退出的媒体，仍应在当前动画完成后返回，而不是把请求误判为重复并忽略。

#### 错误恢复

```text
load next failed
  → unload failed slot
  → mark path failed for this scan generation
  → request next eligible item
  → if all items failed, stop rotation and show status
```

需要设置单次恢复上限，不能通过同步递归无限调用 `rotateNext()`。建议错误跳过使用 `Qt.callLater()`，并记录本轮已失败路径。

---

## 6. 图片与视频的转场矩阵

| 旧媒体 | 新媒体 | 瞬切 | 淡入淡出 | 高级 Shader 首版 | 后续动态 Shader |
|---|---|---:|---:|---:|---:|
| 图片 | 图片 | 支持 | 支持 | 现有行为 | 不适用 |
| 图片 | 视频 | 支持 | 支持 | 视频首帧冻结 | 可选 |
| 视频 | 图片 | 支持 | 支持 | 视频当前帧冻结 | 可选 |
| 视频 | 视频 | 支持 | 支持 | 两端冻结 | 可选 |

### 6.1 淡入淡出细节

- 新视频必须先出现首帧，才能开始改变透明度。
- 首版建议转场期间暂停新视频，避免淡入时已经跳过开头几秒。
- 转场完成后从首帧继续播放。
- 旧视频暂停后淡出，避免额外解码。

### 6.2 高级 Shader 细节

- `ShaderTransitionOverlay.qml` 的源由 `MediaSlot` 提供，而不是具体 `Image`。
- 首版继续使用 `live: false`。
- 捕获前调用 `scheduleUpdate()`。
- 确认 `hideSource: true` 不会让 `VideoOutput` 丢失纹理；若存在后端问题，改为槽位保持可见但置于 Shader 下层，并由遮罩控制。
- 如果视频纹理捕获失败，自动降级到普通淡入淡出，而不是黑屏或终止轮换。

---

## 7. 填充模式与画面方向

当前图片模式需要映射到 `VideoOutput.fillMode`：

| 当前模式 | 图片行为 | 视频建议行为 |
|---|---|---|
| Stretch | 拉伸 | Stretch |
| PreserveAspectFit | 完整显示并留边 | PreserveAspectFit |
| PreserveAspectCrop | 裁剪铺满 | PreserveAspectCrop |
| Tile | 平铺 | 不支持，回退到 PreserveAspectCrop |

视频不建议实现平铺：多个视频纹理副本会增加渲染成本，且视觉用途有限。设置页应在启用视频时说明 Tile 对视频会回退为“缩放并裁剪”。

还需要验证：

- 手机竖屏视频的旋转元数据。
- 带非方形像素的视频。
- 90°/180°/270° 方向。
- 视频内容比例在多屏不同分辨率下的裁剪一致性。

---

## 8. 配置设计

### 8.1 建议新增配置项

建议在 `main.xml` 中加入：

```xml
<entry name="IncludeImages" type="Bool">
  <default>true</default>
</entry>
<entry name="IncludeVideos" type="Bool">
  <default>false</default>
</entry>
<entry name="VideoPlaybackMode" type="String">
  <default>play_once</default>
</entry>
<entry name="VideoMuted" type="Bool">
  <default>true</default>
</entry>
<entry name="VideoVolume" type="Double">
  <default>0.0</default>
</entry>
<entry name="VideoMaxSeconds" type="Int">
  <default>0</default>
</entry>
<entry name="PauseVideoWhenHidden" type="Bool">
  <default>true</default>
</entry>
<entry name="VideoTransitionMode" type="String">
  <default>frozen_frame</default>
</entry>
```

首版 UI 可以只暴露：

- 包含图片。
- 包含视频。
- 视频播放策略。
- 最长播放时间。
- 隐藏时暂停。

`VideoMuted` 固定为 true，音量和动态 Shader 配置可以先写入架构但不在 UI 中开放，或者完全延后添加，避免形成尚未支持的公开承诺。

### 8.2 兼容策略

- `IncludeImages=true`、`IncludeVideos=false` 保证旧用户升级后行为完全不变。
- 保留 `CurrentImage` 和 `CurrentIndex` 键名可以减少迁移，但长期建议新增 `CurrentMedia`。
- 若新增 `CurrentMedia`，读取时优先新键，空值时回退 `CurrentImage`。
- 不删除旧键，至少跨两个稳定版本保留读取兼容。
- 当前图片路径如果升级后变成视频路径，不应导致配置解析错误。

### 8.3 设置页布局

建议新增“媒体类型”和“视频播放”分组：

```text
媒体类型
  [✓] 图片
  [ ] 视频（实验性）

视频播放
  播放结束：切换到下一项
  最长播放：不限 / 自定义秒数
  [✓] 壁纸不可见时暂停
  音频：静音（首版固定）
```

预览区：

- 图片继续显示缩略图。
- 视频首版显示统一视频图标、文件名和“视频”标签。
- 不在列表中自动播放视频。
- 后续可以按需点击预览，或缓存一张首帧缩略图。

计数文本从“X 张图像”改为：

- `X 个媒体文件`
- 或分别显示 `X 张图片，Y 个视频`

---

## 9. 定时器与播放结束协调

当前 `rotateTimer` 始终按固定秒数运行。加入视频后要避免“视频结束事件”和“固定定时器”同时触发两次。

建议规则：

### `play_once`

- 当前是图片：启动固定轮换定时器。
- 当前是视频：停止固定轮换定时器。
- 视频 `EndOfMedia`：调用统一的 `requestNext("video-ended")`。
- 如果设置了 `VideoMaxSeconds > 0`，启动独立的一次性保护定时器。

### `fixed_interval`

- 图片和视频都使用固定轮换定时器。
- 视频结束时从头循环，不触发下一项。

### 所有模式

- 手动下一项先停止当前条目的相关一次性定时器。
- 转场进行期间到期的自动请求采用最后目标优先规则。
- 自动请求和手动请求必须进入同一个调度函数，避免重复逻辑。
- 给每次播放分配 generation/token；过期播放器发出的 `EndOfMedia` 必须被忽略。

建议统一入口：

```js
function requestNext(reason) {
    // reason: timer | video-ended | shortcut | context-menu | error
}
```

---

## 10. 可见性、暂停和资源生命周期

### 10.1 活动槽位

- 当前媒体是视频且壁纸可见时播放。
- 当前媒体是图片时不创建视频解码器。
- 设置页打开不应重复创建桌面播放器。

播放控制采用单一裁决器，而不是让可见性、锁屏、转场和用户操作分别直接调用 `play()`/`pause()`：

```text
desiredPlaying = activeSlot
              && mediaKind == video
              && phase == playing
              && pauseReasons is empty
```

每个视频槽保存 `desiredPlaybackState`、`appliedPlaybackState` 和 `sourceGeneration`。只有目标状态发生变化且 generation 仍匹配时才向后端下发命令。

### 10.2 非活动槽位

- 只在即将切换时加载下一项。
- 视频解码出首帧后立即暂停等待。
- 转场完成后旧槽位调用 `stop()`，清空 `source`，必要时销毁 Loader。

### 10.3 壁纸不可见

需要调查 Plasma `WallpaperItem` 在以下场景中的可见性信号：

- 显示桌面与普通窗口覆盖。
- 切换虚拟桌面。
- 切换 Activity。
- 显示器关闭或 DPMS。
- 锁屏。
- Plasma Shell 重载。

最低要求：

- `root.visible === false` 时暂停。
- 重新可见时从原位置继续，而不是重新开始。
- 锁屏期间不得继续输出音频。
- Plasma Shell 销毁组件时播放器必须随对象销毁停止。

若 `visible` 不能准确反映桌面是否被覆盖，不要为了“窗口覆盖就暂停”引入高频窗口监控。首版只处理能够可靠获得的生命周期事件。

最大化/全屏窗口、电池阈值和桌面效果联动已被成熟项目证明可行，但涉及 TaskManager、PowerDevil、屏幕状态或 Wayland 协议。它们应在基础播放稳定后独立加入，不能阻塞 `v0.4.0`。

### 10.4 休眠与恢复

- 恢复后检查播放器状态，不假设后端仍在播放。
- 若解码管线进入错误，重新加载当前视频一次。
- 防止恢复瞬间旧的 `EndOfMedia` 触发误切换。
- 使用 generation token 忽略恢复前的过期回调。

---

## 11. 多屏设计

Plasma 会为每个桌面/屏幕创建独立壁纸实例，因此首版采用每屏独立播放器。

需要接受的结果：

- 两个屏幕播放同一视频时可能存在两套解码器。
- 两个屏幕的播放起点可能有轻微差异。
- 每个屏幕可以使用不同目录、不同视频和不同播放进度。

首版优化：

- 每个实例最多两个播放器，只有活动播放器持续播放。
- 待切换播放器只解码首帧并暂停。
- 转场完成立即释放旧播放器。
- 不进行跨实例 D-Bus 同步。

未来若需要同步多屏：

- 需要一个共享播放服务或统一纹理源。
- 复杂度、生命周期和打包成本明显提高。
- 应作为独立项目阶段，不与基础视频支持绑定。

---

## 12. 错误处理与降级

### 12.1 错误类别

- 文件不存在或在扫描后被删除。
- 权限不足。
- 容器可识别但编码不支持。
- 文件损坏。
- 解码器初始化失败。
- 首帧超时。
- 视频输出纹理无法被 Shader 捕获。
- 播放中途后端错误。
- 空视频或零时长视频。

### 12.2 建议行为

| 错误 | 行为 |
|---|---|
| 加载失败 | 记录原因，本轮跳过 |
| 首帧超时 | 停止并跳过 |
| Shader 捕获失败 | 降级为淡入淡出 |
| 播放中错误 | 切换下一项 |
| 所有媒体失败 | 保留最后成功画面并显示状态 |
| QtMultimedia 不可用 | 禁用视频，图片继续工作 |

### 12.3 防止错误循环

- 每次扫描 generation 维护 `failedPaths`。
- 同一路径在本轮最多尝试一次。
- 连续失败不得同步递归调用。
- 当失败数等于媒体总数时停止自动轮换。
- 目录发生变化或用户保存设置后清空失败集合。
- 日志包含路径、媒体类型、Qt 错误码和错误字符串，但不输出过量重复日志。

---

## 13. 性能预算与降级策略

### 13.1 资源约束

每屏应满足：

- 常态最多一个持续播放的视频解码器。
- 预加载阶段最多短时存在第二个解码器。
- 转场结束后一个事件循环内开始释放旧源。
- 纯图片模式不加载 Qt Multimedia QML 组件。
- 设置页不批量启动视频解码。

### 13.2 测试分辨率

至少覆盖：

- 1920×1080 H.264 MP4。
- 2560×1440 视频。
- 3840×2160 视频。
- 竖屏 1080×1920 视频。
- VP9 WebM。
- 一个系统不支持的编码样本。

### 13.3 性能降级顺序

检测到动态 Shader 或双路播放压力过高时，按以下顺序降级：

1. 动态视频 Shader → 冻结帧 Shader。
2. 冻结帧 Shader失败 → 普通淡入淡出。
3. 淡入淡出失败 → 瞬切。
4. 视频解码失败 → 跳过视频并继续图片。

首版不建议自动修改视频分辨率或调用外部转码器。

也不要未经测量就加入软件 `fps` 过滤或定时丢帧。参考项目的实测经验表明，此类处理可能迫使硬件帧回读并提高而非降低功耗。首版保持后端默认帧路径，优化必须同时观察 CPU、GPU 视频引擎、GPU 渲染引擎和整机功耗。

### 13.4 可观测指标

- 从设置保存到首帧出现的时间。
- 手动切换到视频的首帧等待时间。
- 活动播放器数量。
- 转场期间是否同时播放两路视频。
- 视频切走后是否仍有解码活动。
- Plasma Shell 的 CPU、GPU 和内存变化。

目标不应只写“流畅”，而应记录测试机器、视频编码、分辨率、屏幕数量和图形后端。

---

## 14. 依赖与打包

### 14.1 Qt 依赖

代码层新增：

```qml
import QtMultimedia
```

Arch 包建议新增：

```bash
depends+=(qt6-multimedia)
```

其他发行版需要在文档中列出等价 QML 模块包，例如 Debian/Ubuntu 系的 Qt 6 Multimedia QML 模块。具体包名应在实现时通过目标发行版实际验证，不在设计阶段写死未经验证的名称。

### 14.2 编解码后端

- Qt Multimedia 能打开某个容器，不代表系统具备对应视频编码解码器。
- README 应明确“格式支持取决于系统 Qt Multimedia 后端”。
- 不把完整 FFmpeg/GStreamer 插件集合设为硬依赖，除非目标发行版确实要求。
- AUR `optdepends` 可以补充常见编解码支持说明，但不能承诺法律或专利受限编码在所有地区可用。

### 14.3 可选依赖还是硬依赖

有两种方案：

1. **硬依赖 `qt6-multimedia`**：实现和测试简单，推荐用于正式发布视频功能。
2. **可选依赖**：通过 Loader 延迟加载，缺少模块时仍可用图片；但错误检测、设置页提示和分发测试更复杂。

建议首个公开视频版本使用硬依赖，避免用户启用视频后只得到难以理解的 QML 模块缺失错误。若后续确认体积和发行版体验需要，再改为可选依赖。

### 14.4 KDE Store

- KDE Store 的壁纸包不能自动安装系统 Qt 模块。
- 商品说明必须写明 Qt Multimedia 要求。
- 若系统缺少模块，插件应尽量继续提供图片功能，而不是整个壁纸组件加载失败。
- 发布前必须在“缺少 QtMultimedia”环境验证降级；如果 QML 静态 import 导致整个组件失败，应保留动态 Loader 隔离设计。

---

## 15. 测试计划

### 15.1 纯函数测试

为 `MediaUtils.js` 覆盖：

- 大小写扩展名。
- 路径包含空格、中文、`#`、`%` 和单引号。
- 不支持扩展名。
- 图片/视频开关组合。
- 排序稳定性。
- 随机队列不重复。
- 视频时长策略。

### 15.2 QML 组件测试

为 `MediaSlot` 覆盖：

- 图片成功和失败。
- 视频首帧成功。
- 视频无解码器错误。
- 视频播放结束。
- 暂停、恢复、停止和卸载。
- 清空源后旧事件不会污染新媒体。

为 `WallpaperTransition` 覆盖：

- 图片 → 图片。
- 图片 → 视频。
- 视频 → 图片。
- 视频 → 视频。
- 转场时连续请求只保留最终目标。
- 两项列表快速绕回当前项。
- 请求正在进入的媒体可取消旧的补跳。
- 新视频首帧超时。
- 当前视频播放中报错。

### 15.3 Shader 测试

- 每种 Shader 至少测试一次图片 → 视频和视频 → 图片。
- 检查转场首帧不是黑色或透明。
- 检查 `hideSource` 不导致视频输出消失。
- 检查转场结束后只有新槽位可见。
- 随机效果池对视频仍只选择启用效果。

### 15.4 手工矩阵

| 维度 | 覆盖项 |
|---|---|
| Plasma | 最低支持版本、当前稳定版本 |
| Qt | 6.4、当前系统版本 |
| 会话 | Wayland，X11 可作为兼容项 |
| 屏幕 | 单屏、双屏、不同缩放比例 |
| GPU | Intel/AMD 至少各一组；NVIDIA 有条件覆盖 |
| 内容 | 纯图片、纯视频、混合目录 |
| 排序 | 名称、修改时间、随机 |
| 控制 | 定时、右键下一项、Meta+F5 |
| 生命周期 | 锁屏、休眠、显示器关闭、重启 plasmashell |

### 15.5 回归测试

- 视频功能关闭时，文件列表与旧版本一致。
- 图片转场视觉和时长不变。
- 鼠标扩散原点不受影响。
- Bézier 编辑器和设置页拖动不受影响。
- 目录递归扫描不引入明显延迟。
- `make check`、Arch `makepkg`、KDE Store 归档继续通过。

---

## 16. 分阶段交付计划

### 阶段 0：技术验证

目标：证明 Qt 6.4 下视频纹理可用于当前渲染路径。

任务：

- 建立最小 `MediaPlayer + VideoOutput` 原型。
- 确认原型严格使用 Qt 6.4 API：显式 `play()`、读取 `playbackState`，不使用 `autoPlay` 或 `playing`。
- 验证本地 MP4/WebM 播放。
- 验证 `videoSink.videoFrameChanged → position > 0 → timeout` 的分层首帧检测。
- 用 `activeAudioTrack: -1` 验证带音轨视频不会产生声音或意外音频会话。
- 验证 `VideoOutput` 能被 `ShaderEffectSource` 捕获。
- 验证暂停后冻结帧仍可参与所有现有 Shader。
- 若直接捕获失败，验证一次性图像快照代理和普通 opacity 淡入淡出的降级可行性。
- 验证两个播放器短时共存的资源行为。
- 验证 `stop()`、清空 source、销毁 Loader 后解码活动消失。
- 验证 Plasma 壁纸上下文，而不仅是独立 `qml6` 窗口。

退出条件：

- 至少一种常见 MP4 和一种 WebM 可播放。
- 带音轨样本始终静音。
- 图片 → 视频和视频 → 图片无黑帧。
- 无法 Shader 捕获时有明确可实施的淡入淡出降级方案。

### 阶段 1：统一媒体扫描

任务：

- 新增 `MediaUtils.js`。
- 抽取主界面和设置页共享的类型识别规则。
- 引入 `mediaItems` 数据模型。
- 设置页显示图片和视频数量。
- 加入 `IncludeVideos`，默认关闭。
- 暂不真正播放视频，可先显示占位符。

退出条件：

- 旧图片目录结果完全一致。
- 视频开关能稳定改变候选列表。
- 排序和随机逻辑适用于混合条目。

### 阶段 2：基础视频播放

任务：

- 新增 `MediaSlot.qml` 和 `VideoSurface.qml`。
- 先支持单槽立即显示。
- 视频默认静音。
- 支持 `EndOfMedia` 切换。
- 支持手动下一项。
- 支持加载失败自动跳过。
- 支持视频最大时长保护。

退出条件：

- 纯视频目录可连续运行至少一小时。
- 损坏文件不会阻塞轮换或崩溃。
- 切走视频后解码停止。

### 阶段 3：双缓冲和基本转场

任务：

- 两个 `MediaSlot` 替代两个 `Image`。
- 完成四种媒体组合的瞬切和淡入淡出。
- 实现视频首帧预加载。
- 接入最后目标优先队列。
- 处理两项列表快速切换。

退出条件：

- 所有媒体组合无黑帧。
- 连续按键不积压动画。
- 最终索引与最终可见内容一致。

### 阶段 4：冻结帧高级 Shader

任务：

- 将 `MediaSlot` 作为 Shader 源。
- 转场前暂停视频。
- 转场后恢复新视频并释放旧视频。
- Shader 失败时降级。
- 全部现有效果加入测试矩阵。

退出条件：

- 十种现有效果均可处理视频组合，或有可预测降级。
- 转场期间没有双路持续解码。
- 转场结束没有残留隐藏播放器。

### 阶段 5：生命周期与性能

任务：

- 隐藏暂停和恢复。
- 锁屏、休眠、DPMS 测试。
- 多屏资源测试。
- 4K 视频测试。
- 错误去重和诊断日志。
- 设置页说明和翻译。

退出条件：

- 常见生命周期操作后播放状态正确。
- 多屏不会无限增加播放器。
- 日志无持续错误刷屏。

### 阶段 6：实验发布

任务：

- 更新 README、Changelog、截图和 KDE Store 文案。
- 更新 Arch 依赖和 `.SRCINFO`。
- 构建 KDE Store 归档和 Arch 包。
- 在发布说明中标注“视频支持实验性”。
- 收集后端、编码、GPU 和发行版兼容反馈。

建议版本：

- 当前快捷键和队列改进可先进入 `v0.3.x`。
- 视频实验版建议 `v0.4.0`。
- 视频经过至少一个小版本稳定后，再考虑默认启用。

### 阶段 7：增强功能

- 动态视频 Shader。
- 缓存缺失时主动生成视频缩略图。
- 视频音频可选支持。
- 片段起止点和播放速度。
- 更完整的节能策略。
- 多屏同步播放的独立技术评估。

---

## 17. 建议的提交/PR 拆分

不要一次提交全部功能。建议按以下顺序拆分：

1. `Refactor media type detection into MediaUtils`
2. `Add opt-in video entries to folder scanning`
3. `Introduce MediaSlot abstraction without behavior changes`
4. `Add muted local video playback`
5. `Advance playlist when video playback ends`
6. `Add video first-frame preload and timeout recovery`
7. `Support mixed media crossfades`
8. `Support frozen-frame shader transitions for video`
9. `Pause video when wallpaper is hidden`
10. `Add video settings and translations`
11. `Package Qt Multimedia runtime dependencies`
12. `Document supported formats and diagnostics`

每一步都应保持图片模式可运行，并有明确的回滚点。

---

## 18. 风险清单

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| Qt 6.4 视频纹理接口差异 | Shader 无法捕获 | 阶段 0 验证；降级淡入淡出 |
| 系统缺少解码器 | 视频打不开 | 错误提示、自动跳过、格式说明 |
| 双屏重复解码 | CPU/GPU 占用高 | 每屏只保持一个活动播放器 |
| 两路视频转场过重 | 掉帧 | 首版冻结帧转场 |
| 首帧检测不可靠 | 黑帧 | VideoSink 信号 + 超时 + 后端矩阵 |
| 视频结束与定时器重复触发 | 一次跳两项 | 根据模式只启用一个主触发源 |
| 旧播放器延迟事件 | 错误切换 | generation token |
| 快速连续切换 | 状态错位 | 最后目标优先、状态机测试 |
| 设置页视频预览过多 | 高资源占用 | 只读取 KDE 静态缩略图缓存，缺失时显示图标 |
| QtMultimedia 缺失 | 插件加载失败 | 动态 Loader 隔离或硬依赖 |
| 视频音频意外播放 | 严重体验问题 | 首版强制静音并测试 |
| 休眠恢复后管线失效 | 黑屏/卡住 | 恢复检查并允许重载一次 |
| 使用较新 Qt QML 属性 | Qt 6.4 加载失败 | 禁用 `autoPlay`/`playing`，按最低版本实机验证 |
| 多暂停来源互相覆盖 | 被锁定/隐藏时错误复播 | 单一播放裁决器、desired/applied 去重 |
| 盲目限帧破坏硬件路径 | 功耗反而上升 | 不默认限帧；按视频引擎、渲染引擎和整机功耗测量 |

---

## 19. 验收标准

首个实验版本至少满足：

1. 关闭视频开关时，与当前图片版本行为一致。
2. MP4、WebM 在测试系统可正常播放，其他格式按后端能力处理。
3. 视频默认且始终静音。
4. 视频播放结束只切换一次。
5. 图片和视频混合目录可按名称、修改时间和随机模式轮换。
6. 四种媒体组合均支持瞬切和淡入淡出。
7. 高级 Shader 至少能通过冻结帧工作；失败时自动降级。
8. 连续按下一项不会形成无限动画队列，最终内容与最终索引一致。
9. 两个媒体条目的列表可快速来回切换，不出现状态错位。
10. 损坏或不支持的视频不会导致 Plasma Shell 崩溃。
11. 所有文件失败时停止重试并保留可理解的状态。
12. 多屏下每屏最多一个持续播放的视频。
13. 视频切走后旧播放器停止并释放源。
14. Plasma Shell 重启后能够恢复当前媒体或安全回退到第一项。
15. `make check`、Arch 构建、KDE Store 归档和 AppStream 验证通过。

---

## 20. 实施前必须回答的开放问题

阶段 0 完成后需要记录并锁定以下结论：

1. Qt 6.4 中 `VideoOutput.videoSink.videoFrameChanged` 能否稳定用于首帧检测？
2. `VideoOutput` 是否能在目标 GPU/后端上被 `ShaderEffectSource` 正确捕获？
3. `hideSource: true` 是否对视频纹理存在兼容问题？
4. KDE Plasma 壁纸实例在虚拟桌面、Activity、锁屏和 DPMS 下会暴露哪些可靠可见性信号？
5. Arch、Debian/Ubuntu 和 Fedora 的 Qt Multimedia 包与编解码后端分别是什么？
6. 视频自然结束后是立即转场，还是保留末帧等待短暂间隔？推荐立即转场。
7. 视频最长播放时间是否需要在首版公开？推荐提供，但默认不限。
8. Tile 模式对视频的回退应为裁剪铺满还是保持比例？推荐裁剪铺满。
9. 缺少 Qt Multimedia 时，是禁用视频还是把模块设为硬依赖？推荐正式发布时硬依赖，同时保留动态加载边界。

源码调研和 Qt 6.4 文档已经锁定以下结论，不再作为开放设计项：

- Qt 6.4 提供 `VideoOutput.videoSink`，但其 QML 信号可用性仍需在阶段 0 实机验证。
- Qt 6.4 基线不得使用 `MediaPlayer.autoPlay` 和 `playing`；使用显式 `play()` 与 `playbackState`。
- 首版通过 `activeAudioTrack: -1` 禁用音轨，并以无 `AudioOutput` 或强制静音作为后端兼容策略。
- 当前参考 mpv/`QQuickRhiItem` 后端要求 Qt 6.7+，不能作为本项目 Qt 6.4 首版实现。
- 播放暂停必须由单一裁决器归并，不能由多个事件处理器直接互相覆盖。

这些问题应由原型和实际测试回答，而不是仅凭 API 文档假设。

---

## 21. 推荐的第一步

先创建一个不接入设置页、不修改扫描逻辑的技术分支，仅完成以下原型：

1. 新建 `VideoSurface.qml`。
2. 写死加载一个本地短 MP4。
3. 验证首帧检测、暂停、恢复和结束事件。
4. 把该 `VideoOutput` 交给现有 `ShaderTransitionOverlay.qml`。
5. 分别验证 Fade、Grow、Pixelate、Portal。
6. 记录 Qt 版本、图形后端、GPU、视频编码、CPU/GPU 占用和所有错误日志。

只有该原型证明视频纹理路径可靠后，才开始重构扫描和双缓冲。这样可以在投入大规模改造前尽早暴露最关键的技术风险。

---

## 22. 参考资料

- [`video-wallpaper-reference-study.md`](video-wallpaper-reference-study.md)：本项目的源码级对标分析、采用/拒绝理由和 Go / No-Go 门槛。
- [Smart Video Wallpaper Reborn](https://github.com/luisbocanegra/plasma-smart-video-wallpaper-reborn)
- [Wallpaper Engine for KDE](https://github.com/RainyPixel/wallpaper-engine-kde-plugin)
- [linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine)
- [Fresco](https://github.com/DibbayajyotiRoy/Fresco)
- [Qt 6.4 VideoOutput QML Type](https://doc.qt.io/archives/qt-6.4/qml-qtmultimedia-videooutput.html)
- [Qt 6.4 MediaPlayer QML Type](https://doc.qt.io/archives/qt-6.4/qml-qtmultimedia-mediaplayer.html)

---

## 23. 2026-10-03 原型与首轮实现结果

当前开发机环境为 Plasma 6.7.5、Qt 6.11.2、Qt Multimedia FFmpeg 后端 n9.0.2。以下结论均已通过可重复脚本验证：

- `tools/run-video-prototype.sh`：在独立 QML 窗口分别验证 H.264/AAC MP4 与 VP9/Opus WebM。
- `tools/run-video-plasma-prototype.sh`：将同一场景临时安装为独立 Plasma 壁纸包，在真实 `plasmashell` 中验证后自动恢复桌面并卸载测试包。
- `tools/run-media-integration-prototype.sh`：验证正式 `main.qml`、统一媒体扫描、双 `MediaSlot`、自然结束切换、latest-wins、损坏视频恢复和单视频循环。

已确认：

1. `videoSink.videoFrameChanged` 可用于当前环境的首帧检测，测试样本均在 `position == 0` 时先收到可显示帧。
2. MP4 与 WebM 均能在图片/视频统一双槽中预加载；图片 → 视频、视频 → 图片和视频 → 视频可完成转场。
3. Fade 以及 Simple、Wipe、Wave、Grow、Outer、Stripes、Pixelate、Iris、Portal 全部能从暂停的视频帧取得非黑纹理。
4. 带音轨样本的 `activeAudioTrack` 最终保持 `-1`；同时连接 `muted: true`、`volume: 0` 的 `AudioOutput`。实测只禁用音轨而完全不连接音频输出时，当前 FFmpeg 后端曾错误地快速推进播放位置，因此保留双重静音保护。
5. 轨道发现时后端可能把 `activeAudioTrack` 暂时重置为 `0`，实现必须在 `tracksChanged` 与 `activeTracksChanged` 后再次设为 `-1`。
6. 清空 source 后 `mediaStatus` 会进入 `NoMedia`，但当前后端的 `playbackState` 仍可能停留在 `PausedState`；资源释放判断不能只依赖 `playbackState`。
7. 4 秒测试视频可在结束前冻结末帧并自动切换下一项；只有一个可播放视频时会从头重播。
8. 视频播放期间连续三次切换只执行当前转场和最后目标，不积压完整动画队列。
9. 正在加载的损坏视频即使失败，也不会丢弃随后到达的最终目标；损坏源会清空并加入本轮失败集合。

尚未关闭的发布门槛：

- 当前代码只按 Qt 6.4 官方 API 编写并通过 Qt 6.11.2 静态/实机测试，仍需在真正的 Qt 6.4 运行环境执行同一组脚本。
- 仍需补充长时间循环、休眠恢复、锁屏/解锁、多屏独立实例和不同图形后端测试。
- 仍需测量双播放器短时共存时的 CPU、GPU 视频引擎、显存和整机功耗，不能仅凭非黑帧测试判断性能达标。

---

## 24. 2026-10-03 发布候选审计

已完成：

- 将 helper、systemd unit 和 KWin 脚本移出 Plasma Wallpaper 包，KDE Store 归档现在只有一个 `metadata.json`，不再触发嵌套 KPackage 类型警告。
- 版本、Changelog、本地 Arch 配方和 KDE Store 提交文案已更新为 `0.4.0`。
- 增加可复现归档、包边界检查、systemd unit 校验和 AppStream 严格验证的 `make release-check`。
- 修复 Plasma 6 配置宿主属性及 Kirigami 主题颜色兼容警告；实机重新打开设置页后未发现 WallShift QML 错误。
- `make release-check`、本地 Arch 包构建和正式混合媒体集成原型均已通过。

分发前仍需选择：

- 若继续声明最低 Qt 6.4，应先在真正的 Qt 6.4 环境执行三套原型；否则必须把发布说明明确标注为仅在 Qt 6.11.2 实测。
- GitHub tag/Release 创建后，再用真实 GitHub 源码归档校验值更新稳定版 AUR 配方。
- KDE Store 需要登录后手动创建产品；其归档不包含可选的 `Meta+F5` companion。
