import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart'; // Offset를 위한 import

/// 댓글 타입 열거형
enum CommentType {
  audio, // 음성 댓글
  text, // 텍스트 댓글
  emoji, // 이모지 댓글
}

class CommentRecordModel {
  final String id;
  final String audioUrl;
  final String photoId;
  final String recorderUser; // 음성 댓글을 다는 사용자
  final DateTime createdAt;
  final List<double> waveformData;
  final int duration; // milliseconds
  final String profileImageUrl; // 프로필 이미지 URL
  final Offset? relativePosition; // 프로필 이미지 위치 (상대 좌표 0.0~1.0)
  final bool isDeleted;
  final CommentType type; // 댓글 타입 (audio, text)
  final String? text; // 텍스트 댓글 내용

  CommentRecordModel({
    required this.id,
    required this.audioUrl,
    required this.photoId,
    required this.recorderUser,
    required this.createdAt,
    required this.waveformData,
    required this.duration,
    required this.profileImageUrl,
    this.relativePosition, // 선택적 필드 (새로운 상대 좌표)
    this.isDeleted = false,
    this.type = CommentType.audio, // 기본값은 audio (하위 호환성)
    this.text, // 텍스트 댓글 내용
  });

  /// Firestore 문서에서 CommentRecordModel 객체 생성
  factory CommentRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // relativePosition 파싱 (새로운 상대 좌표)
    Offset? relativePosition;
    if (data['relativePosition'] != null) {
      final relData = data['relativePosition'] as Map<String, dynamic>;
      relativePosition = Offset(
        (relData['x'] as num?)?.toDouble() ?? 0.0,
        (relData['y'] as num?)?.toDouble() ?? 0.0,
      );
    }

    // CommentType 파싱
    CommentType commentType = CommentType.audio;
    if (data['type'] != null) {
      final typeStr = data['type'] as String;
      commentType = typeStr == 'text' ? CommentType.text : CommentType.audio;
    }

    return CommentRecordModel(
      id: doc.id,
      audioUrl: data['audioUrl'] ?? '',
      photoId: data['photoId'] ?? '',
      recorderUser: data['recorderUser'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      waveformData: List<double>.from(data['waveformData'] ?? []),
      duration: data['duration'] ?? 0,
      isDeleted: data['isDeleted'] ?? false,
      profileImageUrl: data['profileImageUrl'] ?? '',
      relativePosition: relativePosition,
      type: commentType,
      text: data['text'], // 텍스트 댓글 내용
    );
  }

  /// CommentRecordModel 객체를 Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    final result = {
      'audioUrl': audioUrl,
      'photoId': photoId,
      'recorderUser': recorderUser,
      'createdAt': Timestamp.fromDate(createdAt),
      'waveformData': waveformData,
      'duration': duration,
      'isDeleted': isDeleted,
      'profileImageUrl': profileImageUrl,
      'type': type == CommentType.text ? 'text' : 'audio',
    };

    // text가 있는 경우만 추가
    if (text != null) {
      result['text'] = text!;
    }

    // relativePosition이 있는 경우만 추가 (새로운 상대 좌표)
    if (relativePosition != null) {
      result['relativePosition'] = {
        'x': relativePosition!.dx,
        'y': relativePosition!.dy,
      };
    }

    return result;
  }

  /// CommentRecordModel 복사본 생성 (일부 필드 수정용)
  CommentRecordModel copyWith({
    String? id,
    String? audioUrl,
    String? photoId,
    String? recorderUser,
    DateTime? createdAt,
    List<double>? waveformData,
    int? duration,
    bool? isDeleted,
    String? profileImageUrl,
    Offset? profilePosition,
    Offset? relativePosition,
    CommentType? type,
    String? text,
  }) {
    return CommentRecordModel(
      id: id ?? this.id,
      audioUrl: audioUrl ?? this.audioUrl,
      photoId: photoId ?? this.photoId,
      recorderUser: recorderUser ?? this.recorderUser,
      createdAt: createdAt ?? this.createdAt,
      waveformData: waveformData ?? this.waveformData,
      duration: duration ?? this.duration,
      isDeleted: isDeleted ?? this.isDeleted,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,

      relativePosition: relativePosition ?? this.relativePosition,
      type: type ?? this.type,
      text: text ?? this.text,
    );
  }
}
