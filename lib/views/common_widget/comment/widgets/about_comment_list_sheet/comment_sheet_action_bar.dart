import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../features/tagging_soi/tagging_soi.dart';

/// 댓글 시트 입력바의 액션 버튼과 텍스트 입력 필드를 담당하는 위젯입니다.
/// - 댓글 시트의 하단에 고정되어, 사용자가 댓글을 작성하거나 미디어 첨부 등의 액션을 수행할 수 있도록 합니다.
///
/// fields:
/// - [isTextInputMode]: 현재 텍스트 입력 모드인지 여부입니다.
///   - true면 텍스트 입력 필드가 표시되고,
///   - false면 액션 버튼이 표시됩니다.
/// - [textInputSession]: 텍스트 입력 세션을 구분하는 정수입니다. 댓글마다 고유한 세션이 할당되어야 합니다.
/// - [replyTargetId]: 현재 입력 중인 댓글의 대상 댓글 ID입니다. 새 댓글 작성 시 null, 대댓글 작성 시 부모 댓글 ID가 할당됩니다.
/// - [pendingInitialReplyText]: 현재 입력 중인 텍스트 입력 필드에 초기값으로 설정할 문자열입니다. 대댓글 작성 시 부모 댓글의 @멘션이 할당됩니다.
/// - [isReplyDraftArmed]: 현재 대댓글 작성이 활성화되어 있는지 여부입니다. true면 텍스트 입력 필드가 활성화되고, false면 비활성화됩니다.
/// - [replyDraftController]: 대댓글 작성 텍스트 입력 필드의 TextEditingController입니다.
/// - [replyDraftFocusNode]: 대댓글 작성 텍스트 입력 필드의 FocusNode입니다.
/// - [onReplyDraftChanged]: 대댓글 작성 텍스트 입력 필드의 내용이 변경될 때 호출되는 콜백입니다. 변경된 텍스트가 인자로 전달됩니다.
/// - [onCameraPressed]: 카메라 버튼이 눌렸을 때 호출되는 콜백입니다.
/// - [onMicPressed]: 마이크 버튼이 눌렸을 때 호출되는 콜백입니다.
/// - [onSubmitText]: 텍스트 입력이 제출되었을 때 호출되는 콜백입니다. 제출된 텍스트가 인자로 전달됩니다.
/// - [onEditingCancelled]: 텍스트 입력이 취소되었을 때 호출되는 콜백입니다.
class ApiCommentSheetActionBar extends StatelessWidget {
  const ApiCommentSheetActionBar({
    super.key,
    required this.isTextInputMode,
    required this.textInputSession,
    required this.replyTargetId,
    required this.replyTargetName,
    required this.pendingInitialReplyText,
    required this.isReplyDraftArmed,
    required this.onCenterTap,
    required this.onCameraPressed,
    required this.onMicPressed,
    required this.onSubmitText,
    required this.onEditingCancelled,
    required this.onClearReplyTap,
  });

  final bool isTextInputMode;
  final int textInputSession;
  final int? replyTargetId;
  final String? replyTargetName;
  final String pendingInitialReplyText;
  final bool isReplyDraftArmed;
  final VoidCallback onCenterTap;
  final VoidCallback onCameraPressed;
  final VoidCallback onMicPressed;
  final Future<void> Function(String text) onSubmitText;
  final VoidCallback onEditingCancelled;
  final VoidCallback onClearReplyTap;

  /// reply 대상 이름을 정리해 배너와 placeholder에서 재사용할 수 있게 합니다.
  String? get _trimmedReplyTargetName {
    final normalizedName = replyTargetName?.trim();
    if (normalizedName == null || normalizedName.isEmpty) {
      return null;
    }
    return normalizedName;
  }

  /// 하단 입력 바가 현재 reply 흐름인지 여부를 ID 기준으로 판별합니다.
  bool get _hasReplyTarget => replyTargetId != null;

