# PlasmaWallShift Advanced 视频壁纸参考项目调研

> 调研日期：2026-10-03
> 调研方式：在线资料核对 + 浅克隆源码 + 关键播放/渲染/生命周期链路阅读
> 目的：为 WallShift Advanced 的 `v0.4.0` 实验性视频支持选择低风险架构；本次不直接移植第三方代码

## 1. 结论先行

WallShift Advanced 首版视频支持仍应采用 **纯 QML Qt Multimedia + 两个统一媒体槽位 + 冻结帧 Shader 转场**，但应在原路线之上补充四项约束：

1. **把播放器封装成后端边界，而不是把 QtMultimedia 状态散落到转场控制器。** `VideoSurface.qml` 对外只暴露加载、首帧、播放、暂停、停止、结束和错误；将来才有可能替换为 mpv 后端。
2. **用单一播放裁决器合并所有暂停原因。** 活动槽位、组件可见性、锁屏、DPMS、Activity、手动暂停和错误状态共同计算一个 `shouldPlay`，只有最终值变化时才调用播放器。
3. **首帧判定必须分层。** 优先监听 `VideoOutput.videoSink.videoFrameChanged` 的有效帧；以播放位置前进作为兼容回退；`LoadedMedia`/`BufferedMedia` 只能表示管线状态，不能单独证明画面已经可见；最终必须有超时。
4. **严格按 Qt 6.4 API 编写。** Qt 6.4 已提供 `VideoOutput.videoSink`、`MediaPlayer.activeAudioTrack` 和 `playbackState`，但其文档没有较新代码常用的 `autoPlay`、`playing`。因此首版必须显式调用 `play()`，以 `playbackState === MediaPlayer.PlayingState` 判断状态，并用 `activeAudioTrack: -1` 从源头禁用音轨。

不建议首版采用 libmpv、外部守护进程或 `QQuickRhiItem`：这些路线能提供更强的硬件解码控制和诊断能力，但会显著提高编译、ABI、图形后端、分发和 Plasma Shell 稳定性风险，而且当前 Wallpaper Engine KDE 的 `QQuickRhiItem` 后端明确要求 Qt 6.7+，不符合本项目 Qt 6.4 的最低目标。

## 2. 调研样本与快照

