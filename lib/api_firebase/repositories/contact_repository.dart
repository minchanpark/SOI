import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 연락처 데이터 접근을 담당하는 Repository
class ContactRepository {
  static const String _contactSyncKey = 'contact_sync_enabled';

  /// SharedPreferences에서 연락처 동기화 설정 로드
  Future<bool> loadContactSyncSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_contactSyncKey) ?? false;
    } catch (e) {
      debugPrint('연락처 설정 로드 실패: $e');
      return false;
    }
  }

  /// SharedPreferences에 연락처 동기화 설정 저장
  Future<void> saveContactSyncSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_contactSyncKey, value);
    } catch (e) {
      debugPrint('연락처 설정 저장 실패: $e');
    }
  }

  /// 연락처 권한 요청
  Future<bool> requestContactPermission() async {
    try {
      return await FlutterContacts.requestPermission();
    } catch (e) {
      debugPrint('연락처 권한 요청 실패: $e');
      return false;
    }
  }

  /// 연락처 목록 가져오기
  Future<List<Contact>> getContacts() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        // withProperties를 사용해서 전화번호와 이메일을 포함
        return await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );
      } else {
        throw Exception('연락처 권한이 없습니다');
      }
    } catch (e) {
      debugPrint('연락처 목록 가져오기 실패: $e');
      throw Exception('연락처 목록을 가져오는데 실패했습니다: $e');
    }
  }

  /// 특정 연락처 정보 가져오기
  Future<Contact?> getContact(String id) async {
    try {
      if (await FlutterContacts.requestPermission()) {
        return await FlutterContacts.getContact(id);
      } else {
        throw Exception('연락처 권한이 없습니다');
      }
    } catch (e) {
      debugPrint('연락처 정보 가져오기 실패: $e');
      throw Exception('연락처 정보를 가져오는데 실패했습니다: $e');
    }
  }

  /// 연락처 검색
  Future<List<Contact>> searchContacts(String query) async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );
        return contacts.where((contact) {
          final name = contact.name.first;
          final phones = contact.phones.map((p) => p.number).join(' ');
          return name.toLowerCase().contains(query.toLowerCase()) ||
              phones.contains(query);
        }).toList();
      } else {
        throw Exception('연락처 권한이 없습니다');
      }
    } catch (e) {
      debugPrint('연락처 검색 실패: $e');
      throw Exception('연락처 검색에 실패했습니다: $e');
    }
  }
}
