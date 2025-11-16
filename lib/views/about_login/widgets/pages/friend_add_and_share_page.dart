import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../api_firebase/controllers/auth_controller.dart';
import '../../../../api_firebase/controllers/contact_controller.dart';

class FriendAddAndSharePage extends StatefulWidget {
  final PageController? pageController;
  final VoidCallback? onSkip;

  const FriendAddAndSharePage({
    super.key,
    required this.pageController,
    this.onSkip,
  });

  @override
  State<FriendAddAndSharePage> createState() => _FriendAddAndSharePageState();
}

class _FriendAddAndSharePageState extends State<FriendAddAndSharePage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactController>().initialize();
    });
  }

  Future<void> _handleContactSync(ContactController controller) async {
    if (controller.isLoading) return;

    final result = await controller.initializeContactPermission();

    if (!mounted) return;

    setState(() {});

    if (result.message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ContactController, AuthController>(
      builder: (context, contactController, authController, _) {
        final bool isContactLoading = contactController.isLoading;
        final bool inviteLoading = authController.isInviteLinkLoading;
        final String? inviteLink = authController.pendingInviteLink;
        final bool canShareInvite =
            !inviteLoading && inviteLink != null && inviteLink.isNotEmpty;

        return Stack(
          children: [
            Positioned(
              top: 60.h,
              left: 20.w,
              child: IconButton(
                onPressed: () {
                  widget.pageController?.previousPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                icon: Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
            ),
            Positioned(
              top: 60.h,
              right: 20.w,
              child: TextButton(
                onPressed: widget.onSkip,
                child: Text(
                  '건너뛰기 >',
                  style: TextStyle(
                    color: const Color(0xFFCBCBCB),
                    fontSize: 16,
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '공유 링크를 통해 친구를 추가해 보세요.',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 18,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 39.h),
                  ElevatedButton(
                    onPressed: isContactLoading
                        ? null
                        : () => _handleContactSync(contactController),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        Color(0xFF303030),
                      ),
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(33.31),
                        ),
                      ),
                      overlayColor: WidgetStateProperty.all(
                        Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SizedBox(
                      width: 185.w,
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isContactLoading)
                            SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            Image.asset(
                              'assets/contact.png',
                              width: 22.5.w,
                              height: 22.5.h,
                            ),
                          SizedBox(width: 11.5.w),
                          Text(
                            '연락처 동기화',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 27.h),
                  ElevatedButton(
                    onPressed: canShareInvite
                        ? () => _shareInviteLink(authController)
                        : null,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        Color(0xFF303030),
                      ),
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(33.31),
                        ),
                      ),
                      overlayColor: WidgetStateProperty.all(
                        Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SizedBox(
                      width: 185.w,
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (inviteLoading)
                            SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            Image.asset(
                              'assets/icon_share.png',
                              width: 23.w,
                              height: 23.h,
                            ),
                          SizedBox(width: 11.5.w),
                          Text(
                            '친구 링크 공유',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareInviteLink(AuthController authController) async {
    try {
      await authController.sharePreparedInviteLink(
        originContext: context,
        message: 'SOI에서 함께 친구가 되어볼까요?',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('링크를 공유할 수 없습니다: $e')));
    }
  }
}