| 项目 | 定位 | 本地快照 | 许可证 | 主要价值 |
|---|---|---|---|---|
| [Smart Video Wallpaper Reborn](https://github.com/luisbocanegra/plasma-smart-video-wallpaper-reborn) | Plasma 6 原生视频壁纸插件 | `865a20aded54a854afcacbd00ed23a6c5fc0e105` | GPL-2.0 | 与本项目运行环境最接近；QtMultimedia、双播放器淡入淡出、窗口/电池/锁屏暂停 |
| [Wallpaper Engine for KDE](https://github.com/RainyPixel/wallpaper-engine-kde-plugin) | Plasma 6 Wallpaper Engine 集成 | `b9fd9b349c17695609aaae0ab40f68639ee8c643` | GPL-2.0 | QML QtMultimedia 与原生 mpv 双后端、首帧事件、跨实例同步和后端隔离 |
| [linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine) | 独立 C++ Wallpaper Engine 兼容渲染器 | `b016d7d1fdcf4e5fd2f9c9fa420a8aaa07fee02d` | GPL-3.0 | libmpv 直接渲染到 OpenGL FBO、资源计数和明确销毁生命周期 |
| [Fresco](https://github.com/DibbayajyotiRoy/Fresco) | 跨桌面视频壁纸应用/守护进程 | `a7e52472bd69745120117b3b393ad0b14c58a15d` | GPL-3.0-or-later | 每屏播放器监督、暂停原因归并、多屏漂移校正、性能与诊断工程化 |

源码浅克隆保存在临时目录 `/tmp/opencode/video-wallpaper-reference/`，不加入项目仓库，也不构成运行时或构建依赖。

## 3. Smart Video Wallpaper Reborn

### 3.1 播放器封装

关键文件：

- `package/contents/ui/VideoPlayer.qml`
- `package/contents/ui/FadePlayer.qml`
- `package/contents/ui/main.qml`
- `package/contents/ui/TasksModel.qml`
- `package/contents/ui/ScreenModel.qml`

`VideoPlayer.qml` 把 `MediaPlayer`、`VideoOutput`、`AudioOutput` 和填充模糊封装为单个重型对象。`FadePlayer.qml` 在切换时动态创建下一播放器，并用 `StackView.replace()` 保留旧播放器到淡入结束，随后主动 `destroy()`，避免重型视频对象长期堆积。

可借鉴之处：

- 视频对象按需创建，而不是在设置页或每个候选项上常驻。
- 新播放器先加载，再替换当前播放器。
- 切换结束后尽早销毁旧播放器，而不是只隐藏。
- 播放状态由上层 `shouldPlay` 属性集中下发。
- 用调试叠层记录媒体状态、位置、时长、加载时间、暂停来源和当前文件。

不能直接照搬之处：

- 它使用 `autoPlay`、`player.playing` 等较新 Qt API，本项目最低 Qt 6.4 不能假设存在。
- `replaceWhenLoaded()` 通过枚举数值大小判断“加载完成”，没有严格区分可播放与无效媒体；WallShift 应明确匹配状态并等待真正首帧。
- 首帧以 `position > 0` 判定，并在 200 ms 后再次同步播放状态。这是有价值的兼容回退，但不能作为唯一判据。
- 为提前交叉淡入，它按“剩余时长小于转场时长/预加载时长”触发下一项，并承认可能来不及加载。WallShift 首版以播放结束切换为主，不应引入这种估算竞态。
- `StackView` 的转场排队语义不等于 WallShift 已实现的 latest-wins，不能牺牲当前快速切换行为。

### 3.2 生命周期裁决

该项目把以下因素归并为最终 `playing`：

- 最大化或全屏窗口、活动窗口、任意可见窗口；
- 当前 Activity；
- 电池阈值；
- 屏幕锁定和屏幕关闭；
- Plasma 桌面效果；
- 用户临时播放/暂停覆盖。

最值得借鉴的不是所有功能，而是 **只产生一个最终播放意图**。WallShift 首版可以只实现可靠来源，但内部应从一开始采用类似模型：

```text
pauseReasons = hidden | inactive-slot | locked | screen-off | user | error
shouldPlay = currentKind == video && pauseReasons is empty && phase == playing
```

各信号只更新原因，不直接各自调用 `play()`/`pause()`，从而避免恢复顺序不同导致错误复播。

### 3.3 分发与故障经验

其 README 明确要求发行版安装 Qt Multimedia 及编解码后端，并提供硬件纹理转换、FFmpeg/GStreamer 后端和日志诊断建议。这说明：

- “支持 MP4”只能表示候选容器，不能承诺具体编码一定可解码。
- KDE Store 包无法代替系统安装多媒体模块；依赖提示必须在商品页和插件设置页都可见。
- 视频插件可能导致 plasmashell 崩溃循环，因此 WallShift 必须让视频默认关闭，并保留不加载 QtMultimedia 的纯图片路径。

## 4. Wallpaper Engine for KDE

### 4.1 双后端结构

关键文件：

- `plugin/contents/ui/backend/QtMultimedia.qml`
- `plugin/contents/ui/backend/Mpv.qml`
- `src/backend_mpv/MpvBackend.cpp`
- `plugin/contents/ui/main.qml`
- `src/WallpaperSyncBus.cpp`

其 QML 层通过 Loader 选择 QtMultimedia 或 mpv 后端。两个后端都向上提供相似的 `source`、`play()`、`pause()`、`stop()`、音量和显示模式能力。这验证了“先定义窄接口，再绑定具体播放器”是可行路线。

对 WallShift 的启示：

- `MediaSlot` 只面对 `VideoSurface` 的统一接口。
- `VideoSurface` 的 QtMultimedia 实现是 v0.4 唯一后端，但命名和信号不应包含 Qt 专属枚举。
- 不需要现在实现后端选择 UI，也不需要提前引入 C++ 插件。

### 4.2 mpv 与 Qt Quick RHI

当前 mpv 后端继承 `QQuickRhiItem`，由 mpv 软件渲染接口写入对齐的 CPU 缓冲区，再上传到 `QRhiTexture`；首次 dirty/redraw 时发出 `firstFrame()`。它的价值在于：

- 首帧事件来自“渲染器确实得到可绘制帧”，而不是媒体元数据状态。
- 播放控制、源切换和渲染线程更新有明确边界。
- 销毁渲染器时解除回调、停止 mpv 并释放 render context。

但该项目 README 标明 `QQuickRhiItem` 路线要求 Qt 6.7+。此外，软件帧到 QRhi 纹理的逐帧上传会增加拷贝成本。因此它适合作为未来后端研究样本，不适合 WallShift v0.4。

### 4.3 多屏同步

`WallpaperSyncBus` 使用会话 D-Bus 广播全局配置变化，并识别主屏实例。WallShift 当前坚持每屏独立配置，这部分不应直接引入；可保留的思想是：跨实例同步必须明确指定权威实例和消息来源，不能依赖各屏同时启动“恰好同步”。

## 5. linux-wallpaperengine

关键文件：

- `src/WallpaperEngine/Render/Wallpapers/CVideo.cpp`
- `src/WallpaperEngine/VideoPlayback/MPV/GLPlayer.cpp`

该项目直接使用 libmpv render API，把视频渲染到现有 OpenGL FBO/纹理。播放器以 usage count 控制首次使用时启动、最后使用结束时停止；析构时释放 render context 和 mpv handle。视频暂停、静音、音量和源生命周期都落在一个原生对象中。

可借鉴：

- 播放器资源必须有明确所有者；隐藏不等于释放。
- 源尺寸在 `MPV_EVENT_VIDEO_RECONFIG` 后才可靠，初始尺寸只是占位。
- 先解除渲染回调/上下文，再销毁播放器句柄。

不建议采用：

- 该路径绑定 OpenGL，而 Plasma 6/Qt Quick 可能运行在不同 RHI 后端。
- 原生插件一旦崩溃会直接影响 plasmashell。
- libmpv 增加 C++ ABI、构建工具链和发行版打包负担。
- 本项目的核心价值是 QML Shader 转场，不需要为首版重建完整视频渲染器。

## 6. Fresco

### 6.1 外部播放器监督

关键文件：

- `src/daemon/mod.rs`
- `src/daemon/mpv/player.rs`
- `src/daemon/mpvpaper.rs`
- `src/daemon/fullscreen.rs`
- `src/media.rs`
- `src/config.rs`

Fresco 在 Wayland 下为每个输出监督一个 mpvpaper 进程，并通过 mpv JSON IPC 控制；X11 使用嵌入式 libmpv。它不适合直接嵌入 Plasma 壁纸插件，但其监督模型很成熟：

- 每屏独立播放器；
- 启动阶段检测子进程提前退出和 IPC 超时；
- 持续排空 stdout/stderr，避免管道写满卡住进程；
- 保存有限日志尾部用于错误报告；
- 定期检查播放器存活状态并按策略恢复；
- 媒体切换优先 `loadfile`，避免无必要重启播放器；
- 同一视频跨屏播放时定期比较位置，超过阈值才校正。

WallShift 不需要外部进程，但应采用相同的监督原则：加载超时、有限重试、错误分类、状态只在变化时下发、旧回调必须通过 generation token 失效。

### 6.2 单一暂停权威

Fresco 的 `reconcile_pause()` 把用户暂停、电池暂停和每屏全屏覆盖折叠成每个渲染器的 `desired`，并只在 `desired != applied` 时向 mpv 发命令。这是本次调研最值得直接吸收的状态管理模式。

WallShift 应为每个 `MediaSlot` 记录：

```text
desiredPlaybackState
appliedPlaybackState
sourceGeneration
```

只有目标状态改变且 generation 仍匹配时才调用播放器，避免多次 `play()`/`pause()` 和旧源事件扰动新源。

### 6.3 性能经验

Fresco 的源码与公开测量强调：

- 硬件解码只是把成本移到视频引擎，并不等于“免费”。
- 用软件 `fps` 过滤器限帧可能迫使硬件帧回读，反而提高负载。
- 降低缩放器质量有时比跳帧更有效。
- 被窗口遮挡时合成器停止 frame callback，不代表播放器停止解码，所以仍需显式暂停。
- 性能应记录整机功耗、GPU 视频引擎、渲染引擎、CPU、编码和分辨率，而不只看 CPU 百分比。

因此 WallShift v0.4 不应自行加入“低帧率模式”或 QML 定时丢帧。先使用 Qt Multimedia 默认硬件路径并测量；若后续需要节能，应先确认操作没有破坏零拷贝/硬件纹理路径。

## 7. Qt 6.4 官方 API 核对

已核对：

- [Qt 6.4 VideoOutput](https://doc.qt.io/archives/qt-6.4/qml-qtmultimedia-videooutput.html)
- [Qt 6.4 MediaPlayer](https://doc.qt.io/archives/qt-6.4/qml-qtmultimedia-mediaplayer.html)

### 7.1 可依赖能力

- `VideoOutput.videoSink` 存在，底层对象为 `QVideoSink`。
- `MediaPlayer.activeAudioTrack` 可设为 `-1` 禁用音轨。
- `mediaStatus`、`playbackState`、`position`、`duration`、`hasAudio`、`hasVideo`、`errorOccurred` 可用。
- `play()`、`pause()`、`stop()` 可用。
- `VideoOutput` 支持 Stretch、PreserveAspectFit、PreserveAspectCrop。

### 7.2 不能假设的能力

Qt 6.4 的 `MediaPlayer` QML 文档没有列出：

- `autoPlay`
- `playing`

因此原型必须在实际 Qt 6.4 环境编译/运行验证，且基线实现不得引用这些属性。

### 7.3 建议的首帧判定链

```text
设置 source + generation
  → 显式 play()
  → videoSink.videoFrameChanged 收到有效 QVideoFrame
      → visualReady = true
      → 若当前目标不应播放则 pause()
  → 若目标环境无法可靠收到信号：position > 0 作为回退
  → 超时仍未 visualReady：loadFailed("first-frame-timeout")
```

`LoadedMedia` 或 `BufferedMedia` 可以启动/更新超时，但不能直接触发转场。

## 8. 推荐给 WallShift 的具体架构

```text
main.qml
  ├─ MediaCatalog / MediaUtils.js
  ├─ RotationCoordinator
  │    └─ requestNext(reason) + latest-wins target
  └─ WallpaperTransition.qml
       ├─ PlaybackArbiter
       ├─ MediaSlot A
       │    ├─ Image
       │    └─ Loader → VideoSurface.qml → QtMultimedia
       ├─ MediaSlot B
       └─ ShaderTransitionOverlay
```

职责边界：

- `main.qml`：目录、顺序、当前索引、配置、快捷键和自动切换原因。
- `WallpaperTransition.qml`：双槽生命周期、latest-wins、转场阶段，不读取 QtMultimedia 枚举。
- `MediaSlot.qml`：图片/视频统一就绪与错误语义，持有 source generation。
- `VideoSurface.qml`：唯一允许直接导入 `QtMultimedia` 的运行时文件。
- `PlaybackArbiter`：将暂停原因归并为最终目标状态，并去重命令。
- `ShaderTransitionOverlay.qml`：只接收可视 Item，不知道媒体类型；能力失败时向上报告降级。

## 9. 转场策略修订

参考项目普遍使用以下两类方式：

1. 两个播放器同时运行并做 opacity crossfade；实现直接，但转场期双解码。
2. 一个播放器执行淡黑、缩放或滤镜，再 `loadfile`；资源省，但不是真正的双源 Shader 转场。

WallShift 的 Shader 是产品差异点，应保留双槽，但首版按以下层级降级：

1. **冻结帧 Shader**：旧视频暂停，新视频首帧出现后暂停，两个槽位由 `ShaderEffectSource` 静态采样。
2. **快照代理 Shader（仅在阶段 0 证明可行时）**：直接采样视频失败时，尝试一次性 `grabToImage()`/图像代理；允许短时 GPU→CPU→GPU 拷贝，但只发生在切换时。
3. **普通淡入淡出**：视频纹理无法稳定采样时使用双槽 opacity。
4. **瞬切**：淡入淡出也不可靠时保底。

不要为了保持 Shader 效果而让失败转场黑屏，也不要在首版启用两路持续播放的动态 Shader。

## 10. 音频策略修订

首版建议同时执行：

```qml
MediaPlayer {
    activeAudioTrack: -1
}
```

并且不连接 `AudioOutput`。若某发行版后端要求 AudioOutput 才能正常建管线，再创建 `AudioOutput { muted: true; volume: 0 }` 作为兼容路径，但 `activeAudioTrack: -1` 仍保留。

这比只设置 `muted: true` 更明确，也可能避免无意义的音频解码。验收测试应包含带音轨的视频，并用系统混音器/音频会话确认没有 WallShift 输出流或声音。

## 11. 暂停与可见性分阶段范围

### v0.4 必须实现

- 非活动槽位不持续播放；
- 转场结束后旧槽 `stop()`、清空 source、销毁视频 Loader；
- `root.visible === false` 时暂停；
- 组件销毁时停止；
- 锁屏/休眠恢复按可获得的可靠信号处理；
- 暂停原因统一归并，恢复时不覆盖其他仍存在的暂停原因。

### 后续再实现

- 每屏最大化/全屏窗口检测；
- 电池阈值和节能档位；
- 桌面效果联动；
- 多屏同源进度同步。

原因：Smart Video 和 Fresco 都表明这些功能可做，但它们会引入 task model、PowerDevil、KScreen/DPMS、Wayland 协议或 D-Bus 依赖。首版不应把播放基础链路和完整节能策略绑在一起。

## 12. 诊断与故障恢复

实验版至少记录以下结构化字段：

```text
screen / slot / generation / path
mediaStatus / playbackState / error code / error string
loadStartedAt / firstFrameAt / timeout
transition type / fallback level
desiredPlaying / appliedPlaying / pauseReasons
```

默认日志应只记录状态变化和错误；详细位置/帧事件仅在调试开关下输出，避免 journal 刷屏。

建议为设置页提供只读诊断摘要：

- Qt 版本；
- Qt Multimedia 是否可加载；
- 当前文件类型；
- 最近错误；
- 当前降级级别；
- 是否检测到首帧；
- 活动视频槽数量。

首版不需要实现 mpv/Fresco 那样完整的 doctor 工具，但内部状态命名应允许后续扩展。

## 13. 明确不采用的方案

| 方案 | 首版不采用原因 | 何时重评 |
|---|---|---|
| libmpv 原生插件 | ABI、构建、崩溃域和图形后端复杂 | QtMultimedia 在目标发行版出现无法规避的兼容/性能问题 |
| 外部 mpv/mpvpaper 守护进程 | 与 Plasma WallpaperItem 集成割裂，Shader 纹理难共享 | 独立桌面应用或非 Plasma 支持成为目标 |
| `QQuickRhiItem` mpv 后端 | 参考实现要求 Qt 6.7+，且可能逐帧 CPU 上传 | 项目提高最低 Qt 版本并有明确后端需求 |
| 动态双视频 Shader | 双解码 + Shader 峰值负载高 | 冻结帧稳定后单独评测 |
| 自动限帧/软件 fps filter | 可能破坏硬件帧路径、反向增耗 | 有真实功耗测量并验证零拷贝不受影响 |
| 首版全套窗口/电池策略 | 扩大平台状态依赖和测试矩阵 | 基础播放稳定后的增强版本 |

## 14. 对原路线图的直接修改项

本次调研要求把以下内容写回 `video-wallpaper-development-roadmap.md`：

1. `VideoSurface.qml` 是明确的后端适配边界。
2. Qt 6.4 禁止使用 `autoPlay` 和 `playing`，改用显式方法和 `playbackState`。
3. 首帧检测采用 videoSink → position → timeout 的分层策略。
4. 首版以 `activeAudioTrack: -1` 禁用音轨，并保留静音兼容措施。
5. 新增单一 Playback Arbiter 和 `desired/applied` 状态去重。
6. 阶段 0 增加“Qt 6.4 实机 API”和“静态 Shader 捕获/快照代理”验证。
7. 性能测试不以 CPU 单指标或盲目限帧作为优化结论。
8. 原生 mpv 后端明确延后，除非 QtMultimedia 原型失败。

## 15. 实施 Go / No-Go 门槛

阶段 0 只有同时满足以下条件才进入媒体模型重构：

1. Qt 6.4 上不使用新版本属性即可播放至少 H.264 MP4 和 VP9 WebM。
2. `videoSink.videoFrameChanged` 或已验证回退能可靠标记首帧。
3. 带音轨视频完全无声，且没有意外音频输出流。
4. 暂停后画面保持，恢复后继续，stop + 清空 source 后解码活动消失。
5. `ShaderEffectSource live:false` 至少对 Fade、Grow、Pixelate、Portal 可稳定取得非黑帧。
6. 若直接 Shader 捕获失败，普通 opacity 淡入淡出可稳定工作；快照代理是否可用有明确结论。
7. 两播放器短时共存不会崩溃；结束后旧播放器确实销毁。
8. 整个原型在 Plasma WallpaperItem 内验证，而不只在独立 qml6 窗口验证。

若第 1、2、4 项失败，应暂停 QtMultimedia 架构并单独评估 mpv；若只有第 5 项失败，不应放弃视频支持，而应将高级 Shader 降级为淡入淡出。

## 16. 最终建议

参考项目没有推翻原有路线，反而验证了其核心方向：**QtMultimedia 是 Plasma 插件首版的最低复杂度方案，重型播放器必须按需创建并尽早销毁，播放条件必须集中裁决，多屏和硬件解码优化应后置。**

WallShift 不应复制一个通用视频壁纸插件，而应把已有优势保留下来：统一图片/视频轮换、可靠快捷键、latest-wins 调度，以及可预测降级的高级 Shader 转场。最合理的下一步仍是独立阶段 0 原型，但现在原型的 API、失败判定和架构边界已经更明确。
