import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
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

  // ✅ 백그라운드 로딩을 위한 상태 변수들 추가
  bool _isInitializing = false;
  bool _hasInitialized = false;

  // ContactController 참조 저장
  ContactController? _contactController;

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

  /// ✅ 백그라운드에서 연락처 권한 및 초기화 처리 (화면 전환 지연 방지)
  Future<void> _initializeContactPermissionInBackground() async {
    if (_hasInitialized) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      if (!mounted || _contactController == null) return;

      // ✅ 1단계: 권한 확인 (빠른 처리)
      final result = await _contactController!.initializeContactPermission();

      // ✅ 2단계: 권한이 허용된 경우에만 연락처 로드 (느린 처리)
      if (result.isEnabled &&
          mounted &&
          _contactController!.isActivelySyncing) {
        try {
          _contacts = await _contactController!.getContacts(
            forceRefresh: false,
          );

          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          // debugPrint('연락처 로드 실패: $e');
        }
      }

      // ✅ 3단계: 초기화 완료 및 메시지 표시
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
            content: Text(
              tr(
                'friends.manage.init_error',
                context: context,
                namedArgs: {'error': e.toString()},
              ),
            ),
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
            content: Text(
              tr(
                'friends.manage.settings_error',
                context: context,
                namedArgs: {'error': e.toString()},
              ),
            ),
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
                    tr('friends.manage.add_title', context: context),
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
                    tr('friends.manage.invite_link', context: context),
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
                    tr('friends.manage.requests', context: context),
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 친구 요청 카드
                FriendRequestCard(scale: scale),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    tr('friends.manage.list', context: context),
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
                    tr('friends.manage.suggest', context: context),
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
                ),
                SizedBox(height: 134.h),
              ],
            ),
          );
        },
      ),
    );
  }
}
