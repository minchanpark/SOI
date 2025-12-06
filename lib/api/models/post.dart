import 'package:soi_api_client/api.dart';

/// 게시물 상태 enum
///
/// API에서 사용하는 게시물 상태값입니다.
/// - ACTIVE: 활성화된 게시물 (기본)
/// - DELETED: 삭제된 게시물 (휴지통)
/// - INACTIVE: 비활성화된 게시물
enum PostStatus {
  active('ACTIVE'),
  deleted('DELETED'),
  inactive('INACTIVE');

  final String value;
  const PostStatus(this.value);

  static PostStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DELETED':
        return PostStatus.deleted;
      case 'INACTIVE':
        return PostStatus.inactive;
      case 'ACTIVE':
      default:
        return PostStatus.active;
    }
  }
}

/// 게시물(포스트) 모델
///
/// API의 PostRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class Post {
  final int id;
  final String nickName;
  final String? content;
  final String? imageUrl;
  final String? audioUrl;
  final String? waveformData;
  final int? duration;
  final bool isActive;
  final DateTime? createdAt;

  const Post({
    required this.id,
    required this.nickName,
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
      id: dto.id ?? 0,
      nickName: dto.nickname ?? '',
      content: dto.content,
      imageUrl: dto.postFileUrl,
      audioUrl: dto.audioFileUrl,
      waveformData: dto.waveformData,
      duration: dto.duration,
      isActive: dto.isActive ?? true,
      createdAt: dto.createdAt,
    );
  }

  /// JSON에서 Post 모델 생성
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int? ?? 0,
      nickName: json['nickName'] as String? ?? '',
      content: json['content'] as String?,
      imageUrl: json['postFileUrl'] as String?,
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
      'id': id,
      'nickName': nickName,
      'content': content,
      'postFileUrl': imageUrl,
      'audioFileUrl': audioUrl,
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
    int? id,
    String? nickName,
    String? content,
    String? imageUrl,
    String? audioUrl,
    String? waveformData,
    int? duration,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Post(
      id: id ?? this.id,
      nickName: nickName ?? this.nickName,
      content: content ?? this.content,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
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
          nickName == other.nickName &&
          createdAt == other.createdAt;

  @override
  int get hashCode => nickName.hashCode ^ (createdAt?.hashCode ?? 0);

  @override
  String toString() {
    return 'Post{nickName: $nickName, hasImage: $hasImage, hasAudio: $hasAudio}';
  }
}
