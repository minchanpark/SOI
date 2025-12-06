import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soi/utils/instagram_share_channel.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteLinkCard extends StatelessWidget {
  final double scale;

  const InviteLinkCard({super.key, required this.scale});

  static const String _inviteLink = 'https://soi-sns.web.app';
  static const String _inviteMessage = 'SOI 앱에서 친구가 되어주세요!\n\n$_inviteLink';

  /// 시스템 공유 시트용 파라미터 생성
  ShareParams _buildShareParams() {
    return ShareParams(text: _inviteMessage, subject: 'SOI 친구 초대');
  }

  /// 클립보드에 링크 복사
  void _copyLink(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('링크가 복사되었습니다'),
        backgroundColor: Color(0xff404040),
      ),
    );
  }

  /// 시스템 공유 시트 열기
  Future<void> _shareLink(BuildContext context) async {
    try {
      await SharePlus.instance.share(_buildShareParams());
    } catch (e) {
      debugPrint('공유 실패: $e');
    }
  }

  /// 인스타그램 DM 공유 화면 열기 (네이티브 플러그인 사용)
  Future<void> _shareToInstagram(BuildContext context) async {
    // 먼저 링크를 클립보드에 복사
    await Clipboard.setData(const ClipboardData(text: _inviteMessage));

    try {
      // 인스타그램 설치 확인
      final isInstalled = await InstagramShareChannel.isInstagramInstalled();

      if (isInstalled) {
        // 네이티브 채널로 인스타그램 DM 공유 화면 열기
        await InstagramShareChannel.shareToInstagramDirect(_inviteMessage);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('인스타그램이 설치되어 있지 않습니다'),
              backgroundColor: Color(0xff404040),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('인스타그램 공유 실패: $e');
      // 실패 시 시스템 공유 시트로 대체
      try {
        await SharePlus.instance.share(_buildShareParams());
      } catch (shareError) {
        debugPrint('시스템 공유도 실패: $shareError');
      }
    }
  }

  /// SMS 메시지 전송
  Future<void> _sendSms(BuildContext context) async {
    final encodedMessage = Uri.encodeComponent(_inviteMessage);
    final uri = Uri.parse('sms:?body=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('메시지 앱을 열 수 없습니다'),
              backgroundColor: Color(0xff404040),
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
    // FeedTemplate 생성
    final template = FeedTemplate(
      content: Content(
        title: 'SOI 앱에서 친구가 되어주세요!',
        description: '사진과 음성으로 소통하는 새로운 SNS',
        imageUrl: Uri.parse('https://soi-sns.web.app/assets/SOI_logo.png'),
        link: Link(
          webUrl: Uri.parse(_inviteLink),
          mobileWebUrl: Uri.parse(_inviteLink),
        ),
      ),
      buttons: [
        Button(
          title: 'SOI 시작하기',
          link: Link(
            webUrl: Uri.parse(_inviteLink),
            mobileWebUrl: Uri.parse(_inviteLink),
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
            const SnackBar(
              content: Text('카카오톡 공유에 실패했습니다'),
              backgroundColor: Color(0xff404040),
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
            const SnackBar(
              content: Text('카카오톡이 설치되어 있지 않습니다'),
              backgroundColor: Color(0xff404040),
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
                '링크 복사',
                'assets/link.png',
                () => _copyLink(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '공유',
                'assets/share.png',
                () => _shareLink(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '카카오톡',
                'assets/kakao.png',
                () => _shareToKakao(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '인스타그램',
                'assets/insta.png',
                () => _shareToInstagram(context),
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '메세지',
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
