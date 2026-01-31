import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:soi/api/controller/contact_controller.dart';
import 'widgets/friend_request_card.dart';
import 'widgets/friend_suggest_card.dart';

class FriendRequestScreen extends StatefulWidget {
  const FriendRequestScreen({super.key});

  @override
  State<FriendRequestScreen> createState() => _FriendRequestScreenState();
}

class _FriendRequestScreenState extends State<FriendRequestScreen> {
  List<Contact> _contacts = [];
  bool _isInitializing = false;
  bool _hasInitialized = false;
  ContactController? _contactController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContacts();
      _resumeSyncIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contactController ??= Provider.of<ContactController>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    _pauseSyncIfNeededAsync();
    super.dispose();
  }

  void _resumeSyncIfNeeded() {
    _contactController?.resumeSync();
  }

  void _pauseSyncIfNeededAsync() {
    if (_contactController == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contactController?.pauseSync();
    });
  }

  Future<void> _initializeContacts() async {
    if (_hasInitialized || _contactController == null) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      final result =
          await _contactController!.initializeContactPermission();
      if (result.isEnabled &&
          mounted &&
          _contactController!.isActivelySyncing) {
        _contacts = await _contactController!.getContacts(
          forceRefresh: false,
        );
      }
    } catch (_) {
      // 연락처 초기화 실패 시에도 화면은 유지
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFFF8F8F8)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '친구 요청',
          style: TextStyle(
            color: Color(0xFFF8F8F8),
            fontSize: 20,
            fontFamily: 'Pretendard Variable',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: FriendRequestCard(scale: 1.0)),
            SizedBox(height: 20.h),
            Text(
              '친구 추천',
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
              ),
            ),
            SizedBox(height: 10.h),
            Center(
              child: FriendSuggestCard(
                scale: 1.0,
                isInitializing: _isInitializing,
                contacts: _contacts,
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
