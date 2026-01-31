import 'dart:ui';

/// API 버전 pending 댓글 "마커" 데이터 (UI 표시에 필요한 최소 정보)
/// - 사진 위에 프로필 태그를 띄우기 위한 위치/프로필 키만 보관합니다.
typedef PendingApiCommentMarker = ({
  Offset relativePosition,
  String? profileImageUrlKey,
  double? progress,
});

/// API 버전 pending 댓글 "작성 초안" 데이터 (서버 저장에 필요한 최소 정보)
/// - UI 마커 위치는 [PendingApiCommentMarker]로 별도 관리합니다.
typedef PendingApiCommentDraft = ({
  bool isTextComment,
  String? text,
  String? audioPath,
  List<double>? waveformData,
  int? duration,
  int recorderUserId,
  String? profileImageUrlKey,
});
