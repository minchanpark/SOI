import '../repositories/audio_repository.dart';
import '../models/auth_result.dart';

/// 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class AudioService {
  final AudioRepository _repository = AudioRepository();

  // ==================== 권한 관리 ====================

  /// 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    return await AudioRepository.requestMicrophonePermission();
  }

  // ==================== 초기화 ====================

  /// 서비스 초기화
  Future<AuthResult> initialize() async {
    try {
      // 1. 권한 확인
      final micPermission = await AudioRepository.requestMicrophonePermission();
      if (!micPermission) {
        return AuthResult.failure('마이크 권한이 필요합니다.');
      }

      // 3. 임시 파일 정리
      await _repository.cleanupTempFiles();

      return AuthResult.success();
    } catch (e) {
      // // debugPrint('오디오 서비스 초기화 오류: $e');
      return AuthResult.failure('오디오 서비스 초기화에 실패했습니다.');
    }
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 네이티브 녹음 시작
  Future<AuthResult> startRecording() async {
    try {
      if (await AudioRepository.isRecording()) {
        return AuthResult.failure('이미 녹음이 진행 중입니다.');
      }

      final recordingPath = await AudioRepository.startRecording();

      if (recordingPath.isEmpty) {
        return AuthResult.failure('네이티브 녹음을 시작할 수 없습니다.');
      }

      // // debugPrint('네이티브 녹음 시작됨: $recordingPath');
      return AuthResult.success(recordingPath);
    } catch (e) {
      // // debugPrint('네이티브 녹음 시작 오류: $e');
      return AuthResult.failure('네이티브 녹음을 시작할 수 없습니다.');
    }
  }

  /// 간단한 네이티브 녹음 중지 (UI용)
  Future<AuthResult> stopRecordingSimple() async {
    try {
      final filePath = await AudioRepository.stopRecording();

      if (filePath != null && filePath.isNotEmpty) {
        // // debugPrint('간단 녹음 중지: $filePath');
        return AuthResult.success(filePath);
      } else {
        return AuthResult.failure('네이티브 녹음 중지 실패');
      }
    } catch (e) {
      // // debugPrint('간단 녹음 중지 오류: $e');
      return AuthResult.failure('네이티브 녹음 중지 중 오류 발생: $e');
    }
  }

  /// 녹음 상태 확인
  Future<bool> get isRecording => AudioRepository.isRecording();

  // 네이티브 녹음에서는 녹음 진행률 스트림이 제한됨

  // ==================== 재생 관리 ====================

  /// 재생 상태 확인
  bool get isPlaying => _repository.isPlaying;

  // 네이티브 재생에서는 재생 진행률 스트림이 제한됨

  // ==================== 업로드 관리 ====================

  // ==================== 데이터 관리 ====================

  /// 오디오 파일에서 파형 데이터 추출
  Future<List<double>> extractWaveformData(String audioFilePath) async {
    return await _repository.extractWaveformData(audioFilePath);
  }

  /// 오디오 길이 계산
  Future<double> getAudioDuration(String audioFilePath) async {
    return await _repository.getAudioDurationAccurate(audioFilePath);
  }
}
