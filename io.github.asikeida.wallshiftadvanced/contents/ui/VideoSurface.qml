/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtMultimedia
import QtQuick

Item {
    id: root

    property bool desiredPlaying: false
    property int fillMode: VideoOutput.PreserveAspectCrop
    property int firstFrameTimeout: 8000
    property int endGuard: 250
    readonly property alias source: player.source
    readonly property alias playbackState: player.playbackState
    readonly property alias mediaStatus: player.mediaStatus
    readonly property alias position: player.position
    readonly property alias duration: player.duration
    readonly property alias hasAudio: player.hasAudio
    readonly property alias hasVideo: player.hasVideo
    readonly property alias activeAudioTrack: player.activeAudioTrack
    readonly property bool ready: state.firstFrameReady
    readonly property bool failed: state.failed
    readonly property string firstFrameMethod: state.firstFrameMethod
    readonly property int sourceGeneration: state.generation

    signal readyForTransition()
    signal playbackEnded()
    signal loadFailed(string reason)

    function load(sourceUrl) {
        var generation = state.generation + 1;
        state.generation = generation;
        firstFrameTimer.stop();
        player.stop();
        player.source = "";
        state.requestedState = MediaPlayer.StoppedState;
        state.firstFrameReady = false;
        state.firstFrameMethod = "";
        state.failed = false;
        state.endingEmitted = false;
        state.priming = true;
        Qt.callLater(function() {
            if (generation !== state.generation)
                return;

            firstFrameTimer.restart();
            player.source = sourceUrl;
        });
    }

    function play() {
        desiredPlaying = true;
        _reconcilePlayback();
    }

    function pause() {
        desiredPlaying = false;
        _reconcilePlayback();
    }

    function stop() {
        desiredPlaying = false;
        state.priming = false;
        state.requestedState = MediaPlayer.StoppedState;
        player.stop();
    }

    function unload() {
        var generation = state.generation + 1;
        state.generation = generation;
        firstFrameTimer.stop();
        stop();
        player.source = "";
        state.firstFrameReady = false;
        state.firstFrameMethod = "";
        state.failed = false;
        state.endingEmitted = false;
        Qt.callLater(function() {
            if (generation !== state.generation)
                return;

            state.requestedState = MediaPlayer.StoppedState;
            player.stop();
        });
    }

    function restart() {
        if (!player.source)
            return;

        state.endingEmitted = false;
        player.position = 0;
        play();
    }

    function _requestPlay() {
        if (!player.source)
            return;

        if (state.requestedState === MediaPlayer.PlayingState && player.playbackState === MediaPlayer.PlayingState)
            return;

        state.requestedState = MediaPlayer.PlayingState;
        player.play();
    }

    function _requestPause() {
        if (state.requestedState === MediaPlayer.PausedState && player.playbackState === MediaPlayer.PausedState)
            return;

        state.requestedState = MediaPlayer.PausedState;
        player.pause();
    }

    function _disableAudioTrack() {
        if (player.activeAudioTrack !== -1)
            player.activeAudioTrack = -1;
    }

    function _reconcilePlayback() {
        if (!player.source || state.failed)
            return;

        if (!state.firstFrameReady) {
            if (state.priming)
                _requestPlay();

            return;
        }
        if (state.endingEmitted)
            _requestPause();
        else if (desiredPlaying)
            _requestPlay();
        else
            _requestPause();
    }

    function _markFirstFrame(method) {
        if (state.firstFrameReady || state.failed || !player.source)
            return;

        state.firstFrameReady = true;
        state.firstFrameMethod = method;
        state.priming = false;
        firstFrameTimer.stop();
        _reconcilePlayback();
        readyForTransition();
    }

    function _fail(reason) {
        if (state.failed)
            return;

        state.failed = true;
        state.priming = false;
        firstFrameTimer.stop();
        player.stop();
        player.source = "";
        state.requestedState = MediaPlayer.StoppedState;
        loadFailed(reason);
    }

    onDesiredPlayingChanged: _reconcilePlayback()

    QtObject {
        id: state

        property int generation: 0
        property int requestedState: MediaPlayer.StoppedState
        property bool priming: false
        property bool firstFrameReady: false
        property bool failed: false
        property bool endingEmitted: false
        property string firstFrameMethod: ""
    }

    VideoOutput {
        id: videoOutput

        anchors.fill: parent
        fillMode: root.fillMode
    }

    AudioOutput {
        id: silentAudioOutput

        muted: true
        volume: 0
    }

    MediaPlayer {
        id: player

        activeAudioTrack: -1
        audioOutput: silentAudioOutput
        loops: 1
        videoOutput: videoOutput

        onActiveTracksChanged: Qt.callLater(root._disableAudioTrack)
        onErrorOccurred: function(error, errorString) {
            root._fail("media-error-" + error + ": " + errorString);
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.InvalidMedia)
                root._fail("invalid-media: " + errorString);
            else if (mediaStatus === MediaPlayer.EndOfMedia) {
                if (!state.endingEmitted) {
                    state.endingEmitted = true;
                    root.playbackEnded();
                }
            }
            else if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
                root._disableAudioTrack();
                root._reconcilePlayback();
            }
        }
        onPlaybackStateChanged: Qt.callLater(root._reconcilePlayback)
        onPositionChanged: function(position) {
            if (!state.firstFrameReady && position > 0 && (duration <= 0 || position < duration))
                root._markFirstFrame("position");
            if (state.firstFrameReady && !state.endingEmitted && duration > 0 && position > 0 && duration - position <= root.endGuard) {
                state.endingEmitted = true;
                root._requestPause();
                root.playbackEnded();
            }
        }
        onTracksChanged: root._disableAudioTrack()
    }

    Connections {
        target: videoOutput.videoSink

        function onVideoFrameChanged(frame) {
            var generation = state.generation;
            Qt.callLater(function() {
                if (generation !== state.generation)
                    return;

                var size = videoOutput.videoSink.videoSize;
                if (size.width > 0 && size.height > 0)
                    root._markFirstFrame("videoSink");
            });
        }
    }

    Timer {
        id: firstFrameTimer

        interval: root.firstFrameTimeout
        repeat: false
        onTriggered: root._fail("first-frame-timeout")
    }
}
