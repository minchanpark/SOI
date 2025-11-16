import 'package:cloud_firestore/cloud_firestore.dart';

/// 카테고리 초대 상태
enum CategoryInviteStatus { pending, accepted, declined, expired }

/// 카테고리 초대 데이터 모델
class CategoryInviteModel {
  final String id;
  final String categoryId;
  final String invitedUserId;
  final String inviterUserId;
  final CategoryInviteStatus status;
  final List<String> blockedMateIds; // 초대 대상과 친구가 아닌 기존 멤버 IDs
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? respondedAt; // 수락/거절 시각
  final DateTime? expiresAt;

  const CategoryInviteModel({
    required this.id,
    required this.categoryId,
    required this.invitedUserId,
    required this.inviterUserId,
    this.status = CategoryInviteStatus.pending,
    this.blockedMateIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.respondedAt,
    this.expiresAt,
  });

  factory CategoryInviteModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return CategoryInviteModel(
      id: id,
      categoryId: data['categoryId'] ?? '',
      invitedUserId: data['invitedUserId'] ?? '',
      inviterUserId: data['inviterUserId'] ?? '',
      status: CategoryInviteStatus.values.firstWhere(
        (status) => status.name == (data['status'] ?? 'pending'),
        orElse: () => CategoryInviteStatus.pending,
      ),
      blockedMateIds:
          data['blockedMateIds'] != null
              ? List<String>.from(data['blockedMateIds'] as List)
              : const [],
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      respondedAt:
          data['respondedAt'] != null ? _toDateTime(data['respondedAt']) : null,
      expiresAt:
          data['expiresAt'] != null ? _toDateTime(data['expiresAt']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'invitedUserId': invitedUserId,
      'inviterUserId': inviterUserId,
      'status': status.name,
      'blockedMateIds': blockedMateIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  Map<String, dynamic> toFirestoreWithServerTimestamps() {
    final data = toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    return data;
  }

  CategoryInviteModel copyWith({
    String? id,
    String? categoryId,
    String? invitedUserId,
    String? inviterUserId,
    CategoryInviteStatus? status,
    List<String>? blockedMateIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? respondedAt,
    DateTime? expiresAt,
  }) {
    return CategoryInviteModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      invitedUserId: invitedUserId ?? this.invitedUserId,
      inviterUserId: inviterUserId ?? this.inviterUserId,
      status: status ?? this.status,
      blockedMateIds: blockedMateIds ?? this.blockedMateIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isPending => status == CategoryInviteStatus.pending;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw ArgumentError('Invalid timestamp value: $value');
  }
}
