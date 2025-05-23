import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/theme.dart';
import '../../controllers/auth_controller.dart';

class AuthFinalScreen extends StatelessWidget {
  final String id;
  final String name;
  final String phone;
  final String birthDate;

  const AuthFinalScreen({
    super.key,
    required this.id,
    required this.name,
    required this.phone,
    required this.birthDate,
  });

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    AuthController authViewModel = Provider.of<AuthController>(
      context,
      listen: false,
    );
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/auth_final.png',
              width: (349 / 393) * screenWidth,
              height: (66 / 852) * screenHeight,
            ),
            SizedBox(height: (406 / 852) * screenHeight),
            ElevatedButton(
              onPressed: () async {
                try {
                  await authViewModel.createUserInFirestore(
                    authViewModel.currentUser!,
                    id,
                    name,
                    phone,
                    birthDate,
                  );
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home_navigation_screen',
                    (route) => false,
                  );
                } catch (e) {
                  debugPrint('Error creating user in Firestore: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff323232),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Container(
                width: (239 / 393) * screenWidth,
                height: (59 / 852) * screenHeight,
                alignment: Alignment.center,
                child: Text(
                  '내 기록 시작하기',
                  style: TextStyle(
                    color: AppTheme.lightTheme.colorScheme.secondary,
                    fontSize: (24 / 852) * screenHeight,
                    fontWeight: FontWeight.w500,
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
