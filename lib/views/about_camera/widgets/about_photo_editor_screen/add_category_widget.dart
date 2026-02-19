import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:soi/api/models/selected_friend_model.dart';
import '../../../../utils/snackbar_utils.dart';
import '../../../about_archiving/widgets/overlapping_profiles_widget.dart';
import '../../../about_friends/friend_list_add_screen.dart';

// 카테고리 추가 UI 위젯
// 새로운 카테고리를 생성하는 인터페이스를 제공합니다.
class AddCategoryWidget extends StatefulWidget {
  final TextEditingController textController;
  final ScrollController scrollController;
  final VoidCallback onBackPressed;
  final Function(List<SelectedFriendModel>) onSavePressed;
  final FocusNode focusNode;

  const AddCategoryWidget({
    super.key,
    required this.textController,
    required this.scrollController,
    required this.onBackPressed,
    required this.onSavePressed,
    required this.focusNode,
  });

  @override
  State<AddCategoryWidget> createState() => _AddCategoryWidgetState();
}

class _AddCategoryWidgetState extends State<AddCategoryWidget> {
  // 선택된 친구들 상태 관리
  List<SelectedFriendModel> _selectedFriends = [];

  void _handleSavePressed() async {
    // 카테고리 이름이 입력되었는지 확인
    if (widget.textController.text.trim().isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        tr('archive.create_category_name_required', context: context),
      );
      return;
    }

    // 저장 콜백 호출
    widget.onSavePressed(_selectedFriends);
  }

  Future<void> _handleAddFriends() async {
    // Navigator.push로 결과값 받기
    final result = await Navigator.push<List<SelectedFriendModel>>(
      context,
      MaterialPageRoute(
        builder: (context) => FriendListAddScreen(
          allowDeselection: true,
          categoryMemberUids: _selectedFriends
              .map((friend) => friend.uid)
              .toList(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedFriends = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF171717),
      child: Column(
        children: [
          // 네비게이션 헤더
          Container(
            padding: EdgeInsets.only(left: 12.w, right: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 뒤로가기 버튼
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFFD9D9D9),
                    size: 20.sp,
                  ),
                  onPressed: widget.onBackPressed,
                ),

                // "새 카테고리 만들기" 텍스트
                Text(
                  'archive.create_category_title',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                    letterSpacing: -0.4,
                  ),
                ).tr(),

                // 저장 버튼 (터치 영역 확장)
                GestureDetector(
                  behavior: HitTestBehavior.opaque, // 투명 영역도 터치 감지
                  onTap: _handleSavePressed,
                  child: Container(
                    width: 51.w,
                    height: 25.h,
                    decoration: BoxDecoration(
                      color: Color(0xFF323232),
                      borderRadius: BorderRadius.circular(16.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'common.save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                        letterSpacing: -0.4,
                      ),
                    ).tr(),
                  ),
                ),
              ],
            ),
          ),

          // 구분선
          Divider(height: 1, color: Color(0xFF323232)),

          // 메인 컨텐츠 영역 (스크롤 가능하도록 Expanded + SingleChildScrollView)
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedFriends.isEmpty)
                      // 친구 추가하기 버튼
                      GestureDetector(
                        onTap: _handleAddFriends,
                        child: Container(
                          width: 117.w,
                          height: 35.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF323232),
                            borderRadius: BorderRadius.circular(16.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/category_add.png',
                                width: 17.sp,
                                height: 17.sp,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'category.members.add_friend_action',
                                style: TextStyle(
                                  color: const Color(0xFFE2E2E2),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Pretendard',
                                  letterSpacing: -0.4,
                                ),
                              ).tr(),
                            ],
                          ),
                        ),
                      ),

                    // 선택된 친구들 표시
                    if (_selectedFriends.isNotEmpty) ...[
                      OverlappingProfilesWidget(
                        selectedFriends: _selectedFriends,
                        onAddPressed: _handleAddFriends,
                        showAddButton: true, // + 버튼 표시
                      ),
                    ],

                    // 텍스트 입력 영역
                    TextField(
                      controller: widget.textController,
                      cursorColor: Color(0xFFF3F3F3),
                      focusNode: widget.focusNode,
                      style: TextStyle(
                        color: const Color(0xFFf4f4f4),
                        fontSize: 15.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.40,
                      ),
                      decoration: InputDecoration(
                        border: UnderlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                        hintText: tr(
                          'archive.create_category_name_hint',
                          context: context,
                        ),
                        hintStyle: TextStyle(
                          color: const Color(0xFFcccccc),
                          fontSize: 14.sp,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.40,
                        ),
                      ),
                      maxLength: 20,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) {
                            return null;
                          },
                    ),

                    // 글자 수 카운터
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: widget.textController,
                          builder: (context, value, child) {
                            return Text(
                              'archive.create_category_name_counter',
                              style: TextStyle(
                                color: const Color(0xFFCBCBCB),
                                fontSize: 12.sp,
                                fontFamily: 'Pretendard Variable',
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.40,
                              ),
                            ).tr(
                              namedArgs: {
                                'count': value.text.length.toString(),
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
