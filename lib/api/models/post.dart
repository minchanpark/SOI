import 'package:soi_api_client/api.dart';

/// 댓글 유형
enum PostType {
  textOnly, // 텍스트만 Post에 입력할 경우
  multiMedia, // 이미지/비디오가 포함된 Post
}

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
  final String? postFileUrl;
  final String? userProfileImageKey;
  final String? userProfileImageUrl;
  final String? audioUrl;
  final String? waveformData;
  final int? commentCount;
  final int? duration;
  final bool isActive;
  final DateTime? createdAt;
  final PostType? postType;
  final double? savedAspectRatio; // 저장된 미디어의 가로세로 비율
  final bool? isFromGallery; // 갤러리에서 업로드된 미디어인지 여부

  const Post({
    required this.id,
    required this.nickName,
    this.content,
    this.postFileKey,
    this.postFileUrl,
    this.userProfileImageKey,
    this.userProfileImageUrl,
    this.audioUrl,
    this.waveformData,
    this.commentCount,
    this.duration,
    this.isActive = true,
    this.createdAt,
    this.postType,
    this.savedAspectRatio,
    this.isFromGallery,
  });

  /// PostRespDto에서 Post 모델 생성
  factory Post.fromDto(PostRespDto dto) {
    return Post(
      id: dto.id ?? 0,
      nickName: dto.nickname ?? '',
      content: dto.content,
      postFileKey: dto.postFileKey,
      postFileUrl: dto.postFileUrl,
      userProfileImageKey: dto.userProfileImageKey,
      userProfileImageUrl: dto.userProfileImageUrl,
      audioUrl: dto.audioFileKey,
      waveformData: dto.waveformData,
      commentCount: dto.commentCount,
      duration: dto.duration,
      isActive: dto.isActive ?? true,
      createdAt: _normalizeApiDateTime(dto.createdAt),
      postType: _postTypeFromRespEnum(dto.postType),
      savedAspectRatio: dto.savedAspectRatio,
      isFromGallery: dto.isFromGallery,
    );
  }

  /// JSON에서 Post 모델 생성
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int? ?? 0,
      nickName:
          (json['nickName'] as String?) ?? (json['nickname'] as String?) ?? '',
      content: json['content'] as String?,
      userProfileImageKey: json['userProfileImageKey'] as String?,
      userProfileImageUrl: json['userProfileImageUrl'] as String?,
      postFileKey: json['postFileKey'] as String?,
      postFileUrl: json['postFileUrl'] as String?,
      audioUrl: json['audioFileKey'] as String?,
      waveformData: json['waveformData'] as String?,
      commentCount: json['commentCount'] as int?,
      duration: json['duration'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseApiDateString(json['createdAt'] as String?),
      postType: _postTypeFromJsonValue(json['postType']),
      savedAspectRatio: (json['savedAspectRatio'] as num?)?.toDouble(),
      isFromGallery: json['isFromGallery'] as bool?,
    );
  }

  /// Post 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickName': nickName,
      'content': content,
      'postFileKey': postFileKey,
      'postFileUrl': postFileUrl,
      'userProfileImageKey': userProfileImageKey,
      'userProfileImageUrl': userProfileImageUrl,
      'audioFileKey': audioUrl,
      'waveformData': waveformData,
      'commentCount': commentCount,
      'duration': duration,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'postType': _postTypeToApiValue(postType),
      'savedAspectRatio': savedAspectRatio,
      'isFromGallery': isFromGallery,
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
    String? postFileUrl,
    String? audioUrl,
    String? waveformData,
    int? commentCount,
    String? userProfileImageKey,
    String? userProfileImageUrl,
    int? duration,
    bool? isActive,
    DateTime? createdAt,
    PostType? postType,
    double? savedAspectRatio,
    bool? isFromGallery,
  }) {
    return Post(
      id: id ?? this.id,
      nickName: nickName ?? this.nickName,
      content: content ?? this.content,
      postFileKey: postFileKey,
      postFileUrl: postFileUrl,
      audioUrl: audioUrl,
      waveformData: waveformData ?? this.waveformData,
      commentCount: commentCount ?? this.commentCount,
      userProfileImageKey: userProfileImageKey ?? this.userProfileImageKey,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      postType: postType ?? this.postType,
      savedAspectRatio: savedAspectRatio ?? this.savedAspectRatio,
      isFromGallery: isFromGallery ?? this.isFromGallery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          nickName == other.nickName &&
          createdAt == other.createdAt &&
          postType == other.postType;

  @override
  int get hashCode =>
      nickName.hashCode ^
      (createdAt?.hashCode ?? 0) ^
      (postType?.hashCode ?? 0);

  @override
  String toString() {
    return 'Post{nickName: $nickName, hasImage: $hasImage, hasAudio: $hasAudio, postType: $postType }';
  }

  /// postType 변환 헬퍼 메서드
  /// 서버로부터 받은 PostRespDtoPostTypeEnum 값을 클라이언트의 PostType으로 변환
  ///
  /// Parameters:
  ///   - [value]: PostRespDtoPostTypeEnum 값
  /// Returns:
  ///   - [PostType]: 변환된 PostType 값
  static PostType? _postTypeFromRespEnum(PostRespDtoPostTypeEnum? value) {
    switch (value) {
      case PostRespDtoPostTypeEnum.TEXT_ONLY:
        return PostType.textOnly;
      case PostRespDtoPostTypeEnum.MULTIMEDIA:
        return PostType.multiMedia;
      default:
        return null;
    }
  }

  static PostType? _postTypeFromJsonValue(dynamic raw) {
    if (raw is PostRespDtoPostTypeEnum) {
      return _postTypeFromRespEnum(raw);
    }
    if (raw == null) {
      return null;
    }

    final normalized = raw
        ?.toString()
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    switch (normalized) {
      case 'TEXTONLY':
        return PostType.textOnly;
      case 'MULTIMEDIA':
        return PostType.multiMedia;
      default:
        return null;
    }
  }

  static String? _postTypeToApiValue(PostType? type) {
    switch (type) {
      case PostType.textOnly:
        return 'TEXT_ONLY';
      case PostType.multiMedia:
        return 'MULTIMEDIA';
      default:
        return null;
    }
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
