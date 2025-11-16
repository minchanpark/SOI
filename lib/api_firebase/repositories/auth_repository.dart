import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/auth_model.dart';

// firebase에서 auth관련 정보를 가지고 오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // ==================== Firebase Auth 관련 ====================

  // 현재 로그인한 사용자
  User? get currentUser => _auth.currentUser;

  // 현재 로그인한 사용자의 uid 가져오기
  String? get getUserId => _auth.currentUser?.uid;

  // 전화번호 인증 요청
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(String) onTimeout,
  }) async {
    try {
      // reCAPTCHA 우회를 위한 강화된 설정
      await _auth.setSettings(
        appVerificationDisabledForTesting: false, // 실제 SMS 사용
        forceRecaptchaFlow: false, // reCAPTCHA 강제 사용 안함
      );

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android에서 SMS 자동 감지 시 자동 로그인
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            debugPrint("❌ 자동 인증 실패: $e");
          }
        },
        verificationFailed: (FirebaseAuthException exception) {
          // 특정 에러 코드 처리
          if (exception.code == 'invalid-phone-number') {
            throw Exception('유효하지 않은 전화번호입니다.');
          } else if (exception.code == 'too-many-requests') {
            throw Exception('너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.');
          } else if (exception.code == 'web-internal-error' ||
              exception.message?.contains('reCAPTCHA') == true ||
              exception.message?.contains('captcha') == true) {
            return;
          }

          throw exception;
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onTimeout(verificationId);
        },
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      // debugPrint('전화번호 인증 중 오류: $e');

      // reCAPTCHA 관련 에러는 사용자에게 영향을 주지 않으므로 무시
      if (e.toString().contains('reCAPTCHA') ||
          e.toString().contains('web-internal-error')) {
        // debugPrint('reCAPTCHA 관련 에러이므로 무시');
        return;
      }

      rethrow;
    }
  }

  // SMS 코드로 로그인
  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== Firestore 관련 ====================

  // 전화번호로 사용자 검색
  Future<DocumentSnapshot?> findUserByPhone(String phone) async {
    final query =
        await _firestore
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

    return query.docs.isNotEmpty ? query.docs.first : null;
  }

  // 사용자 정보 저장
  Future<void> saveUser(AuthModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestoreWithServerTimestamp());
  }

  // 사용자 정보 업데이트
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // 사용자 정보 조회
  Future<AuthModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      return AuthModel.fromFirestore(doc.data()!);
    }
    return null;
  }

  // 사용자 정보 조회 (getUserInfo 별칭)
  Future<AuthModel?> getUserInfo(String userId) async {
    return await getUser(userId);
  }

  // 사용자 프로필 이미지 URL 조회
  Future<String> getUserProfileImageUrlById(String userId) async {
    try {
      // debugPrint('👤 프로필 이미지 URL 조회 시작 - UserId: $userId');

      final userDoc = await _firestore.collection('users').doc(userId).get();

      // debugPrint('📄 사용자 문서 존재: ${userDoc.exists}');

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        // 각 필드 개별 확인
        final profileImageUrl = data['profileImageUrl'];
        final profileImage = data['profile_image'];

        // debugPrint('profileImageUrl 필드: $profileImageUrl');
        // debugPrint('profile_image 필드: $profileImage');
        // debugPrint('전체 사용자 데이터: $data');

        // 두 가지 필드명 모두 시도 (기존 호환성)
        final finalUrl = profileImageUrl ?? profileImage ?? '';

        // debugPrint('최종 ProfileImageUrl: "$finalUrl"');

        return finalUrl;
      }

      // debugPrint('사용자 문서가 존재하지 않음');
      return '';
    } catch (e) {
      // debugPrint('사용자 프로필 이미지 가져오기 실패: $e');
      return '';
    }
  }

  // 사용자 검색 (닉네임으로)
  Future<List<String>> searchUsersByNickname(String nickname) async {
    final query = await _firestore.collection('users').get();

    return query.docs
        .where((doc) => doc['id'].toString().contains(nickname))
        .map((doc) => doc['id'] as String)
        .toList();
  }

  /// 여러 사용자의 프로필 이미지를 실시간으로 가져오는 스트림 (UID 기반)
  ///
  /// [userIds]: 사용자 UID 리스트 (문서 ID)
  /// Returns: Stream<Map<userId, profileImageUrl>>
  Stream<Map<String, String>> getMultipleUserProfileImagesStream(
    List<String> userIds,
  ) {
    if (userIds.isEmpty) {
      return Stream.value({});
    }

    final controller = StreamController<Map<String, String>>();
    final Map<String, String> profileCache = {};
    final List<StreamSubscription<DocumentSnapshot>> subscriptions = [];

    // 각 사용자의 프로필 이미지를 실시간으로 구독
    for (final userId in userIds) {
      final sub = _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen(
            (doc) {
              if (doc.exists) {
                final data = doc.data();
                // 두 가지 필드명 지원 (기존 호환성)
                final url =
                    data?['profileImageUrl'] ?? data?['profile_image'] ?? '';
                profileCache[userId] = url;
              } else {
                // 문서가 없으면 빈 문자열
                profileCache[userId] = '';
              }

              // 변경사항을 Map으로 emit
              if (!controller.isClosed) {
                controller.add(Map.from(profileCache));
              }
            },
            onError: (error) {
              debugPrint('프로필 이미지 Stream 오류 - UserId: $userId, Error: $error');
              // 에러 발생 시 빈 문자열로 처리
              profileCache[userId] = '';
              if (!controller.isClosed) {
                controller.add(Map.from(profileCache));
              }
            },
          );

      subscriptions.add(sub);
    }

    // Stream이 취소되면 모든 Firestore 구독 해제
    controller.onCancel = () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
      subscriptions.clear();
    };

    return controller.stream;
  }

  /// 단일 사용자의 프로필 이미지를 실시간으로 가져오는 스트림 (UID 기반)
  ///
  /// [userId]: 사용자 UID (문서 ID)
  /// Returns: Stream<String> - 프로필 이미지 URL
  Stream<String> getUserProfileImageStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map<String>((snapshot) {
          if (!snapshot.exists) return '';

          final data = snapshot.data();
          // 두 가지 필드명 지원 (기존 호환성)
          final url = data?['profileImageUrl'] ?? data?['profile_image'] ?? '';
          return url is String ? url : '';
        })
        .handleError((error) {
          debugPrint('프로필 이미지 Stream 오류 - UserId: $userId, Error: $error');
        });
  }

  // 사용자 삭제
  Future<void> deleteUser(String uid) async {
    try {
      // 0. 사용자가 생성한 모든 컨텐츠 삭제 (사진/오디오/댓글/리액션/알림 등)
      await _deleteAllUserContent(uid);

      // 1. 사용자의 모든 친구 관계 삭제
      final friendsCollection = _firestore
          .collection('users')
          .doc(uid)
          .collection('friends');
      final friendsSnapshot = await friendsCollection.get();

      // 배치 삭제로 성능 최적화 (500 한도 대비 챙김)
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      Future<void> commitIfNeeded() async {
        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      Future<void> queueDelete(DocumentReference ref) async {
        batch.delete(ref);
        operationCount++;
        await commitIfNeeded();
      }

      Future<void> queueUpdate(
        DocumentReference ref,
        Map<String, dynamic> data,
      ) async {
        batch.update(ref, data);
        operationCount++;
        await commitIfNeeded();
      }

      for (var friendDoc in friendsSnapshot.docs) {
        await queueDelete(friendDoc.reference);
      }

      // 2. 다른 사용자들의 friends 컬렉션에서 이 사용자 제거
      final allUsersSnapshot = await _firestore.collection('users').get();
      for (var userDoc in allUsersSnapshot.docs) {
        if (userDoc.id != uid) {
          final otherUserFriendDoc = userDoc.reference
              .collection('friends')
              .doc(uid);
          await queueDelete(otherUserFriendDoc);
        }
      }

      // 3. 사용자가 멤버인 모든 카테고리에서 제거
      final categoriesSnapshot =
          await _firestore
              .collection('categories')
              .where('mates', arrayContains: uid)
              .get();

      for (var categoryDoc in categoriesSnapshot.docs) {
        final categoryData = categoryDoc.data();
        final mates = List<String>.from(categoryData['mates'] ?? []);
        mates.remove(uid);

        if (mates.isEmpty) {
          final photosSnapshot =
              await categoryDoc.reference.collection('photos').get();

          for (final photoDoc in photosSnapshot.docs) {
            await _deletePhotoDocumentWithAssets(photoDoc);
          }

          await queueDelete(categoryDoc.reference);
        } else {
          await queueUpdate(categoryDoc.reference, {'mates': mates});
        }
      }

      // 4. 사용자 문서 삭제
      await queueDelete(_firestore.collection('users').doc(uid));

      if (operationCount > 0) {
        await batch.commit();
      }

      // debugPrint('✅ 사용자 데이터 완전 삭제 완료: $uid');
    } catch (e) {
      // debugPrint('❌ 사용자 삭제 실패: $e');
      throw Exception('사용자 데이터 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // ==================== 유저 컨텐츠 전체 삭제 ====================

  Future<void> _deleteAllUserContent(String uid) async {
    // 사진, 오디오, 댓글, 리액션, 알림 순으로 정리
    await _deleteUserReactions(uid);
    await _deleteUserCommentRecords(uid);
    await _deleteUserAudios(uid);
    await _deleteUserPhotos(uid);
    await _deleteUserNotifications(uid);
  }

  Future<void> _deleteUserReactions(String uid) async {
    try {
      final snap =
          await _firestore
              .collectionGroup('reactions')
              .where('uid', isEqualTo: uid)
              .get();
      if (snap.docs.isEmpty) return;

      // 배치 삭제 (최대 500개씩)
      int index = 0;
      while (index < snap.docs.length) {
        final batch = _firestore.batch();
        final end = (index + 450).clamp(0, snap.docs.length);
        for (int i = index; i < end; i++) {
          batch.delete(snap.docs[i].reference);
        }
        await batch.commit();
        index = end;
      }
    } catch (_) {
      // 무시 (계속 진행)
    }
  }

  Future<void> _deleteUserCommentRecords(String uid) async {
    try {
      final snap =
          await _firestore
              .collection('comment_records')
              .where('recorderUser', isEqualTo: uid)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final audioUrl = data['audioUrl'] as String?;
        if (audioUrl != null && audioUrl.isNotEmpty) {
          await _tryDeleteAnyStorageFile(audioUrl);
        }
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Future<void> _deleteUserAudios(String uid) async {
    try {
      final snap =
          await _firestore
              .collection('audios')
              .where('userId', isEqualTo: uid)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final url = data['firebaseUrl'] as String?; // supabase URL일 수도 있음
        if (url != null && url.isNotEmpty) {
          await _tryDeleteAnyStorageFile(url);
        }
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Future<void> _deleteUserPhotos(String uid) async {
    try {
      final snap =
          await _firestore
              .collectionGroup('photos')
              .where('userID', isEqualTo: uid)
              .get();

      for (final doc in snap.docs) {
        await _deletePhotoDocumentWithAssets(doc);
      }
    } catch (_) {}
  }

  Future<void> _deletePhotoDocumentWithAssets(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final imageUrl = data['imageUrl'] as String?;
    final audioUrl = data['audioUrl'] as String?;

    try {
      final commentsSnap =
          await _firestore
              .collection('comment_records')
              .where('photoId', isEqualTo: doc.id)
              .get();
      for (final c in commentsSnap.docs) {
        final cAudio = c.data()['audioUrl'] as String?;
        if (cAudio != null && cAudio.isNotEmpty) {
          await _tryDeleteAnyStorageFile(cAudio);
        }
        await c.reference.delete();
      }
    } catch (_) {}

    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _tryDeleteAnyStorageFile(imageUrl);
    }
    if (audioUrl != null && audioUrl.isNotEmpty) {
      await _tryDeleteAnyStorageFile(audioUrl);
    }

    await doc.reference.delete();
  }

  Future<void> _deleteUserNotifications(String uid) async {
    try {
      // 수신자 기준 알림 삭제
      final recv =
          await _firestore
              .collection('notifications')
              .where('recipientUserId', isEqualTo: uid)
              .get();
      for (final d in recv.docs) {
        await d.reference.delete();
      }

      // 발신자 기준 알림 삭제
      final sent =
          await _firestore
              .collection('notifications')
              .where('actorUserId', isEqualTo: uid)
              .get();
      for (final d in sent.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
  }

  // ==================== Storage 유틸리티 ====================
  Future<void> _tryDeleteAnyStorageFile(String url) async {
    // 1) Firebase Storage 시도
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return;
    } catch (_) {
      // 계속 진행 (Supabase일 수 있음)
    }

    // 2) Supabase Storage 시도
    try {
      final uri = Uri.parse(url);
      // 형식 예: https://xxxx.supabase.co/storage/v1/object/public/<bucket>/<path>
      if (!uri.path.contains('/storage/v1/object/public/')) return;
      final parts = uri.path.split('/');
      final idx = parts.indexOf('public');
      if (idx < 0 || idx + 2 >= parts.length) return;

      final bucket = parts[idx + 1];
      final pathSegments = parts.sublist(idx + 2);
      final objectPath = pathSegments.join('/');

      final supabase = Supabase.instance.client;
      await supabase.storage.from(bucket).remove([objectPath]);
    } catch (_) {
      // 무시
    }
  }

  // ==================== Storage 관련 ====================

  // 갤러리에서 이미지 선택
  Future<File?> pickImageFromGallery() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    return pickedImage != null ? File(pickedImage.path) : null;
  }

  // 프로필 이미지 업로드
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    final fileName =
        'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.png';
    final ref = _storage.ref().child('profiles').child(uid).child(fileName);

    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() => null);

    return await snapshot.ref.getDownloadURL();
  }

  // 파일 경로에서 프로필 이미지 업로드
  Future<String> uploadProfileImageFromPath(
    String uid,
    String imagePath,
  ) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw Exception('이미지 파일을 찾을 수 없습니다.');
    }

    return await uploadProfileImage(uid, file);
  }

  // ID 중복 확인
  Future<bool> isIdDuplicate(String id) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('id', isEqualTo: id)
              .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking ID duplicate in Firestore: $e');
      return false;
    }
  }

  // 사용자가 올린 모든 사진의 unactive 필드를 true로 설정
  Future<void> deactivateUserPhotos(String userId) async {
    try {
      // collectionGroup을 사용하여 모든 카테고리의 photos 서브컬렉션에서 해당 사용자의 사진 찾기
      final photosSnapshot =
          await _firestore
              .collectionGroup('photos')
              .where('userID', isEqualTo: userId)
              .get();

      // 배치 업데이트로 성능 최적화
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      for (final doc in photosSnapshot.docs) {
        batch.update(doc.reference, {'unactive': true});
        operationCount++;

        // Firestore 배치 제한(500개)에 대비하여 450개마다 커밋
        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      // 남은 업데이트 커밋
      if (operationCount > 0) {
        await batch.commit();
      }

      debugPrint('✅ 사용자 $userId의 ${photosSnapshot.docs.length}개 사진을 비활성화했습니다.');
    } catch (e) {
      debugPrint('❌ 사용자 사진 비활성화 실패: $e');
      rethrow;
    }
  }

  // 사용자가 올린 모든 사진의 unactive 필드를 false로 설정 (활성화)
  Future<void> activateUserPhotos(String userId) async {
    try {
      final photosSnapshot =
          await _firestore
              .collectionGroup('photos')
              .where('userID', isEqualTo: userId)
              .get();

      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      for (final doc in photosSnapshot.docs) {
        batch.update(doc.reference, {'unactive': false});
        operationCount++;

        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }

      debugPrint('✅ 사용자 $userId의 ${photosSnapshot.docs.length}개 사진을 활성화했습니다.');
    } catch (e) {
      debugPrint('❌ 사용자 사진 활성화 실패: $e');
      rethrow;
    }
  }

  // 사용자 비활성화 상태 업데이트
  Future<void> updateUserDeactivationStatus(
    String userId,
    bool isDeactivated,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeactivated': isDeactivated,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 사용자 $userId 비활성화 상태를 $isDeactivated로 업데이트했습니다.');
    } catch (e) {
      debugPrint('❌ 사용자 비활성화 상태 업데이트 실패: $e');
      rethrow;
    }
  }
}
