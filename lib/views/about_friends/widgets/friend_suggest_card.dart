import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/contact_controller.dart';
import '../../../api_firebase/services/friend_request_service.dart';
import '../../../api_firebase/repositories/friend_request_repository.dart';
import '../../../api_firebase/repositories/friend_repository.dart';
import '../../../api_firebase/repositories/user_search_repository.dart';

class FriendSuggestCard extends StatefulWidget {
  final double scale;
  final bool isInitializing;
  final List<Contact> contacts;
  final Function(Contact) onAddFriend;

  const FriendSuggestCard({
    super.key,
    required this.scale,
    required this.isInitializing,
    required this.contacts,
    required this.onAddFriend,
  });

  @override
  State<FriendSuggestCard> createState() => _FriendSuggestCardState();
}

class _FriendSuggestCardState extends State<FriendSuggestCard> {
  late final FriendRequestService _friendRequestService;
  final Map<String, String> _friendshipStatuses = {};
  bool _isLoadingStatuses = false;
  StreamSubscription? _friendRequestSubscription;
  StreamSubscription? _sentRequestSubscription;

  @override
  void initState() {
    super.initState();
    _friendRequestService = FriendRequestService(
      friendRequestRepository: FriendRequestRepository(),
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    _loadFriendshipStatuses();
    _listenToFriendRequestChanges();
  }

  void _listenToFriendRequestChanges() {
    // 받은 요청 변화 감지 (친구 수락 시)
    _friendRequestSubscription = _friendRequestService
        .getReceivedRequests()
        .listen((_) {
          _refreshFriendshipStatuses();
        });

    // 보낸 요청 변화 감지 (요청 전송, 취소 시)
    _sentRequestSubscription = _friendRequestService.getSentRequests().listen((
      _,
    ) {
      _refreshFriendshipStatuses();
    });
  }

  void _refreshFriendshipStatuses() {
    if (mounted) {
      _friendshipStatuses.clear();
      _loadFriendshipStatuses();
    }
  }

  @override
  void dispose() {
    _friendRequestSubscription?.cancel();
    _sentRequestSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFriendshipStatuses() async {
    if (widget.contacts.isEmpty || _isLoadingStatuses) return;

    setState(() {
      _isLoadingStatuses = true;
    });

    for (final contact in widget.contacts) {
      try {
        final phoneNumbers = contact.phones
            .map((phone) => phone.number)
            .toList();
        if (phoneNumbers.isNotEmpty) {
          // 전화번호로 사용자 검색
          final userSearchRepo = UserSearchRepository();
          final user = await userSearchRepo.searchUserByPhoneNumber(
            phoneNumbers.first,
          );

          if (user != null) {
            // 친구 상태 확인
            final status = await _friendRequestService.getFriendshipStatus(
              user.uid,
            );
            if (mounted) {
              setState(() {
                // contact의 displayName을 키로 사용
                _friendshipStatuses[contact.displayName] = status;
              });
            }
          }
        }
      } catch (e) {
        // 오류 발생 시 무시
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingStatuses = false;
      });
    }
  }

  @override
  void didUpdateWidget(FriendSuggestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contacts != widget.contacts) {
      _friendshipStatuses.clear();
      _loadFriendshipStatuses();
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
    final status = _friendshipStatuses[contact.displayName] ?? 'none';

    switch (status) {
      case 'sent':
        return _buildButton(
          text: '요청됨',
          isEnabled: false,
          backgroundColor: const Color(0xff666666),
          textColor: const Color(0xffd9d9d9),
          onPressed: null,
        );
      case 'friends':
        // 친구로 추가되면 목록에 표시하지 않음. 버튼은 필요없음.
        return null;

      case 'none':
        return _buildButton(
          text: '친구 추가',
          isEnabled: true,
          backgroundColor: const Color(0xfff9f9f9),
          textColor: const Color(0xff1c1c1c),
          onPressed: () async {
            widget.onAddFriend(contact);
            // 친구 요청 후 잠깐 기다렸다가 상태 새로고침
            await Future.delayed(const Duration(milliseconds: 100));
            _refreshFriendshipStatuses();
          },
        );
    }
    return null;
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
              '연락처에서 친구를 찾는 중...',
              style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    // 연락처 동기화가 활성화되어 있고 연락처가 있는 경우
    if (contactController.contactSyncEnabled && widget.contacts.isNotEmpty) {
      // 친구로 추가된 사용자 제외 필터링
      final filteredContacts = widget.contacts.where((contact) {
        final status = _friendshipStatuses[contact.displayName] ?? 'none';
        return status != 'friends'; // 친구 상태가 아닌 연락처만 표시
      }).toList();

      // 필터링 후 연락처가 없으면 메시지 표시
      if (filteredContacts.isEmpty) {
        return Container(
          padding: EdgeInsets.all(20.sp),
          child: Center(
            child: Text(
              '추천할 친구가 없습니다',
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
              contact.displayName.isNotEmpty ? contact.displayName : '이름 없음',
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
              ? '연락처에서 친구를 찾을 수 없습니다'
              : '연락처 동기화를 활성화해주세요',
          style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
        ),
      ),
    );
  }
}
