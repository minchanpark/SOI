import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/user_controller.dart';

/// 친구 추천 카드
/// 연락처 동기화가 활성화된 경우, 연락처 목록에서 SOI 사용자들을 추천합니다.
class FriendSuggestCard extends StatefulWidget {
  final double scale;
  final bool isInitializing;
  final List<Contact> contacts;

  const FriendSuggestCard({
    super.key,
    required this.scale,
    required this.isInitializing,
    required this.contacts,
  });

  @override
  State<FriendSuggestCard> createState() => _FriendSuggestCardState();
}

class _FriendSuggestCardState extends State<FriendSuggestCard> {
  /// 전화번호 -> 친구 상태 매핑
  /// 상태값: 'none', 'pending', 'accepted', 'blocked', 'loading'
  final Map<String, String> _friendshipStatuses = {};

  /// 상태 로드 대기 중인 전화번호 목록
  final Set<String> _pendingPhoneNumbers = {};

  /// 현재 로드 중인지 여부
  bool _isLoadingBatch = false;

  /// Debounce 타이머
  Timer? _debounceTimer;

  /// 배치 로드 간격 (밀리초)
  static const int _batchDebounceMs = 100;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 특정 전화번호의 상태 로드 요청 (lazy loading)
  void _requestStatusLoad(String phoneNumber) {
    // 이미 로드됨 또는 대기 중이면 무시
    if (_friendshipStatuses.containsKey(phoneNumber) ||
        _pendingPhoneNumbers.contains(phoneNumber)) {
      return;
    }

    // 대기 목록에 추가
    _pendingPhoneNumbers.add(phoneNumber);

    // debounce: 짧은 시간 내 여러 요청을 모아서 한 번에 처리
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      Duration(milliseconds: _batchDebounceMs),
      _flushPendingStatusLoad,
    );
  }

  /// 대기 중인 전화번호들의 상태를 배치로 로드
  Future<void> _flushPendingStatusLoad() async {
    if (_pendingPhoneNumbers.isEmpty || _isLoadingBatch) return;

    // 로드할 전화번호 복사 후 펜딩 목록 초기화
    final phoneNumbersToLoad = List<String>.from(_pendingPhoneNumbers);
    _pendingPhoneNumbers.clear();

    _isLoadingBatch = true;

    // 로딩 중 상태 표시
    if (mounted) {
      setState(() {
        for (final phone in phoneNumbersToLoad) {
          _friendshipStatuses[phone] = 'loading';
        }
      });
    }

    try {
      // 현재 사용자 ID 가져오기
      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final currentUserId = userController.currentUser?.id;
      if (currentUserId == null) {
        debugPrint('로그인된 사용자가 없습니다.');
        _isLoadingBatch = false;
        return;
      }

      // API로 친구 관계 확인 (배치)
      final friendController = Provider.of<FriendController>(
        context,
        listen: false,
      );
      final relations = await friendController.checkFriendRelations(
        userId: currentUserId,
        phoneNumbers: phoneNumbersToLoad,
      );

      // 결과를 Map에 저장
      if (mounted) {
        setState(() {
          // 응답에 포함된 전화번호 처리 (FriendCheck 모델 사용)
          for (final relation in relations) {
            _friendshipStatuses[relation.phoneNumber] = relation.statusString;
          }

          // 응답에 없는 전화번호는 'none' 처리
          final respondedPhones = relations.map((r) => r.phoneNumber).toSet();
          for (final phone in phoneNumbersToLoad) {
            if (!respondedPhones.contains(phone)) {
              _friendshipStatuses[phone] = 'none';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('친구 관계 확인 실패: $e');
      // 실패 시 'none'으로 설정
      if (mounted) {
        setState(() {
          for (final phone in phoneNumbersToLoad) {
            if (_friendshipStatuses[phone] == 'loading') {
              _friendshipStatuses[phone] = 'none';
            }
          }
        });
      }
    } finally {
      _isLoadingBatch = false;

      // 로드 중 새로 추가된 요청이 있으면 다시 처리
      if (_pendingPhoneNumbers.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(
          Duration(milliseconds: _batchDebounceMs),
          _flushPendingStatusLoad,
        );
      }
    }
  }

  /// 전화번호 정규화 (공백, 하이픈 제거)
  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// 연락처의 전화번호로 상태 조회 (lazy loading 트리거)
  String _getStatusForContact(Contact contact) {
    if (contact.phones.isEmpty) return 'none';
    final normalizedPhone = _normalizePhoneNumber(contact.phones.first.number);

    // 상태가 없으면 로드 요청
    if (!_friendshipStatuses.containsKey(normalizedPhone)) {
      _requestStatusLoad(normalizedPhone);
      return 'loading';
    }

    return _friendshipStatuses[normalizedPhone] ?? 'none';
  }

  void _refreshFriendshipStatuses() {
    if (mounted) {
      setState(() {
        _friendshipStatuses.clear();
        _pendingPhoneNumbers.clear();
      });
      // 다음 빌드에서 lazy loading이 다시 트리거됨
    }
  }

  /// 친구 추가 처리 (API 사용)
  ///
  /// FriendController.addFriend를 호출하여 친구 추가 요청을 보냅니다.
  /// - 성공 시: 친구 요청이 전송됨 (status: PENDING)
  /// - 실패 시 (null 반환): 상대방이 SOI 사용자가 아님 → SMS로 앱 설치 안내
  Future<void> _handleAddFriend(Contact contact) async {
    // 1. 전화번호 추출
    final phoneNumber = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : null;
    if (phoneNumber == null) {
      debugPrint('전화번호가 없는 연락처입니다.');
      return;
    }

    // 2. 현재 사용자 ID 가져오기
    final userController = Provider.of<UserController>(context, listen: false);
    final currentUserId = userController.currentUser?.id;
    if (currentUserId == null) {
      debugPrint('로그인된 사용자가 없습니다.');
      return;
    }

    // 3. FriendController.addFriend 호출
    final friendController = Provider.of<FriendController>(
      context,
      listen: false,
    );
    final result = await friendController.addFriend(
      requesterId: currentUserId,
      receiverPhoneNum: phoneNumber,
    );

    // 4. 결과 처리
    if (result == null) {
      // 상대방이 SOI 사용자가 아님 → SMS로 앱 설치 안내
      await _sendAppInviteSms(contact, phoneNumber);
    } else {
      // 친구 요청 성공
      debugPrint('친구 요청 성공: ${result.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'friends.suggest.request_sent',
                context: context,
                namedArgs: {'name': contact.displayName},
              ),
            ),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }

    // 5. 상태 새로고침
    _refreshFriendshipStatuses();
  }

  /// SMS로 앱 설치 안내 전송
  Future<void> _sendAppInviteSms(Contact contact, String phoneNumber) async {
    const appInstallLink = 'https://soi-sns.web.app';
    final userController = Provider.of<UserController>(context, listen: false);
    final user = userController.currentUser;
    final link = user == null
        ? appInstallLink
        : Uri.parse(appInstallLink).replace(
            queryParameters: {
              'refUserId': user.id.toString(),
              'refNickname': user.userId,
            },
          ).toString();
    final message = tr(
      'friends.suggest.sms_message',
      context: context,
      namedArgs: {'link': link},
    );

    // SMS URI 직접 구성 (queryParameters 사용 시 +로 인코딩되는 문제 방지)
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:$phoneNumber?body=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'friends.suggest.invite_sms_sent',
                  context: context,
                  namedArgs: {'name': contact.displayName},
                ),
              ),
              backgroundColor: const Color(0xFF5A5A5A),
            ),
          );
        }
      } else {
        debugPrint('SMS 앱을 열 수 없습니다.');
      }
    } catch (e) {
      debugPrint('SMS 전송 실패: $e');
    }
  }

  @override
  void didUpdateWidget(FriendSuggestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contacts != widget.contacts) {
      // 연락처가 변경되면 캐시 초기화 (lazy loading이 다시 트리거됨)
      setState(() {
        _friendshipStatuses.clear();
        _pendingPhoneNumbers.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactController>(
      builder: (context, contactController, child) {
        return SizedBox(
          width: 354.w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildContent(context, contactController),
          ),
        );
      },
    );
  }

  // 친구 추가, 요청됨, 추가됨을 파라미터에 따라서 다르게 표시하는 버튼
  Widget? _buildFriendButton(Contact contact) {
    final status = _getStatusForContact(contact);

    switch (status) {
      case 'loading':
        // 로딩 중 표시
        return SizedBox(
          width: 20.w,
          height: 20.h,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: const Color(0xff666666),
          ),
        );
      case 'pending':
        return _buildButton(
          text: tr('friends.suggest.pending', context: context),
          isEnabled: false,
          backgroundColor: const Color(0xff666666),
          textColor: const Color(0xffd9d9d9),
          onPressed: null,
        );
      case 'accepted':
        // 친구로 추가되면 목록에 표시하지 않음. 버튼은 필요없음.
        return null;
      case 'blocked':
        // 차단된 사용자도 목록에 표시하지 않음
        return null;
      case 'none':
      default:
        return _buildButton(
          text: tr('friends.suggest.add', context: context),
          isEnabled: true,
          backgroundColor: const Color(0xfff9f9f9),
          textColor: const Color(0xff1c1c1c),
          onPressed: () async {
            await _handleAddFriend(contact);
          },
        );
    }
  }

  // 버튼을 만드는 공통 위젯 함수
  Widget _buildButton({
    required String text,
    required bool isEnabled,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(backgroundColor),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        alignment: Alignment.center,
      ),
      clipBehavior: Clip.none,
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.visible,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ContactController contactController,
  ) {
    // 초기화 진행 중일 때
    if (widget.isInitializing) {
      return Container(
        padding: EdgeInsets.all(40.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24.w,
              height: 24.h,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xfff9f9f9),
              ),
            ),
            SizedBox(height: (16).h),
            Text(
              tr('friends.suggest.loading', context: context),
              style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    // 연락처 동기화가 활성화되어 있고 연락처가 있는 경우
    if (contactController.contactSyncEnabled && widget.contacts.isNotEmpty) {
      // 친구로 추가되었거나 차단된 사용자 제외 필터링
      // 로딩 중('loading')과 상태 없음('none')은 표시
      final filteredContacts = widget.contacts.where((contact) {
        final status = _getStatusForContact(contact);
        return status != 'accepted' &&
            status != 'blocked'; // 친구/차단 상태가 아닌 연락처만 표시
      }).toList();

      // 필터링 후 연락처가 없으면 메시지 표시
      if (filteredContacts.isEmpty) {
        return Container(
          padding: EdgeInsets.all(20.sp),
          child: Center(
            child: Text(
              tr('friends.suggest.empty', context: context),
              style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
            ),
          ),
        );
      }

      return Column(
        children: filteredContacts.map((contact) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xff323232),
              child: Text(
                contact.displayName.isNotEmpty
                    ? contact.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: const Color(0xfff9f9f9),
                  fontSize: (16).sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(
              contact.displayName.isNotEmpty
                  ? contact.displayName
                  : tr('friends.suggest.no_name', context: context),
              style: TextStyle(
                color: const Color(0xFFD9D9D9),
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
              ),
            ),
            subtitle: () {
              try {
                final phones = contact.phones;
                return phones.isNotEmpty
                    ? Text(
                        phones.first.number,
                        style: TextStyle(
                          color: const Color(0xFFD9D9D9),
                          fontSize: 10,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w300,
                        ),
                      )
                    : null;
              } catch (e) {
                return null;
              }
            }(),
            trailing: SizedBox(
              width: 84.w,
              height: 29.h,
              child: _buildFriendButton(contact),
            ),
          );
        }).toList(),
      );
    }

    // 기본 상태 (연락처 동기화 비활성화 또는 연락처 없음)
    return Container(
      padding: EdgeInsets.all(20.sp),
      child: Center(
        child: Text(
          contactController.contactSyncEnabled
              ? tr('friends.suggest.no_contacts', context: context)
              : tr('friends.suggest.enable_sync', context: context),
          style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
        ),
      ),
    );
  }
}
