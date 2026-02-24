import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/audio_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

class CommentAudioSheetResult {
  final String audioPath;
  final List<double> waveformData;
  final int durationMs;

  const CommentAudioSheetResult({
    required this.audioPath,
    required this.waveformData,
    required this.durationMs,
  });
}

enum _CommentAudioSheetState { ready, recording, playback }

class CommentAudioRecordingBottomSheetWidget extends StatefulWidget {
  const CommentAudioRecordingBottomSheetWidget({super.key});

  @override
  State<CommentAudioRecordingBottomSheetWidget> createState() =>
      _CommentAudioRecordingBottomSheetWidgetState();
}

class _CommentAudioRecordingBottomSheetWidgetState
    extends State<CommentAudioRecordingBottomSheetWidget> {
  static const double _sheetHeight = 258;

  late final AudioController _audioController;
  late final RecorderController _recorderController;
  PlayerController? _playerController;

  _CommentAudioSheetState _state = _CommentAudioSheetState.ready;
  List<double> _waveformData = const [];
  String? _audioPath;
  DateTime? _recordingStartedAt;
  int _recordingDurationMs = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _audioController = context.read<AudioController>();
    _recorderController = RecorderController()
      ..overrideAudioSession = false
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
    _playerController = PlayerController();
  }

  @override
  void dispose() {
    unawaited(_stopRecordingIfNeeded());
    _recorderController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isTransitioning || _state == _CommentAudioSheetState.recording) {
      return;
    }

    _isTransitioning = true;
    try {
      await _stopPlaybackIfNeeded();
      await _recorderController.record();
      _recordingStartedAt = DateTime.now();
      _recordingDurationMs = 0;
      await _audioController.startRecording();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _CommentAudioSheetState.recording;
      });
    } catch (_) {
      _showSnackBar(tr('comments.audio_sheet.recording_failed'));
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _stopRecordingAndPreparePlayback() async {
    if (_isTransitioning || _state != _CommentAudioSheetState.recording) {
      return;
    }

    _isTransitioning = true;
    try {
      var waveform = List<double>.from(
        _recorderController.waveData,
      ).map((value) => value.abs()).toList();

      if (_recorderController.isRecording) {
        await _recorderController.stop();
      }

      await _audioController.stopRecordingSimple();

      final path = _audioController.currentRecordingPath;
      if (path == null || path.isEmpty) {
        throw StateError('recording path is empty');
      }

      final durationMs = _recordingStartedAt == null
          ? 0
          : DateTime.now().difference(_recordingStartedAt!).inMilliseconds;
      _recordingDurationMs = durationMs;

      final player = _playerController ??= PlayerController();
      await player.preparePlayer(path: path, shouldExtractWaveform: true);

      if (waveform.isEmpty) {
        final extracted = await player.extractWaveformData(
          path: path,
          noOfSamples: 100,
        );
        if (extracted.isNotEmpty) {
          waveform = extracted;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _audioPath = path;
        _waveformData = waveform;
        _state = _CommentAudioSheetState.playback;
      });
    } catch (_) {
      _showSnackBar(tr('comments.audio_sheet.prepare_failed'));
      await _discardRecordingAndReset();
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _togglePlayback() async {
    final player = _playerController;
    final path = _audioPath;
    if (player == null || path == null || path.isEmpty) {
      return;
    }

    try {
      if (player.playerState.isPlaying) {
        await player.pausePlayer();
      } else {
        if (player.playerState == PlayerState.initialized ||
            player.playerState == PlayerState.paused) {
          await player.startPlayer();
        } else {
          await player.preparePlayer(path: path, shouldExtractWaveform: true);
          await player.startPlayer();
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _showSnackBar(tr('common.error_occurred'));
    }
  }

  Future<void> _backToReady() async {
    await _discardRecordingAndReset();
  }

  Future<void> _stopRecordingIfNeeded() async {
    if (_recorderController.isRecording) {
      await _recorderController.stop();
    }
    if (_audioController.isRecording) {
      await _audioController.stopRecordingSimple();
    }
  }

  Future<void> _stopPlaybackIfNeeded() async {
    final player = _playerController;
    if (player == null) {
      return;
    }
    if (player.playerState.isPlaying) {
      await player.stopPlayer();
    }
  }

  Future<void> _discardRecordingAndReset() async {
    await _stopPlaybackIfNeeded();
    await _stopRecordingIfNeeded();

    final oldPath = _audioPath ?? _audioController.currentRecordingPath;
    _audioController.clearCurrentRecording();

    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        final file = File(oldPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _audioPath = null;
      _waveformData = const [];
      _recordingStartedAt = null;
      _recordingDurationMs = 0;
      _state = _CommentAudioSheetState.ready;
    });
  }

  Future<void> _confirm() async {
    final path = _audioPath;
    if (path == null || path.isEmpty) {
      return;
    }

    await _stopPlaybackIfNeeded();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      CommentAudioSheetResult(
        audioPath: path,
        waveformData: List<double>.from(_waveformData),
        durationMs: _recordingDurationMs,
      ),
    );
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTopBar() {
    switch (_state) {
      case _CommentAudioSheetState.ready:
        return Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Color(0xFF8A8A8A), size: 28),
            ),
            const Spacer(),
          ],
        );
      case _CommentAudioSheetState.recording:
      case _CommentAudioSheetState.playback:
        return Row(
          children: [
            IconButton(
              onPressed: _backToReady,
              icon: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 28,
              ),
            ),
            const Spacer(),
            if (_state == _CommentAudioSheetState.playback)
              TextButton(
                onPressed: _confirm,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  tr('common.confirm'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
    }
  }

  Widget _buildReadyBody() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.graphic_eq, color: Color(0xFF6D6D6D), size: 58),
          const SizedBox(height: 14),
          Text(
            tr('comments.audio_sheet.start_tag'),
            style: const TextStyle(
              color: Color(0xFFF1F1F1),
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),
          _buildPrimaryCircleButton(
            icon: const Icon(Icons.mic, color: Colors.white, size: 24),
            onTap: _startRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPill(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildRecordingBody() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Selector<AudioController, String>(
            selector: (_, controller) => controller.formattedRecordingDuration,
            builder: (_, duration, __) {
              return _buildDurationPill(
                Text(
                  duration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: 70,
            width: double.infinity,
            child: AudioWaveforms(
              size: const Size(double.infinity, 70),
              recorderController: _recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                showMiddleLine: false,
                extendWaveform: true,
                waveThickness: 2.5,
                spacing: 5,
              ),
            ),
          ),
          Row(
            children: [
              _buildSecondaryCircleButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onTap: _discardRecordingAndReset,
              ),
              const Spacer(),
              _buildPrimaryCircleButton(
                icon: const Icon(Icons.pause, color: Colors.white, size: 30),
                onTap: _stopRecordingAndPreparePlayback,
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackWaveform() {
    final player = _playerController;
    if (player == null || _waveformData.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<int>(
      stream: player.onCurrentDurationChanged,
      builder: (context, snapshot) {
        final current = snapshot.data ?? 0;
        final total = player.maxDuration;
        final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
        return SizedBox(
          height: 70,
          width: double.infinity,
          child: CustomWaveformWidget(
            waveformData: _waveformData,
            color: const Color(0xFF5A5A5A),
            activeColor: Colors.white,
            progress: progress,
          ),
        );
      },
    );
  }

  Widget _buildPlaybackDuration() {
    final player = _playerController;
    if (player == null) {
      return _buildDurationPill(
        Text(
          _formatDuration(Duration(milliseconds: _recordingDurationMs)),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return StreamBuilder<int>(
      stream: player.onCurrentDurationChanged,
      builder: (context, snapshot) {
        final currentDuration = Duration(milliseconds: snapshot.data ?? 0);
        final fallback = Duration(milliseconds: _recordingDurationMs);
        final display = currentDuration == Duration.zero
            ? fallback
            : currentDuration;
        return _buildDurationPill(
          Text(
            _formatDuration(display),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaybackBody() {
    final player = _playerController;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlaybackDuration(),
          _buildPlaybackWaveform(),
          Row(
            children: [
              _buildSecondaryCircleButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onTap: _discardRecordingAndReset,
              ),
              const Spacer(),
              StreamBuilder<PlayerState>(
                stream: player?.onPlayerStateChanged,
                builder: (context, snapshot) {
                  final isPlaying =
                      (snapshot.data ?? player?.playerState)?.isPlaying ??
                      false;
                  return _buildPrimaryCircleButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                    onTap: _togglePlayback,
                  );
                },
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCircleButton({
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF3F3F3F),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }

  Widget _buildSecondaryCircleButton({
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFF2F2F2F),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _CommentAudioSheetState.ready,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _state != _CommentAudioSheetState.ready) {
          unawaited(_discardRecordingAndReset());
        }
      },
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _sheetHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 8),
                  switch (_state) {
                    _CommentAudioSheetState.ready => _buildReadyBody(),
                    _CommentAudioSheetState.recording => _buildRecordingBody(),
                    _CommentAudioSheetState.playback => _buildPlaybackBody(),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
