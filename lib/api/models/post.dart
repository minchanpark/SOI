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
  final String? postFileKey;
  final String? userProfileImageKey;
  final String? audioUrl;
  final String? waveformData;
  final int? duration;
  final bool isActive;
  final DateTime? createdAt;

  const Post({
    required this.id,
    required this.nickName,
    this.content,
    this.postFileKey,
    this.userProfileImageKey,
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
      postFileKey: dto.postFileKey,
      userProfileImageKey: dto.userProfileImageKey,
      audioUrl: dto.audioFileKey,
      waveformData: dto.waveformData,
      duration: dto.duration,
      isActive: dto.isActive ?? true,
      createdAt: _normalizeApiDateTime(dto.createdAt),
    );
  }

  /// JSON에서 Post 모델 생성
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int? ?? 0,
      nickName: json['nickName'] as String? ?? '',
      content: json['content'] as String?,
      userProfileImageKey: json['userProfileImageKey'] as String?,
      postFileKey: json['postFileKey'] as String?,
      audioUrl: json['audioFileKey'] as String?,
      waveformData: json['waveformData'] as String?,
      duration: json['duration'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseApiDateString(json['createdAt'] as String?),
    );
  }

  /// Post 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickName': nickName,
      'content': content,
      'postFileKey': postFileKey,
      'userProfileImageKey': userProfileImageKey,
      'audioFileKey': audioUrl,
      'waveformData': waveformData,
      'duration': duration,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// 이미지 유무 확인
  bool get hasImage => hasMedia && !isVideo;

  /// 미디어(이미지/비디오) 유무 확인
  bool get hasMedia => postFileKey != null && postFileKey!.isNotEmpty;

  /// 비디오 여부 (postFileKey 확장자 기반)
  bool get isVideo => _isVideoKey(postFileKey);

  /// 오디오 유무 확인
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// 오디오 길이 (초 단위)
  int get durationInSeconds => duration ?? 0;

  /// copyWith 메서드
  Post copyWith({
    int? id,
    String? nickName,
    String? content,
    String? postFileKey,
    String? audioUrl,
    String? waveformData,
    String? userProfileImageKey,
    int? duration,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Post(
      id: id ?? this.id,
      nickName: nickName ?? this.nickName,
      content: content ?? this.content,
      postFileKey: postFileKey,
      audioUrl: audioUrl,
      waveformData: waveformData ?? this.waveformData,
      userProfileImageKey: userProfileImageKey ?? this.userProfileImageKey,
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

  /// 비디오 확장자 집합
  static const Set<String> _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.m4v',
    '.webm',
    '.3gp',
  };

  /// 비디오 키인지 확인
  ///
  /// Parameters:
  ///   - [key]: 미디어 파일의 키 또는 URL
  ///
  /// Returns:
  ///   - [bool]: 비디오 파일인지 여부
  ///   - true: 비디오 파일
  ///   - false: 비디오 파일 아님
  static bool _isVideoKey(String? key) {
    final extension = _extractExtension(key);
    if (extension == null) return false;
    return _videoExtensions.contains(extension);
  }

  /// 확장자 추출
  ///
  /// Parameters:
  ///  - [raw]: 파일 키 또는 URL 문자열
  ///
  /// Returns:
  ///  - [String]: 추출된 확장자 (없으면 null)
  static String? _extractExtension(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    var value = raw;
    final queryIndex = value.indexOf('?');
    if (queryIndex != -1) {
      value = value.substring(0, queryIndex);
    }

    final hashIndex = value.indexOf('#');
    if (hashIndex != -1) {
      value = value.substring(0, hashIndex);
    }

    // S3 key or URL path both supported
    final lastDot = value.lastIndexOf('.');
    if (lastDot == -1 || lastDot == value.length - 1) return null;

    final ext = value.substring(lastDot).toLowerCase();
    if (ext.length > 8) return null;
    return ext;
  }

  /// API에서 넘어온 시간을 로컬 시간으로 보정
  ///
  /// 타임존 정보가 없으면 UTC로 간주하고 로컬로 변환합니다.
  static DateTime? _normalizeApiDateTime(DateTime? value) {
    if (value == null) return null;
    if (value.isUtc) return value.toLocal();

    final utc = DateTime.utc(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    return utc.toLocal();
  }

  /// 문자열 기반 날짜 파싱 (타임존 없는 경우 UTC로 간주)
  static DateTime? _parseApiDateString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = _hasTimeZone(raw) ? raw : '${raw}Z';
    return DateTime.tryParse(normalized)?.toLocal();
  }

  static bool _hasTimeZone(String value) {
    return RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
  }
}
