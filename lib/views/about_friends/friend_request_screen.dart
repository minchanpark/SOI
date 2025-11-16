import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api_firebase/controllers/friend_request_controller.dart';
import '../../api_firebase/controllers/contact_controller.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/controllers/user_matching_controller.dart';
import '../../api_firebase/services/user_matching_service.dart';
import '../../api_firebase/services/firebase_deeplink_service.dart';
import 'widgets/friend_request_card.dart';
import 'widgets/friend_suggest_card.dart';

/// 친구 요청 화면
class FriendRequestScreen extends StatefulWidget {
  const FriendRequestScreen({super.key});

  @override
  State<FriendRequestScreen> createState() => _FriendRequestScreenState();
}

class _FriendRequestScreenState extends State<FriendRequestScreen> {
  late ContactController _contactController;
  List<Contact> _suggestedContacts = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  /// 데이터 초기화
  void _initializeData() async {
    final authController = context.read<AuthController>();
    final user = authController.currentUser;

    if (user != null) {
      // 친구 요청 데이터 로드
      try {
        final friendRequestController = context.read<FriendRequestController>();

        // 컨트롤러가 초기화되어 있지 않으면 초기화
        if (!friendRequestController.isInitialized) {
          await friendRequestController.initialize();
        }

        // 데이터 새로고침

        await friendRequestController.refresh();
      } catch (e) {
        debugPrint('친구 요청 데이터 초기화 실패: $e');
      }

      // 연락처 기반 친구 추천 로드
      _loadContactSuggestions();
    } else {
      debugPrint('사용자 정보가 없습니다');
    }
  }

  /// 연락처 기반 친구 추천 로드
  void _loadContactSuggestions() async {
    _contactController = context.read<ContactController>();

    if (_contactController.contactSyncEnabled) {
      setState(() {
        _isLoadingSuggestions = true;
      });

      try {
        final contacts = await _contactController.getContacts();
        setState(() {
          _suggestedContacts = contacts;
          _isLoadingSuggestions = false;
        });
      } catch (e) {
        debugPrint('연락처 로드 실패: $e');
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  /// 친구 요청 수락
  void _onAcceptRequest(
    String requestId,
    FriendRequestController controller,
  ) async {
    try {
      await controller.acceptFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 요청을 수락했습니다'),
            backgroundColor: Color(0xFF5A5A5A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 요청 수락에 실패했습니다'),
            backgroundColor: Color(0xFF5A5A5A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 친구 요청 거절
  void _onRejectRequest(
    String requestId,
    FriendRequestController controller,
  ) async {
    try {
      await controller.rejectFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 요청을 거절했습니다'),
            backgroundColor: Color(0xFF5A5A5A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 요청 거절에 실패했습니다'),
            backgroundColor: Color(0xFF5A5A5A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 친구 추가 (연락처 기반)
  void _onAddFriend(Contact contact) async {
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
      // Contact의 전화번호 확인
      if (contact.phones.isEmpty) {
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

      AuthController authController = AuthController();

      if (phoneNumber.isEmpty) {
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

      final currentUserName = authController.currentUser?.displayName ?? '사용자';
      final currentUserId = authController.currentUser?.uid;

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

      // Firebase로 친구 초대 링크 생성
      final inviteLink = FirebaseDeeplinkService.createFriendInviteLink(
        inviterName: currentUserName,
        inviterId: currentUserId,
        inviterProfileImage: authController.currentUser?.photoURL,
      );

      final message =
          '안녕하세요! $currentUserName님이 SOI 앱에서 친구가 되고 싶어해요! 아래 링크로 SOI를 시작해보세요\n$inviteLink';

      final uri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

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

  @override
  Widget build(BuildContext context) {
    // 메인 앱에서 제공되는 기존 FriendRequestController 사용
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// AppBar 구성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        '친구 요청',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontFamily: 'Pretendard Variable',
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: false,
    );
  }

  /// Body 구성
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 받은 친구 요청 섹션
          _buildSectionTitle('친구 요청'),
          SizedBox(height: 12.h),

          Consumer<FriendRequestController>(
            builder: (context, controller, child) {
              return FriendRequestCard(
                scale: 1.0,
                onAcceptRequest: _onAcceptRequest,
                onRejectRequest: _onRejectRequest,
              );
            },
          ),

          SizedBox(height: 32.h),

          // 친구 추천 섹션
          _buildSectionTitle('친구 추천'),
          SizedBox(height: 12.h),

          Consumer<ContactController>(
            builder: (context, contactController, child) {
              return FriendSuggestCard(
                scale: 1.0,
                isInitializing: _isLoadingSuggestions,
                contacts: _suggestedContacts,
                onAddFriend: _onAddFriend,
              );
            },
          ),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  /// 섹션 제목 위젯
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 18.sp,
        fontFamily: 'Pretendard Variable',
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