  /// reply 상태 배너는 현재 누구에게 답글을 남기는지 한 줄로 요약합니다.
  String _resolvedReplyContextLabel(BuildContext context) {
    final normalizedName = _trimmedReplyTargetName;
    if (normalizedName == null) {
      return tr('comments.replying');
    }
    return tr('comments.replying_to', namedArgs: {'name': normalizedName});
  }

  /// 기본 액션 바 문구는 일반 댓글과 reply 모드를 구분해 진입 의도를 드러냅니다.
  String _resolvedComposerPrompt(BuildContext context) {
    if (_hasReplyTarget) {
      return tr('comments.add_reply');
    }
    return tr('comments.add_comment');
  }

  /// 텍스트 입력 힌트는 reply 대상이 있으면 이름까지 포함해 현재 문맥을 안내합니다.
  String _resolvedTextInputHint(BuildContext context) {
    final normalizedName = _trimmedReplyTargetName;
    if (!_hasReplyTarget || normalizedName == null) {
      return _resolvedComposerPrompt(context);
    }
    return tr('comments.reply_to', namedArgs: {'name': normalizedName});
  }

  /// reply 배너는 분리된 입력 바에서도 답글 대상과 취소 액션을 한눈에 보여줍니다.
  Widget _buildReplyContextBanner(BuildContext context) {
    final bannerLabel = _resolvedReplyContextLabel(context);
    final canClearReply = !isTextInputMode;

    return Container(
      width: 353,
      padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 7.sp),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33F8F8F8), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: 14.sp,
            color: const Color(0xFFF8F8F8),
          ),
          SizedBox(width: 8.sp),
          Expanded(
            child: Text(
              bannerLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 12.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (canClearReply)
            IconButton(
              onPressed: onClearReplyTap,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(width: 24.sp, height: 24.sp),
              splashRadius: 14.sp,
              tooltip: tr('common.cancel'),
              icon: Icon(
                Icons.close_rounded,
                size: 16.sp,
                color: const Color(0xFFB9B9B9),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasReplyTarget) ...[
              _buildReplyContextBanner(context),
              SizedBox(height: 8.sp),
            ],
            SizedBox(
              height: 52.sp,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: isTextInputMode
                    ?
                      // 텍스트 입력 모드일 때는 태깅 패키지의 공용 입력창을 표시합니다.
                      KeyedSubtree(
                        key: ValueKey(
                          'reply_input_${replyTargetId ?? 0}_$textInputSession',
                        ),
                        child: SoiTagTextInputWidget(
                          initialText: pendingInitialReplyText,
                          onSubmitText: onSubmitText,
                          onEditingCancelled: onEditingCancelled,
                          hintText: _resolvedTextInputHint(context),
                        ),
                      )
                    :
                      // 액션 버튼 모드일 때는 기존 댓글 바 모양을 유지하되, 중앙 탭으로 텍스트 입력 모드에 진입합니다.
                      KeyedSubtree(
                        key: ValueKey(
                          'comment_action_bar_${replyTargetId ?? 0}',
                        ),
                        child: Opacity(
                          opacity: isReplyDraftArmed ? 1 : 0.45,
                          child: Container(
                            width: 353,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(52),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 5),
                                IconButton(
                                  onPressed: isReplyDraftArmed
                                      ? onCameraPressed
                                      : null,
                                  padding: EdgeInsets.zero,
                                  icon: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const ShapeDecoration(
                                      color: Color(0xFF323232),
                                      shape: CircleBorder(),
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/camera_mode.png',
                                        width: (17.78).sp,
                                        height: 16.sp,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: isReplyDraftArmed
                                        ? onCenterTap
                                        : null,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _resolvedComposerPrompt(context),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFF8F8F8),
                                          fontSize: 16,
                                          fontFamily: 'Pretendard Variable',
                                          fontWeight: FontWeight.w200,
                                          letterSpacing: -1.14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: isReplyDraftArmed
                                      ? onMicPressed
                                      : null,
                                  padding: EdgeInsets.zero,
                                  icon: Image.asset(
                                    'assets/record_icon.png',
                                    width: 36,
                                    height: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
