# 친구 차단 및 필터링 로직 명세

## 친구 차단 로직
- **요청 진입**: `FriendController.blockFriend()`가 `FriendService.blockFriend()`를 호출하며, 차단 대상이 존재하고 이미 차단 상태가 아닌지 검증합니다 (`lib/api_firebase/services/friend_service.dart (lines 104-139)`).
- **데이터 갱신**: `FriendRepository.blockFriend()`가 `users/{currentUid}/friends/{friendUid}` 문서를 `status: 'blocked'`, `lastInteraction: Timestamp.now()`로 업데이트하고 캐시를 무효화합니다 (`lib/api_firebase/repositories/friend_repository.dart (lines 239-287)`).
- **차단 목록 재사용**: `FriendRepository.getBlockedUsers()`가 같은 경로에서 `where('status','blocked')` 쿼리로 차단 ID를 수집하고 (`lib/api_firebase/repositories/friend_repository.dart (lines 588-605)`), `FriendService.getBlockedUsers()`가 이를 다른 서비스에 전달합니다 (`lib/api_firebase/services/friend_service.dart (lines 234-241)`).

## 게시물 필터링 흐름
- **조회 결과 후처리**: 모든 사진 조회 API(`getPhotosFromAllCategoriesPaginated`, `getPhotosByCategory`, `getPhotosByCategoryStream`)가 Repository 결과를 받은 뒤 `_filterPhotosWithBlockedUsers()`를 실행합니다 (`lib/api_firebase/services/media_service.dart (lines 505-560)`).
- **필터 구현**: helper는 `FriendService.getBlockedUsers()` 호출로 차단 ID 세트를 얻고, `MediaDataModel.userID`가 포함된 항목을 제외합니다. 차단 목록이 비어 있으면 그대로 반환하고, 오류 시에도 원본을 유지합니다 (`lib/api_firebase/services/media_service.dart (lines 863-882)`).
- **효과**: 내가 차단한 사용자가 업로드한 사진은 전체 피드, 특정 카테고리, 실시간 스트림 어디에서도 전달되지 않습니다.

## 알림 필터링 흐름
- **데이터 진입점**: 알림 리스트 스트림(`getUserNotificationsStream`)과 단건 조회(`getUserNotifications`) 모두 `_notificationRepository` 결과를 받은 직후 `_filterNotificationsWithBlockedUsers()`를 거칩니다 (`lib/api_firebase/services/notification_service.dart (lines 286-310)`).
- **필터 구현**: helper가 `FriendService.getBlockedUsers()`를 통해 차단 목록을 가져와 `NotificationModel.actorUserId`가 그 목록에 있으면 제외합니다. 목록이 비어 있거나 오류가 발생하면 원본을 그대로 반환합니다 (`lib/api_firebase/services/notification_service.dart (lines 480-500)`).
- **효과**: 내가 차단한 사용자가 발송한 친구 요청, 댓글, 초대 등 모든 알림이 UI에 도달하지 않으며, 읽지 않은 개수 계산에도 포함되지 않습니다.