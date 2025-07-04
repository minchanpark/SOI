import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// 인증 관련 비즈니스 로직을 처리하는 Model 클래스
class AuthModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  String? _verificationId;
  ConfirmationResult? _confirmationResult;

  // 현재 로그인한 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 현재 사용자 ID 가져오기
  String? get getUserId => _auth.currentUser?.uid;

  // 전화번호로 기존 사용자를 찾는 메서드
  Future<DocumentSnapshot?> findUserByPhone(String phone) async {
    try {
      // 전화번호 형식 정규화
      String formattedPhone = phone;
      if (phone.startsWith('0')) {
        formattedPhone = phone.substring(1);
      }

      // users 컬렉션에서 phone 필드가 일치하는 문서 검색
      QuerySnapshot querySnapshot =
          await _firestore
              .collection('users')
              .where('phone', isEqualTo: formattedPhone)
              .limit(1)
              .get();

      // 검색 결과가 있으면 첫 번째 문서 반환, 없으면 null 반환
      return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
    } catch (e) {
      debugPrint('전화번호로 사용자 검색 중 오류 발생: $e');
      return null;
    }
  }

  // 회원가입 시 사용자 정보를 Firestore에 저장
  Future<void> createUserInFirestore(
    User user,
    String id,
    String name,
    String phone,
    String birthDate,
  ) async {
    try {
      // 전화번호 형식 정규화
      String formattedPhone = phone;
      if (phone.startsWith('0')) {
        formattedPhone = phone.substring(1);
      }

      // 전화번호로 기존 사용자 검색
      DocumentSnapshot? existingUser = await findUserByPhone(formattedPhone);

      if (existingUser != null) {
        // 기존 사용자가 있는 경우, 해당 문서 업데이트
        String existingUserId = existingUser.id;
        debugPrint('기존 사용자 발견 (ID: $existingUserId), 정보 업데이트');

        await _firestore.collection('users').doc(existingUserId).update({
          'uid': user.uid, // 새 Firebase Auth의 고유 ID로 업데이트
          'lastLogin': Timestamp.now(), // 마지막 로그인 시간 업데이트
          'id': id,
          'name': name,
          'birth_date': birthDate,
          // profile_image는 유지
        });

        // 필요한 경우 사용자 정보를 새 문서로도 복제 (기존 문서 ID와 새 Auth UID가 다른 경우)
        if (existingUserId != user.uid) {
          Map<String, dynamic> userData =
              existingUser.data() as Map<String, dynamic>;
          userData['uid'] = user.uid;
          userData['lastLogin'] = Timestamp.now();
          userData['id'] = id;
          userData['name'] = name;
          userData['birth_date'] = birthDate;

          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(userData, SetOptions(merge: true));
        }
      } else {
        // 새 사용자인 경우, 새 문서 생성
        debugPrint('새 사용자 생성 (ID: ${user.uid})');
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid, // Firebase Auth의 고유 ID
          'createdAt': Timestamp.now(), // 생성 시간
          'lastLogin': Timestamp.now(), // 마지막 로그인 시간
          'id': id,
          'name': name,
          'phone': formattedPhone, // 정규화된 전화번호 저장
          'birth_date': birthDate,
          'profile_image': '', // 프로필 이미지 URL
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('사용자 문서 생성/업데이트 중 오류 발생: $e');
      rethrow;
    }
  }

  // firestore에 id 필드의 값 가지고 오는 함수
  Future<String> getIdFromFirestore() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();
      if (documentSnapshot.exists) {
        // 닉네임 필드 가져오기
        String? fetchedId = documentSnapshot.get('id');
        debugPrint('Fetched Id: $fetchedId');
        return fetchedId ?? 'Default Nickname';
      } else {
        debugPrint('User document does not exist');
        return 'Default Nickname'; // 기본 닉네임 반환
      }
    } catch (e) {
      debugPrint('Error fetching user document: $e');
      rethrow;
    }
  }

  // 사용자 검색 메서드
  Future<List<String>> searchNickName(String userNickName) async {
    List<String> results = [];

    if (userNickName.isEmpty) return results;

    try {
      // users 컬렉션의 모든 문서 가져오기
      final QuerySnapshot result = await _firestore.collection('users').get();

      // uid가 일치하거나 3글자 이상 비슷한 문서 필터링
      results =
          result.docs
              .where((doc) {
                String id = doc['id'] as String;

                // 정확히 일치하는 경우
                if (id == userNickName) return true;

                // 3글자 이상 비슷한지 확인
                int matchCount = 0;
                int minLength =
                    id.length < userNickName.length
                        ? id.length
                        : userNickName.length;

                for (int i = 0; i < minLength; i++) {
                  if (id[i] == userNickName[i]) matchCount++;
                }

                return matchCount >= 2;
              })
              .map((doc) => doc['id'] as String)
              .toList();

      return results;
    } catch (e) {
      debugPrint('Error searching users: $e');
      rethrow;
    }
  }

  // mates에 맞는 사용자들의 프로필 이미지 리스트 가지고 오기
  Stream<List<String>> getprofileImages(List<dynamic> mates) {
    if (mates.isEmpty) {
      return Stream.value([]);
    }

    debugPrint('Fetching profile images for mates: $mates');

    return _firestore
        .collection('users')
        .where('id', whereIn: mates)
        .snapshots()
        .map((querySnapshot) {
          // mates에 정확히 매치되는 프로필 이미지만 추출합니다
          List<String> profileImages = [];
          for (var doc in querySnapshot.docs) {
            try {
              String userId = doc['id'] as String;
              String profileImage = doc['profile_image'] as String;

              // 유효한 프로필 이미지만 추가 (빈 문자열이나 null이 아닌)
              if (mates.contains(userId) && profileImage.isNotEmpty) {
                profileImages.add(profileImage);
                debugPrint(
                  'Added profile image for user $userId: $profileImage',
                );
              } else if (profileImage.isEmpty) {
                debugPrint('User $userId has empty profile image');
              }
            } catch (e) {
              debugPrint('Error processing user doc: $e');
            }
          }

          debugPrint('Final profile images count: ${profileImages.length}');
          return profileImages;
        });
  }

  // reCAPTCHA 초기화 및 재설정
  Future<void> resetRecaptcha() async {
    try {
      debugPrint('reCAPTCHA 초기화 시작');

      if (kIsWeb) {
        // 웹에서는 reCAPTCHA 설정 초기화
        await _auth.setSettings(
          appVerificationDisabledForTesting: false,
          forceRecaptchaFlow: true, // reCAPTCHA 강제 사용
        );

        // 더 긴 대기 시간으로 reCAPTCHA 로드 완료 대기
        await Future.delayed(const Duration(milliseconds: 2000));
      } else {
        // 모바일에서는 reCAPTCHA 비활성화
        await _auth.setSettings(
          appVerificationDisabledForTesting: false,
          forceRecaptchaFlow: false,
        );

        await Future.delayed(const Duration(milliseconds: 1000));
      }

      debugPrint('reCAPTCHA 초기화 완료');
    } catch (e) {
      debugPrint('reCAPTCHA 초기화 중 오류: $e');
      // 재시도 로직 추가
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        await _auth.setSettings(
          appVerificationDisabledForTesting: false,
          forceRecaptchaFlow: kIsWeb,
        );
      } catch (retryError) {
        debugPrint('reCAPTCHA 재시도 실패: $retryError');
      }
    }
  }

  // 전화번호 인증 요청 (플랫폼별 구분)
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String verificationId, int? resendToken) onCodeSent,
    Function(String verificationId) codeAutoRetrievalTimeout,
  ) async {
    try {
      // 전화번호 형식 확인 및 정규화
      String formattedPhone = phoneNumber;
      if (phoneNumber.startsWith('0')) {
        formattedPhone = phoneNumber.substring(1);
      }
      final String fullPhoneNumber = "+82$formattedPhone";
      debugPrint('Formatted phone number: $fullPhoneNumber');

      if (kIsWeb) {
        // 웹 플랫폼에서는 signInWithPhoneNumber 사용
        await _signInWithPhoneNumberWeb(fullPhoneNumber, onCodeSent);
      } else {
        // 네이티브 플랫폼에서는 verifyPhoneNumber 사용
        await _verifyPhoneNumberNative(
          fullPhoneNumber,
          onCodeSent,
          codeAutoRetrievalTimeout,
        );
      }
    } catch (e) {
      debugPrint('Error verifying phone number: $e');
      Fluttertoast.showToast(msg: '전화번호 인증 중 오류가 발생했습니다: $e');
    }
  }

  // 웹용 전화번호 인증
  Future<void> _signInWithPhoneNumberWeb(
    String phoneNumber,
    Function(String verificationId, int? resendToken) onCodeSent,
  ) async {
    try {
      debugPrint('웹 전화번호 인증 시작: $phoneNumber');

      // reCAPTCHA 로드 확인 및 재시도 로직
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          // 웹에서는 RecaptchaVerifier를 사용하여 signInWithPhoneNumber 호출
          _confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);

          // 확인 결과를 저장하고 콜백 호출
          _verificationId = _confirmationResult!.verificationId;
          onCodeSent(_confirmationResult!.verificationId, null);

          debugPrint(
            "웹 전화번호 인증 성공, verificationId: ${_confirmationResult!.verificationId}",
          );
          return; // 성공 시 메서드 종료
        } catch (e) {
          retryCount++;
          debugPrint('웹 전화번호 인증 시도 $retryCount 실패: $e');

          if (e.toString().contains('web-internal-error') ||
              e.toString().contains('reCAPTCHA')) {
            // reCAPTCHA 관련 오류 시 재시도
            if (retryCount < maxRetries) {
              debugPrint('reCAPTCHA 재시도 중... ($retryCount/$maxRetries)');
              await Future.delayed(Duration(seconds: retryCount * 2));

              // reCAPTCHA 재초기화
              await resetRecaptcha();
              continue;
            }
          }

          // 최대 재시도 횟수 도달 또는 다른 오류
          throw e;
        }
      }

      throw Exception('웹 전화번호 인증 최대 재시도 횟수 초과');
    } catch (e) {
      debugPrint('웹 전화번호 인증 최종 실패: $e');
      Fluttertoast.showToast(msg: '전화번호 인증에 실패했습니다. 네트워크 연결을 확인하고 다시 시도해주세요.');
      rethrow;
    }
  }

  // 네이티브용 전화번호 인증
  Future<void> _verifyPhoneNumberNative(
    String phoneNumber,
    Function(String verificationId, int? resendToken) onCodeSent,
    Function(String verificationId) codeAutoRetrievalTimeout,
  ) async {
    try {
      // reCAPTCHA 캐시 문제 해결을 위한 대기 시간 추가
      await Future.delayed(const Duration(milliseconds: 500));

      await _auth.setSettings(
        appVerificationDisabledForTesting: false,
        forceRecaptchaFlow: false,
      );

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: null,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint("credential :: $credential");
        },
        verificationFailed: (FirebaseAuthException exception) {
          debugPrint("exception :: $exception");
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(verificationId, resendToken);
          debugPrint("verificationId :: $verificationId");
          debugPrint("resendToken :: $resendToken");
        },
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      debugPrint('Native phone auth error: $e');
      rethrow;
    }
  }

  // SMS 코드로 로그인 (플랫폼별 구분)
  Future<bool> signInWithSmsCode(String verificationId, String smsCode) async {
    if (verificationId.isEmpty) {
      Fluttertoast.showToast(msg: '인증 ID가 없습니다. 다시 시도해주세요.');
      return false;
    }

    try {
      debugPrint('Signing in with SMS code. Verification ID: $verificationId');

      if (kIsWeb) {
        // 웹에서는 ConfirmationResult.confirm() 사용
        return await _signInWithSmsCodeWeb(smsCode);
      } else {
        // 네이티브에서는 PhoneAuthCredential 사용
        return await _signInWithSmsCodeNative(verificationId, smsCode);
      }
    } catch (e) {
      debugPrint('Error signing in with SMS code: $e');
      Fluttertoast.showToast(msg: '인증 코드 확인 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  // 웹용 SMS 코드 확인
  Future<bool> _signInWithSmsCodeWeb(String smsCode) async {
    if (_confirmationResult == null) {
      Fluttertoast.showToast(msg: '전화번호 인증을 먼저 진행해주세요.');
      return false;
    }

    try {
      UserCredential userCredential = await _confirmationResult!.confirm(
        smsCode,
      );
      if (userCredential.user != null) {
        debugPrint('Successfully signed in (web): ${userCredential.user?.uid}');
        return true;
      } else {
        Fluttertoast.showToast(msg: '로그인에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('Web SMS verification error: $e');
      rethrow;
    }
  }

  // 네이티브용 SMS 코드 확인
  Future<bool> _signInWithSmsCodeNative(
    String verificationId,
    String smsCode,
  ) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      if (userCredential.user != null) {
        debugPrint(
          'Successfully signed in (native): ${userCredential.user?.uid}',
        );
        return true;
      } else {
        Fluttertoast.showToast(msg: '로그인에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('Native SMS verification error: $e');
      rethrow;
    }
  }

  // 사용자 정보 가져오기
  Future<String> getUserID() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();

      if (documentSnapshot.exists) {
        // 아이디 필드 가져오기 (문서에 있는 실제 아이디 필드명에 맞게 수정 필요)
        return documentSnapshot.data()!.toString().contains('id')
            ? documentSnapshot.get('id').toString()
            : 'user id'; // 기본값
      } else {
        debugPrint('User document does not exist');
        return 'user id'; // 기본값
      }
    } catch (e) {
      debugPrint('Error fetching user id: $e');
      return 'user id'; // 오류 시 기본값
    }
  }

  Future<String> getUserName() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();

      if (documentSnapshot.exists) {
        // 아이디 필드 가져오기 (문서에 있는 실제 아이디 필드명에 맞게 수정 필요)
        return documentSnapshot.data()!.toString().contains('name')
            ? documentSnapshot.get('name').toString()
            : 'user name'; // 기본값
      } else {
        debugPrint('User document does not exist');
        return 'user name'; // 기본값
      }
    } catch (e) {
      debugPrint('Error fetching user id: $e');
      return 'user name'; // 오류 시 기본값
    }
  }

  Future<String> getUserPhoneNumber() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();

      if (documentSnapshot.exists) {
        // 아이디 필드 가져오기 (문서에 있는 실제 아이디 필드명에 맞게 수정 필요)
        return documentSnapshot.data()!.toString().contains('phone')
            ? documentSnapshot.get('phone').toString()
            : 'phone number'; // 기본값
      } else {
        debugPrint('User document does not exist');
        return 'phone number'; // 기본값
      }
    } catch (e) {
      debugPrint('Error fetching user id: $e');
      return 'phone number'; // 오류 시 기본값
    }
  }

  // 로그아웃 기능
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error signing out: $e');
      Fluttertoast.showToast(msg: '로그아웃 중 오류가 발생했습니다.');
      rethrow;
    }
  }

  // 프로필 이미지 URL 가져오기
  Future<String> getUserProfileImageUrl() async {
    try {
      // 현재 사용자의 UID 확인
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('사용자가 로그인되어 있지 않습니다');
        return '';
      }

      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore.collection('users').doc(uid).get();

      if (documentSnapshot.exists) {
        // profile_image 필드 가져오기
        return documentSnapshot.data()!.toString().contains('profile_image')
            ? documentSnapshot.get('profile_image').toString()
            : '';
      } else {
        debugPrint('사용자 문서가 존재하지 않습니다');
        return '';
      }
    } catch (e) {
      debugPrint('프로필 이미지 URL 가져오기 오류: $e');
      return '';
    }
  }

  // 갤러리에서 이미지 선택
  Future<File?> pickImageFromGallery() async {
    try {
      // 이미지 선택
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // 이미지 품질 (0-100)
      );

      if (pickedImage == null) {
        debugPrint('이미지 선택이 취소되었습니다');
        return null;
      }

      // XFile을 File로 변환
      return File(pickedImage.path);
    } catch (e) {
      debugPrint('이미지 선택 중 오류 발생: $e');
      Fluttertoast.showToast(msg: '이미지를 선택하는 중 오류가 발생했습니다');
      return null;
    }
  }

  // 이미지 압축 함수
  Future<Object?> compressImage(File imageFile) async {
    try {
      // 원본 파일 경로 및 이름 가져오기
      final String fileName = path.basename(imageFile.path);
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/$fileName';

      // 이미지 압축 실행
      final XFile? compressedFile =
          await FlutterImageCompress.compressAndGetFile(
            imageFile.absolute.path,
            targetPath,
            quality: 70, // 압축 품질 (0-100)
            minWidth: 1024, // 최소 너비
            minHeight: 1024, // 최소 높이
          );

      return compressedFile;
    } catch (e) {
      debugPrint('이미지 압축 중 오류 발생: $e');
      return imageFile; // 압축 실패 시 원본 반환
    }
  }

  // 프로필 이미지 업로드 및 Firestore 업데이트
  Future<bool> uploadProfileImage(File imageFile) async {
    try {
      // 현재 사용자의 UID 확인
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('사용자가 로그인되어 있지 않습니다');
        return false;
      }

      // 1. 이미지 압축
      final Object? compressedFile = await compressImage(imageFile);
      if (compressedFile == null) {
        debugPrint('이미지 압축 실패');
        return false;
      }

      // 2. 파일 이름 생성 (고유한 파일명 보장)
      final String fileName =
          'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.png';

      // 3. Firebase Storage에 업로드
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profiles')
          .child(uid)
          .child(fileName);

      // 업로드 작업 생성 및 진행
      UploadTask uploadTask;
      if (compressedFile is File) {
        // If compression returned a File object
        uploadTask = storageRef.putFile(compressedFile);
      } else if (compressedFile is XFile) {
        // If compression returned an XFile object
        uploadTask = storageRef.putFile(File((compressedFile).path));
      } else {
        // Fallback to original file if compression result is unexpected
        uploadTask = storageRef.putFile(imageFile);
        debugPrint(
          'Using original image as compression returned unexpected type',
        );
      }

      // 업로드 완료 대기
      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);

      // 업로드된 파일의 다운로드 URL 가져오기
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // 4. Firestore 사용자 문서 업데이트
      await _firestore.collection('users').doc(uid).update({
        'profile_image': downloadUrl,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('프로필 이미지 업로드 완료: $downloadUrl');

      // 업로드 성공
      return true;
    } catch (e) {
      debugPrint('프로필 이미지 업로드 중 오류 발생: $e');
      Fluttertoast.showToast(msg: '프로필 이미지를 업로드하는 중 오류가 발생했습니다');
      return false;
    }
  }

  Future<void> deleteUser() async {
    try {
      // Firestore에서 사용자 문서 삭제
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).delete();
        debugPrint('Firestore에서 사용자 문서 삭제 완료');
      }

      // Firebase Authentication에서 사용자 삭제
      _auth.currentUser?.delete();
      debugPrint('Firebase Authentication에서 사용자 삭제 완료');
    } catch (e) {
      debugPrint('사용자 삭제 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 프로필 이미지 URL이 유효한지 확인하는 함수
  Future<bool> isValidImageUrl(String imageUrl) async {
    if (imageUrl.isEmpty) return false;

    try {
      // Firebase Storage의 URL이라면 URL 구조를 검사
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        // HTTP 헤더만 요청하여 이미지가 존재하는지 확인 (빠른 방법)
        final http.Response response = await http.head(Uri.parse(imageUrl));
        return response.statusCode == 200;
      }
      return false;
    } catch (e) {
      debugPrint('이미지 URL 확인 중 오류 발생: $e');
      return false;
    }
  }

  /// 유효하지 않은 프로필 이미지 URL을 초기화하는 함수
  Future<void> cleanInvalidProfileImageUrl() async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // 현재 사용자의 프로필 이미지 URL 가져오기
      final String profileImageUrl = await getUserProfileImageUrl();

      // URL이 유효하지 않으면 빈 문자열로 초기화
      if (profileImageUrl.isNotEmpty &&
          !(await isValidImageUrl(profileImageUrl))) {
        debugPrint('유효하지 않은 프로필 이미지 URL 초기화: $profileImageUrl');
        await _firestore.collection('users').doc(uid).update({
          'profile_image': '',
        });
      }
    } catch (e) {
      debugPrint('프로필 이미지 URL 정리 중 오류 발생: $e');
    }
  }
}
