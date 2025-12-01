import 'package:soi_api_client/api.dart';

/// 게시물(포스트) 모델
///
/// API의 PostRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class Post {
  final String odid;
  final String? content;
  final String? imageUrl;
  final String? audioUrl;
  final String? waveformData;
  final int? duration;
  final bool isActive;
  final DateTime? createdAt;

  const Post({
    required this.odid,
    this.content,
    this.imageUrl,
    this.audioUrl,
    this.waveformData,
    this.duration,
    this.isActive = true,
    this.createdAt,
  });

  /// PostRespDto에서 Post 모델 생성
  factory Post.fromDto(PostRespDto dto) {
    return Post(
      odid: dto.userId ?? '',
      content: dto.content,
      imageUrl: dto.postFileKey,
      audioUrl: dto.audioFileKey,
      waveformData: dto.waveformData,
      duration: dto.duration,
      isActive: dto.isActive ?? true,
      createdAt: dto.createdAt,
    );
  }

  /// JSON에서 Post 모델 생성
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      odid: json['userId'] as String? ?? '',
      content: json['content'] as String?,
      imageUrl: json['postFileKey'] as String?,
      audioUrl: json['audioFileKey'] as String?,
      waveformData: json['waveformData'] as String?,
      duration: json['duration'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  /// Post 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'userId': odid,
      'content': content,
      'postFileKey': imageUrl,
      'audioFileKey': audioUrl,
      'waveformData': waveformData,
      'duration': duration,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// 이미지 유무 확인
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// 오디오 유무 확인
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// 오디오 길이 (초 단위)
  int get durationInSeconds => duration ?? 0;

  /// copyWith 메서드
  Post copyWith({
    String? odid,
    String? content,
    String? imageUrl,
    String? audioUrl,
    String? waveformData,
    int? duration,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Post(
      odid: odid ?? this.odid,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      waveformData: waveformData ?? this.waveformData,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          odid == other.odid &&
          createdAt == other.createdAt;

  @override
  int get hashCode => odid.hashCode ^ (createdAt?.hashCode ?? 0);

  @override
  String toString() {
    return 'Post{odid: $odid, hasImage: $hasImage, hasAudio: $hasAudio}';
  }
}
