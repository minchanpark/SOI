import 'dart:io';

import '../../../api/models/selected_friend_model.dart';

/// 새 카테고리 추가 시 필요한 정보를 담는 모델
/// 카테고리 이름, 선택된 친구 목록, 선택된 커버 이미지 파일 등을 포함
/// 카테고리 생성 요청 시 이 모델을 사용하여 필요한 데이터를 전달합니다.
///
/// Parameters:
/// - [requesterId]: 카테고리를 생성하는 사용자의 ID
/// - [categoryName]: 새 카테고리의 이름
/// - [selectedFriends]: 새 카테고리에 포함될 친구들의 목록
/// - [selectedCoverImageFile]: 새 카테고리의 커버 이미지로 선택된 파일 (선택 사항)
class AddCategoryDraft {
  AddCategoryDraft({
    required this.requesterId,
    required this.categoryName,
    required List<SelectedFriendModel> selectedFriends,
    this.selectedCoverImageFile,
  }) : selectedFriends = List.unmodifiable(selectedFriends);

  final int requesterId;
  final String categoryName;
  final List<SelectedFriendModel> selectedFriends;
  final File? selectedCoverImageFile;
}
