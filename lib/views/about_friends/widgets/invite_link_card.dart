import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/utils/instagram_share_channel.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteLinkCard extends StatelessWidget {
  final double scale;

  const InviteLinkCard({super.key, required this.scale});

  static const String _inviteLink = 'https://soi-sns.web.app';

  String _buildInviteLinkWithUser(User? user) {
    if (user == null) return _inviteLink;
    final uri = Uri.parse(_inviteLink);
    return uri
        .replace(
          queryParameters: {
            'refUserId': user.id.toString(),
            'refNickname': user.userId,
          },
        )
        .toString();
  }

  /// 시스템 공유 시트용 파라미터 생성
  ShareParams _buildShareParams(BuildContext context, String link) {
    return ShareParams(
      text: tr(
        'friends.invite.share_text',
        context: context,
        namedArgs: {'link': link},
      ),
      subject: tr('friends.invite.share_subject', context: context),
    );
  }

  String _buildInviteLink(BuildContext context) {
    final user = Provider.of<UserController>(context, listen: false).currentUser;
    return _buildInviteLinkWithUser(user);
  }

  /// 클립보드에 링크 복사
  void _copyLink(BuildContext context) {
    final link = _buildInviteLink(context);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('friends.invite.link_copied', context: context)),
        backgroundColor: const Color(0xff404040),
      ),
    );
  }

  /// 시스템 공유 시트 열기
  Future<void> _shareLink(BuildContext context) async {
    try {
      final link = _buildInviteLink(context);
      await SharePlus.instance.share(_buildShareParams(context, link));
    } catch (e) {
      debugPrint('공유 실패: $e');
    }
  }

  /// 인스타그램 DM 공유 화면 열기 (네이티브 플러그인 사용)
  Future<void> _shareToInstagram(BuildContext context) async {
    final link = _buildInviteLink(context);
    final message = tr(
      'friends.invite.share_text',
      context: context,
      namedArgs: {'link': link},
    );
    // 먼저 링크를 클립보드에 복사
    await Clipboard.setData(ClipboardData(text: message));

    try {
      // 인스타그램 설치 확인
      final isInstalled = await InstagramShareChannel.isInstagramInstalled();

      if (isInstalled) {
        // 네이티브 채널로 인스타그램 DM 공유 화면 열기
        await InstagramShareChannel.shareToInstagramDirect(message);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('friends.invite.instagram_missing', context: context),
              ),
              backgroundColor: const Color(0xff404040),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('인스타그램 공유 실패: $e');
      // 실패 시 시스템 공유 시트로 대체
      try {
        await SharePlus.instance.share(_buildShareParams(context, link));
      } catch (shareError) {
        debugPrint('시스템 공유도 실패: $shareError');
      }
    }
  }

  /// SMS 메시지 전송
  Future<void> _sendSms(BuildContext context) async {
    final user = Provider.of<UserController>(
      context,
      listen: false,
    ).currentUser;
    final link = _buildInviteLinkWithUser(user);
    final message = tr(
      'friends.invite.share_text',
      context: context,
      namedArgs: {'link': link},
    );
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:?body=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('friends.invite.sms_unavailable', context: context)),
              backgroundColor: const Color(0xff404040),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('SMS 전송 실패: $e');
    }
  }

  /// 카카오톡으로 공유
  Future<void> _shareToKakao(BuildContext context) async {
    final link = _buildInviteLink(context);
    final linkUri = Uri.parse(link);
    final executionParams = <String, String>{};
    final refUserId = linkUri.queryParameters['refUserId'];
    final refNickname = linkUri.queryParameters['refNickname'];
    if (refUserId != null && refUserId.isNotEmpty) {
      executionParams['refUserId'] = refUserId;
    }
    if (refNickname != null && refNickname.isNotEmpty) {
      executionParams['refNickname'] = refNickname;
    }
    // FeedTemplate 생성
    final template = FeedTemplate(
      content: Content(
        title: tr('friends.invite.kakao_title', context: context),
        description: tr('friends.invite.kakao_description', context: context),
        imageUrl: Uri.parse('https://soi-sns.web.app/assets/SOI_logo.png'),
        link: Link(
          webUrl: linkUri,
          mobileWebUrl: linkUri,
          androidExecutionParams: executionParams.isEmpty
              ? null
              : executionParams,
          iosExecutionParams: executionParams.isEmpty ? null : executionParams,
        ),
      ),
      buttons: [
        Button(
          title: tr('friends.invite.kakao_button', context: context),
          link: Link(
            webUrl: linkUri,
            mobileWebUrl: linkUri,
            androidExecutionParams: executionParams.isEmpty
                ? null
                : executionParams,
            iosExecutionParams:
                executionParams.isEmpty ? null : executionParams,
          ),
        ),
      ],
    );

    // 카카오톡 설치 여부 확인
    if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
      try {
        final uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
        debugPrint('카카오톡 공유 성공');
      } catch (e) {
        debugPrint('카카오톡 공유 실패: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('friends.invite.kakao_failed', context: context)),
              backgroundColor: const Color(0xff404040),
            ),
          );
        }
      }
    } else {
      // 카카오톡 미설치 시 웹 공유로 대체
      try {
        final shareUrl = await WebSharerClient.instance.makeDefaultUrl(
          template: template,
        );
        await launchUrl(shareUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('웹 공유 실패: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('friends.invite.kakao_missing', context: context)),
              backgroundColor: const Color(0xff404040),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 354,
      height: 110,
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: const Color(0xff1c1c1c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 18.w),
              _buildLinkCardContent(
                context,
                scale,
                tr('friends.invite.copy', context: context),
                'assets/link.png',
                () => _copyLink(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                tr('friends.invite.share', context: context),
                'assets/share.png',
                () => _shareLink(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                tr('friends.invite.kakao', context: context),
                'assets/kakao.png',
                () => _shareToKakao(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                tr('friends.invite.instagram', context: context),
                'assets/insta.png',
                () => _shareToInstagram(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                tr('friends.invite.message', context: context),
                'assets/message.png',
                () => _sendSms(context),
              ),
              SizedBox(width: (18).w),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCardContent(
    BuildContext context,
    double scale,
    String title,
    String imagePath,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Image.asset(imagePath, width: (51.76).w, height: (51.76).w),
          ),
          SizedBox(height: (7.24).h),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xfff9f9f9),
              fontSize: (12).sp,
              fontWeight: FontWeight.w800,
              fontFamily: "Pretendard",
            ),
          ),
        ],
      ),
    );
  }
}
