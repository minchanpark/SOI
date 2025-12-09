import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/api_firebase/controllers/auth_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api_firebase/controllers/contact_controller.dart';
import '../../api_firebase/controllers/friend_controller.dart';
import '../../api_firebase/controllers/user_matching_controller.dart';
import '../../api_firebase/controllers/friend_request_controller.dart';
import '../../api_firebase/services/contact_service.dart';
import '../../api_firebase/services/firebase_deeplink_service.dart';
import '../../api_firebase/services/user_matching_service.dart';
import 'widgets/friend_add_options_card.dart';
import 'widgets/invite_link_card.dart';
import 'widgets/friend_request_card.dart';
import 'widgets/friend_list_card.dart';
import 'widgets/friend_suggest_card.dart';
import 'dialogs/permission_settings_dialog.dart';

class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  State<FriendManagementScreen> createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen>
    with AutomaticKeepAliveClientMixin {
  List<Contact> _contacts = [];

  // 백그라운드 로딩을 위한 상태 변수들 추가
  bool _isInitializing = false;
  bool _hasInitialized = false;

  // ContactController 참조 저장
  ContactController? _contactController;
  AuthController? _authController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 화면을 즉시 표시하고 백그라운드에서 초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
      // 페이지 진입 시 동기화 재개
      _resumeSyncIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ContactController 참조를 안전하게 저장
    _contactController ??= Provider.of<ContactController>(
      context,
      listen: false,
    );
    _authController = Provider.of<AuthController>(context, listen: false);
  }

  @override
  void dispose() {
    // 페이지를 벗어날 때 동기화 일시 중지 (비동기로 처리)
    _pauseSyncIfNeededAsync();
    // Provider로 관리되는 컨트롤러들은 직접 dispose하지 않음
    // _authController와 _contactController는 Provider가 관리하므로 dispose 불필요
    super.dispose();
  }

  /// 동기화 재개 (필요한 경우)
  void _resumeSyncIfNeeded() {
    if (_contactController != null) {
      _contactController!.resumeSync();
    }
  }

  /// 동기화 일시 중지 (필요한 경우) - 비동기 버전
  void _pauseSyncIfNeededAsync() {
    if (_contactController != null) {
      // 다음 프레임에서 실행하여 위젯 트리 lock 문제 방지
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_contactController != null) {
          _contactController!.pauseSync();
        }
      });
    }
  }

  Future<void> _initializeControllers() async {
    // 백그라운드에서 순차적으로 초기화
    Future.microtask(() async {
      await _initializeFriendController();
      await _initializeFriendRequestController();

      // 연락처는 필요할 때만 로드
      if (_shouldLoadContacts()) {
        await _initializeContactPermissionInBackground();
      }
    });
  }

  bool _shouldLoadContacts() {
    // 이미 로드했거나 권한이 없으면 스킵
    if (!mounted || _contactController == null) return false;

    // 활성 동기화 상태일 때만 연락처 로드
    return _contactController!.isActivelySyncing && _contacts.isEmpty;
  }

  /// FriendController 초기화
  Future<void> _initializeFriendController() async {
    try {
      if (!mounted) return;

      final friendController = Provider.of<FriendController>(
        context,
        listen: false,
      );

      // 이미 초기화되어 있으면 스킵
      if (friendController.isInitialized) return;

      await friendController.initialize();
    } catch (e) {
      debugPrint('FriendController 초기화 실패: $e');
    }
  }

  /// FriendRequestController 초기화
  Future<void> _initializeFriendRequestController() async {
    try {
      if (!mounted) return;

      final friendRequestController = Provider.of<FriendRequestController>(
        context,
        listen: false,
      );

      // 이미 초기화되어 있으면 스킵
      if (friendRequestController.isInitialized) return;

      await friendRequestController.initialize();
      // debugPrint('FriendRequestController 초기화 완료');
    } catch (e) {
      // debugPrint('FriendRequestController 초기화 실패: $e');
    }
  }

  /// 백그라운드에서 연락처 권한 및 초기화 처리 (화면 전환 지연 방지)
  /// 최적화: 캐시 기반 조기 반환으로 반복 호출 시 O(1) 속도 달성
  Future<void> _initializeContactPermissionInBackground() async {
    // 1. 조기 반환: 이미 초기화됨 - O(1)
    if (_hasInitialized) return;

    // 2. null 체크 먼저 수행 - O(1)
    final controller = _contactController;
    if (!mounted || controller == null) return;

    // 3. 캐시된 권한 상태 확인 - O(1)
    // 이미 동기화가 활성화되어 있고 연락처가 로드되어 있으면 스킵
    if (controller.contactSyncEnabled && _contacts.isNotEmpty) {
      _hasInitialized = true;
      return;
    }

    // 4. UI 상태 업데이트 (한 번만)
    setState(() => _isInitializing = true);

    try {
      // 5. 권한 확인 (비동기 I/O - 불가피)
      final result = await controller.initializeContactPermission();

      // 6. 마운트 체크 후 연락처 로드
      if (result.isEnabled && mounted && controller.isActivelySyncing) {
        // 캐시 우선 사용 (forceRefresh: false)
        _contacts = await controller.getContacts(forceRefresh: false);
      }

      // 7. 최종 상태 업데이트 (한 번에 처리)
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasInitialized = true;
        });
        _showInitSnackBar(result.message, result.type);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasInitialized = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('초기화 중 오류가 발생했습니다: $e'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }
  }

  /// 연락처 목록 새로고침
  Future<void> _refreshContacts() async {
    try {
      if (!mounted || _contactController == null) return;

      if (_contactController!.contactSyncEnabled) {
        _contacts = await _contactController!.getContacts(forceRefresh: true);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 토글 클릭 시 처리
  Future<void> _handleToggleChange(ContactController contactController) async {
    final result = await contactController.handleToggleChange();

    if (!mounted) return;

    if (result.type == ContactToggleResultType.requiresSettings) {
      // 설정 이동 팝업 표시
      PermissionSettingsDialog.show(context, _openAppSettings);
    } else {
      // 토글 상태가 변경된 경우 연락처 목록 새로고침
      if (result.isEnabled) {
        await _refreshContacts();
      } else {
        // 연락처 동기화가 비활성화된 경우 목록 초기화
        _contacts.clear();
        if (mounted) {
          setState(() {});
        }
      }

      if (mounted) {
        _showSnackBar(result.message, result.type);
      }
    }
  }

  /// SnackBar 표시 (결과 타입에 따른 색상)
  void _showSnackBar(String message, ContactToggleResultType type) {
    // 모든 SnackBar 배경색을 0xFF5A5A5A로 통일
    const backgroundColor = Color(0xFF5A5A5A);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  /// 초기화 결과 SnackBar 표시
  void _showInitSnackBar(String message, ContactInitResultType type) {
    // 모든 SnackBar 배경색을 0xFF5A5A5A로 통일
    const backgroundColor = Color(0xFF5A5A5A);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  /// 앱 설정 화면 열기
  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();

      // 설정에서 돌아왔을 때 권한 상태 재확인
      Future.delayed(const Duration(seconds: 1), () async {
        if (!mounted || _contactController == null) return;

        final result = await _contactController!.checkPermissionAfterSettings();
        if (mounted) {
          _showSnackBar(result.message, result.type);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설정 화면을 열 수 없습니다: $e'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    // 반응형 UI를 위한 화면 너비 및 스케일 팩터 계산
    final screenWidth = MediaQuery.of(context).size.width;
    const double referenceWidth = 393;
    final double scale = screenWidth / referenceWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
      ),
      body: Consumer<ContactController>(
        builder: (context, contactController, child) {
          return SingleChildScrollView(
            // 전체적인 좌우 패딩을 반응형으로 적용
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 페이지 제목
                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구추가',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // 친구 추가 옵션 카드 위젯 함수 호출
                FriendAddOptionsCard(
                  scale: scale,
                  contactController: contactController,
                  onToggleChange: () => _handleToggleChange(contactController),
                ),

                SizedBox(height: 24.h),

                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '초대링크',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 초대링크 카드
                // 카카오톡 등등 친구 초대 링크를 공유할 수 있는 카드
                InviteLinkCard(scale: scale),

                SizedBox(height: 24.h),

                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구 요청',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 친구 요청 카드 (API)
                FriendRequestCard(scale: scale),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구 목록',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FriendListCard(scale: scale),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구 추천',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FriendSuggestCard(
                  scale: scale,
                  isInitializing: _isInitializing,
                  contacts: _contacts,
                  onAddFriend: _addFriendFromContact,
                ),
                SizedBox(height: 134.h),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 연락처에서 친구 추가
  Future<void> _addFriendFromContact(Contact contact) async {
    try {
      // UserMatchingController와 FriendRequestController 가져오기
      final userMatchingController = Provider.of<UserMatchingController>(
        context,
        listen: false,
      );
      final friendRequestController = Provider.of<FriendRequestController>(
        context,
        listen: false,
      );

      // 1. 해당 연락처가 SOI 사용자인지 확인
      final contactStatus = await userMatchingController.getContactSearchStatus(
        contact,
      );

      switch (contactStatus) {
        case ContactSearchStatus.canSendRequest:
          // SOI 사용자이고 친구 요청 가능
          // UserMatchingController를 통해 사용자 정보 다시 가져오기
          final matchedUser = await userMatchingController.findUserForContact(
            contact,
          );

          if (matchedUser != null) {
            // debugPrint('매칭된 사용자 찾음: ${matchedUser.uid}, ${matchedUser.id}');
            final success = await friendRequestController.sendFriendRequest(
              receiverUid: matchedUser.uid,
              message: '받은 친구 요청',
            );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${contact.displayName}님에게 친구 요청을 전송했습니다'),
                  backgroundColor: const Color(0xFF5A5A5A),
                ),
              );
            }
          } else {
            // SOI 사용자이지만 정보를 찾을 수 없는 경우
            // debugPrint('사용자 정보를 찾을 수 없음');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${contact.displayName}님의 정보를 확인하는 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
                  ),
                  backgroundColor: const Color(0xFF5A5A5A),
                ),
              );
            }
          }
          break;

        case ContactSearchStatus.alreadyFriend:
          // 이미 친구인 경우
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.displayName}님은 이미 친구입니다'),
                backgroundColor: const Color(0xFF5A5A5A),
              ),
            );
          }
          break;

        case ContactSearchStatus.requestSent:
          // 이미 친구 요청을 보낸 경우
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.displayName}님에게 이미 친구 요청을 보냈습니다'),
                backgroundColor: const Color(0xFF5A5A5A),
              ),
            );
          }
          break;

        case ContactSearchStatus.requestReceived:
          // 상대방이 이미 친구 요청을 보낸 경우
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${contact.displayName}님으로부터 친구 요청이 와있습니다. 친구 요청 목록을 확인해주세요',
                ),
                backgroundColor: const Color(0xFF5A5A5A),
              ),
            );
          }
          break;

        case ContactSearchStatus.notFound:
          // SOI 사용자가 아닌 경우 - SMS로 앱 설치 링크 전송
          await _sendInviteSMS(contact);
          break;

        case ContactSearchStatus.error:
          // 오류 발생
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.displayName}님 정보를 확인하는 중 오류가 발생했습니다'),
                backgroundColor: const Color(0xFF5A5A5A),
              ),
            );
          }
          break;
      }
    } catch (e) {
      // debugPrint('친구 추가 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 추가 중 오류가 발생했습니다: $e'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }
  }

  /// SMS로 앱 설치 링크 전송
  Future<void> _sendInviteSMS(Contact contact) async {
    try {
      // debugPrint('Contact 정보: ${contact.displayName}');
      // debugPrint('Contact phones 길이: ${contact.phones.length}');

      // Contact의 전화번호 확인
      if (contact.phones.isEmpty) {
        // debugPrint('전화번호가 없는 연락처: ${contact.displayName}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.displayName}님의 전화번호가 없습니다'),
              backgroundColor: const Color(0xFF5A5A5A),
            ),
          );
        }
        return;
      }

      // 첫 번째 전화번호 가져오기
      final phone = contact.phones.first;
      final phoneNumber = phone.number;

      if (phoneNumber.isEmpty) {
        // debugPrint('빈 전화번호: ${contact.displayName}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.displayName}님의 유효한 전화번호가 없습니다'),
              backgroundColor: const Color(0xFF5A5A5A),
            ),
          );
        }
        return;
      }

      final currentUserName = await _authController?.getUserName();
      final currentUserId = _authController?.currentUser?.uid;

      if (currentUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그인이 필요합니다'),
              backgroundColor: const Color(0xFF5A5A5A),
            ),
          );
        }
        return;
      }

      // Supabase로 친구 초대 링크 생성
      final inviteLink = FirebaseDeeplinkService.createFriendInviteLink(
        inviterName: currentUserName ?? 'Unknown User',
        inviterId: currentUserId,

        inviterProfileImage: _authController?.currentUser?.photoURL,
      );

      debugPrint("Inviter Name: $currentUserName");

      final message =
          '안녕하세요! $currentUserName님이 SOI 앱에서 친구가 되고 싶어해요! 아래 링크로 SOI를 시작해보세요\n\n$inviteLink';

      // URL 인코딩 문제를 방지하기 위해 직접 URI 구성
      final encodedMessage = Uri.encodeComponent(message);
      final uri = Uri.parse('sms:$phoneNumber?body=$encodedMessage');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.displayName}님에게 초대 메시지를 전송했습니다'),
              backgroundColor: const Color(0xFF5A5A5A),
            ),
          );
        }
      } else {
        throw 'SMS 앱을 열 수 없습니다';
      }
    } catch (e) {
      // debugPrint('SMS 전송 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메시지 전송 실패: $e'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }
  }
}
