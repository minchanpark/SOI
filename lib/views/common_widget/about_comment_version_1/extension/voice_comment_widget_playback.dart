// ignore_for_file: invalid_use_of_protected_member

part of '../voice_comment_widget.dart';

/// 음성 댓글 위젯의 재생 관련 로직
/// - 녹음 완료 후 recorded 상태에서 재생/일시정지 토글
/// - 재생 UI에는 실시간 파형, 재생 시간, 재생/일시정지 버튼이 포함됨
extension _VoiceCommentWidgetPlaybackExtension on _VoiceCommentWidgetState {
  /// 오디오 재생/일시정지 토글
  /// PlayerController의 상태에 따라 재생 또는 일시정지 실행
  Future<void> _togglePlayback() async {
    // null 체크와 mounted 체크 추가
    if (!mounted || _playerController == null) {
      return;
    }

    try {
      if (_playerController!.playerState.isPlaying) {
        await _playerController!.pausePlayer();
      } else {
        // 재생이 끝났다면 처음부터 다시 시작
        if (_playerController!.playerState.isStopped) {
          await _playerController!.startPlayer();
        } else {
          await _playerController!.startPlayer();
        }
      }
      if (mounted) {
        setState(() {}); // UI 갱신
      }
    } catch (e) {
      debugPrint('재생/일시정지 오류: $e');
    }
  }

  /// 녹음 중 UI (AudioRecorderWidget과 동일)
  /// 실시간 파형, 녹음 시간, 중지 버튼을 표시
  Widget _buildRecordingUI(String duration) {
    final borderRadius = BorderRadius.circular(21.5);
    return Container(
      width: 353, // 텍스트 필드와 동일한 너비
      height: 46, // 텍스트 필드와 동일한 높이
      decoration: BoxDecoration(
        color: const Color(0xffd9d9d9).withValues(alpha: 0.1),
        borderRadius: borderRadius,
        border: Border.all(
          color: const Color(0x66D9D9D9).withValues(alpha: 0.4),
          width: 1,
        ),
        // 3D: 떠있는 느낌(아래 그림자 + 위쪽 하이라이트)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 10),
            blurRadius: 18,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      // 3D: 상단 하이라이트/하단 음영 오버레이(기존 색 유지)
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 15.w),
          // 쓰레기통 아이콘 (녹음 취소)
          GestureDetector(
            onTap: _deleteRecording,
            child: Image.asset('assets/trash.png', width: 25, height: 25),
          ),
          SizedBox(width: 18.w),
          // 실시간 파형
          Expanded(
            child: AudioWaveforms(
              size: Size(1, 46),
              recorderController: _recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          // 녹음 시간
          Text(
            duration,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.40,
            ),
          ),
          // 중지 버튼
          IconButton(
            onPressed: _stopAndPreparePlayback,
            padding: EdgeInsets.only(bottom: 3.h),
            icon: Icon(Icons.stop, color: Colors.white, size: 35.sp),
          ),
        ],
      ),
    );
  }

  /// 재생 UI (AudioRecorderWidget과 동일)
  /// 파형, 재생 시간, 재생/일시정지 버튼을 표시
  Widget _buildPlaybackUI() {
    final borderRadius = BorderRadius.circular(21.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 353,
      height: 46,
      // 3D: 바깥쪽 그림자로 태그처럼 떠 보이게
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 10),
            blurRadius: 18,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Container(
                  key: ValueKey('playback_bg'),
                  decoration: BoxDecoration(
                    color: const Color(0xffd9d9d9).withValues(alpha: 0.1),
                    border: Border.all(
                      color: const Color(0x66D9D9D9).withValues(alpha: 0.4),
                      width: 1,
                    ),
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              // 3D: 상단 하이라이트/하단 음영 오버레이(기존 배경색은 그대로)
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 15.w),
                // 쓰레기통 아이콘 (삭제)
                GestureDetector(
                  onTap: _deleteRecording,
                  child: Image.asset('assets/trash.png', width: 25, height: 25),
                ),
                SizedBox(width: 18.w),
                // 재생 파형 - 드래그 가능
                Expanded(
                  child: _buildWaveformDraggable(
                    child: _waveformData != null && _waveformData!.isNotEmpty
                        ? StreamBuilder<int>(
                            stream:
                                _playerController?.onCurrentDurationChanged ??
                                const Stream.empty(),
                            builder: (context, positionSnapshot) {
                              // mounted와 _playerController null 체크 추가
                              if (!mounted || _playerController == null) {
                                return Container();
                              }

                              final currentPosition =
                                  positionSnapshot.data ?? 0;
                              final totalDuration =
                                  _playerController?.maxDuration ?? 1;
                              final progress = totalDuration > 0
                                  ? (currentPosition / totalDuration).clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : 0.0;

                              // _waveformData가 여전히 null이 아닌지 다시 확인
                              if (_waveformData == null ||
                                  _waveformData!.isEmpty) {
                                return Container();
                              }

                              return CustomWaveformWidget(
                                waveformData: _waveformData!,
                                color: Colors.grey,
                                activeColor: Colors.white,
                                progress: progress,
                              );
                            },
                          )
                        : Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '파형 없음',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14.sp,
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                // 재생 시간
                StreamBuilder<int>(
                  stream:
                      _playerController?.onCurrentDurationChanged ??
                      const Stream.empty(),
                  builder: (context, snapshot) {
                    // mounted와 _playerController null 체크 추가
                    if (!mounted || _playerController == null) {
                      return Text(
                        '00:00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.40,
                        ),
                      );
                    }

                    final currentDurationMs = snapshot.data ?? 0;
                    final currentDuration = Duration(
                      milliseconds: currentDurationMs,
                    );
                    final minutes = currentDuration.inMinutes;
                    final seconds = currentDuration.inSeconds % 60;
                    return Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.40,
                      ),
                    );
                  },
                ),
                // 재생/일시정지 버튼
                StreamBuilder<PlayerState>(
                  stream:
                      _playerController?.onPlayerStateChanged ??
                      const Stream.empty(),
                  builder: (context, snapshot) {
                    // mounted와 _playerController null 체크 추가
                    if (!mounted || _playerController == null) {
                      return IconButton(
                        onPressed: null,
                        icon: Icon(
                          Icons.play_arrow,
                          color: Colors.white54,
                          size: 35.sp,
                        ),
                      );
                    }

                    final playerState = snapshot.data;
                    final isPlaying = playerState?.isPlaying ?? false;

                    return IconButton(
                      onPressed: _togglePlayback,
                      padding: EdgeInsets.only(bottom: 3.h),
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 35.sp,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
