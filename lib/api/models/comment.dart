import 'package:soi_api_client/api.dart';

/// 댓글 유형
enum CommentType {
  emoji, // 이모지 댓글
  text, // 텍스트 댓글
  audio, // 음성 댓글
}

/// 댓글 모델
///
/// API의 CommentRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class Comment {
  final String? userProfile;
  final String? text;
  final int? emojiId;
  final String? audioUrl;
  final String? waveformData;
  final int? duration;
  final double? locationX;
  final double? locationY;
  final CommentType type;

  const Comment({
    this.userProfile,
    this.text,
    this.emojiId,
    this.audioUrl,
    this.waveformData,
    this.duration,
    this.locationX,
    this.locationY,
    required this.type,
  });

  /// CommentRespDto에서 Comment 모델 생성
  factory Comment.fromDto(CommentRespDto dto) {
    return Comment(
      userProfile: dto.userProfile,
      text: dto.text,
      emojiId: dto.emojiId,
      audioUrl: dto.audioUrl,
      waveformData: dto.waveFormData,
      duration: dto.duration,
      locationX: dto.locationX,
      locationY: dto.locationY,
      type: _typeFromDto(dto.commentType),
    );
  }

  /// DTO 타입을 CommentType으로 변환
  static CommentType _typeFromDto(CommentRespDtoCommentTypeEnum? type) {
    switch (type) {
      case CommentRespDtoCommentTypeEnum.EMOJI:
        return CommentType.emoji;
      case CommentRespDtoCommentTypeEnum.TEXT:
        return CommentType.text;
      case CommentRespDtoCommentTypeEnum.AUDIO:
        return CommentType.audio;
      default:
        return CommentType.text;
    }
  }

  /// JSON에서 Comment 모델 생성
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      userProfile: json['userProfile'] as String?,
      text: json['text'] as String?,
      emojiId: json['emojiId'] as int?,
      audioUrl: json['audioUrl'] as String?,
      waveformData: (json['waveformdata'] as String?),
      duration: json['duration'] as int?,
      locationX: (json['locationX'] as num?)?.toDouble(),
      locationY: (json['locationY'] as num?)?.toDouble(),
      type: _typeFromString(json['commentType'] as String?),
    );
  }

  /// 문자열을 CommentType으로 변환
  static CommentType _typeFromString(String? type) {
    switch (type?.toUpperCase()) {
      case 'EMOJI':
        return CommentType.emoji;
      case 'TEXT':
        return CommentType.text;
      case 'AUDIO':
        return CommentType.audio;
      default:
        return CommentType.text;
    }
  }

  /// Comment 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'userProfile': userProfile,
      'text': text,
      'emojiId': emojiId,
      'audioUrl': audioUrl,
      'waveformdata': waveformData,
      'duration': duration,
      'locationX': locationX,
      'locationY': locationY,
      'commentType': type.name.toUpperCase(),
    };
  }

  /// 이모지 댓글인지 확인
  bool get isEmoji => type == CommentType.emoji;

  /// 텍스트 댓글인지 확인
  bool get isText => type == CommentType.text;

  /// 음성 댓글인지 확인
  bool get isAudio => type == CommentType.audio;

  /// 오디오 길이 (초 단위)
  int get durationInSeconds => duration ?? 0;

  /// 위치 정보가 있는지 확인
  bool get hasLocation => locationX != null && locationY != null;

  /// copyWith 메서드
  Comment copyWith({
    String? userProfile,
    String? text,
    int? emojiId,
    String? audioUrl,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) {
    return Comment(
      userProfile: userProfile ?? this.userProfile,
      text: text ?? this.text,
      emojiId: emojiId ?? this.emojiId,
      audioUrl: audioUrl ?? this.audioUrl,
      waveformData: waveformData ?? this.waveformData,
      duration: duration ?? this.duration,
      locationX: locationX ?? this.locationX,
      locationY: locationY ?? this.locationY,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'Comment{type: $type, text: $text, emojiId: $emojiId}';
  }
}
