import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
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
    unawaited(_stopRecordingIfNeeded(force: true));
    unawaited(_stopPlaybackIfNeeded());
    _recorderController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isTransitioning || _state == _CommentAudioSheetState.recording) {
      return;
    }

    _isTransitioning = true;
    try {
      // 이전 사이클의 잔여 상태를 먼저 정리
      await _stopPlaybackIfNeeded();
      await _stopRecordingIfNeeded(force: true);
      _audioController.clearCurrentRecording();

      // native 녹음부터 시작한 뒤 wave recorder를 시작한다.
      await _audioController.startRecording();
      await _recorderController.record();

      _recordingStartedAt = DateTime.now();
      if (!mounted) {
        return;
      }
      setState(() {
        _audioPath = null;
        _waveformData = const [];
        _recordingDurationMs = 0;
        _state = _CommentAudioSheetState.recording;
      });
    } catch (_) {
      // 부분 시작 실패 시 즉시 롤백
      await _stopRecordingIfNeeded(force: true);
      _audioController.clearCurrentRecording();
      if (mounted) {
        setState(() {
          _audioPath = null;
          _waveformData = const [];
          _recordingStartedAt = null;
          _recordingDurationMs = 0;
          _state = _CommentAudioSheetState.ready;
        });
      }
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

      await _audioController.stopRecordingSimple(force: true);

      final path = _audioController.currentRecordingPath;
      if (path == null || path.isEmpty) {
        throw StateError('recording path is empty');
      }

      final durationMs = _recordingStartedAt == null
          ? 0
          : DateTime.now().difference(_recordingStartedAt!).inMilliseconds;
      _recordingDurationMs = durationMs;

      await _stopPlaybackIfNeeded();
      final player = PlayerController();
      _playerController = player;
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

  Future<void> _stopRecordingIfNeeded({bool force = false}) async {
    if (_recorderController.isRecording) {
      try {
        await _recorderController.stop();
      } catch (_) {}
    }

    if (force || _audioController.isRecording) {
      try {
        await _audioController.stopRecordingSimple(force: force);
      } catch (_) {}
    }
  }

  Future<void> _stopPlaybackIfNeeded() async {
    final player = _playerController;
    if (player == null) {
      return;
    }

    try {
      await player.stopPlayer();
    } catch (_) {}

    try {
      player.dispose();
    } catch (_) {}

    if (identical(_playerController, player)) {
      _playerController = null;
    }
  }

  Future<void> _discardRecordingAndReset() async {
    await _stopPlaybackIfNeeded();
    await _stopRecordingIfNeeded(force: true);

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
          Image.asset("assets/waveform_icon.png", width: 93.sp, height: 93.sp),
          Text(
            tr('comments.audio_sheet.start_tag'),
            style: TextStyle(
              color: Color(0xFFCBCBCB),
              fontSize: 16.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 10.sp),
          // 녹음 시작 버튼
          IconButton(
            onPressed: _startRecording,
            icon: SvgPicture.asset(
              'assets/record_icon.svg',
              width: 54.sp,
              height: 54.sp,
            ),
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

  /// 녹음 중 UI
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
          AudioWaveforms(
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

  /// 녹음 완료 후 재생 UI
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
        return Container(
          height: 90.sp,
          padding: EdgeInsets.symmetric(horizontal: 42.sp),
          child: CustomWaveformWidget(
            waveformData: _waveformData,
            color: const Color(0xFF5A5A5A),
            activeColor: Colors.white,
            progress: progress,
            barThickness: 3.0, // 녹음된 파형의 두께
            barSpacing: 8.0, // 녹음된 파형의 간격
            maxBarHeightFactor: 2.0, // 녹음된 파형의 최대 높이 비율
            amplitudeScale: 1.2, // 녹음된 파형의 진폭 스케일
            minBarHeight: 3.0, // 녹음된 파형의 최소 높이
            strokeCap: StrokeCap.round, // 녹음된 파형의 끝 모양
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
            child: Column(
              children: [
                _buildTopBar(),
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
    );
  }
}
