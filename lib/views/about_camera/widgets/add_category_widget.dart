import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../api_firebase/models/selected_friend_model.dart';
import '../../about_archiving/widgets/overlapping_profiles_widget.dart';
import '../../about_friends/friend_list_add_screen.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '카테고리 이름을 입력해주세요.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontFamily: 'Pretendard',
            ),
          ),
          backgroundColor: Color(0xFF323232),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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

      for (final friend in _selectedFriends) {
        debugPrint('- ${friend.name} (${friend.uid})');
      }
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

                // 제목
                Text(
                  '새 카테고리 만들기',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                    letterSpacing: -0.4,
                  ),
                ),

                // 저장 버튼
                SizedBox(
                  width: 51.w,
                  height: 25.h,

                  child: ElevatedButton(
                    onPressed: _handleSavePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF323232),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.5),
                      ),
                      elevation: 0,
                      // 저장 텍스트의 위치를 조정할 때는 여기서 <--
                      padding: EdgeInsets.only(top: (2.5).h),
                    ),
                    child: Text(
                      '저장',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 구분선
          Divider(height: 1, color: Color(0xFF323232)),

          // 메인 컨텐츠 영역
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                '친구 추가하기',
                                style: TextStyle(
                                  color: const Color(0xFFE2E2E2),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Pretendard',
                                  letterSpacing: -0.4,
                                ),
                              ),
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
                    Column(
                      children: [
                        // 입력 필드
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
                            hintText: '카테고리의 이름을 입력해 주세요.',
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

                        SizedBox(height: 8.h),

                        // 글자 수 카운터
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: widget.textController,
                              builder: (context, value, child) {
                                return Text(
                                  '${value.text.length}/20자',
                                  style: TextStyle(
                                    color: const Color(0xFFCBCBCB),
                                    fontSize: 12.sp,
                                    fontFamily: 'Pretendard Variable',
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.40,
                                  ),
                                );
                              },
                            ),
                          ],
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
