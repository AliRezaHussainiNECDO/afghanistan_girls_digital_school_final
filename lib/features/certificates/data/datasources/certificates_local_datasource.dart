import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/certificate.dart';
import 'certificates_remote_datasource.dart' show CertificatesDataSource;

/// ذخیرهٔ محلی گواهی‌نامه‌ها — تا اتصال بک‌اند، منبع واحد حقیقت همین‌جاست.
/// (در فاز بک‌اند با جدول `certificates` سند SPEC بخش ۱۷.۴ جایگزین می‌شود.)
class CertificatesLocalDataSource implements CertificatesDataSource {
  static const _storageKey = 'certificates_v1';

  Future<List<Certificate>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Certificate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<Certificate> certs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(certs.map((c) => c.toJson()).toList()));
  }

  @override
  Future<List<Certificate>> getAll() async {
    final all = await _readAll();
    all.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return all;
  }

  /// گواهی‌نامه‌های یک شاگرد مشخص (برای شاگرد/والد/مدیر).
  @override
  Future<List<Certificate>> getForStudent(String studentId) async {
    final all = await getAll();
    return all.where((c) => c.studentId == studentId).toList();
  }

  /// صدور و «ارسال» گواهی‌نامهٔ جدید توسط مدیر پس از ختم صنف.
  @override
  Future<Certificate> issue({
    required String studentId,
    required String studentName,
    required int grade,
    required String yearLabel,
    required double average,
    required String honor,
  }) async {
    final now = DateTime.now();
    final cert = Certificate(
      id: 'cert_${now.millisecondsSinceEpoch}',
      serial: 'AGDS-$grade-${now.millisecondsSinceEpoch}',
      studentId: studentId,
      studentName: studentName,
      grade: grade,
      yearLabel: yearLabel,
      average: average,
      honor: honor,
      issuedAt: now,
      issuedBy: 'مدیریت مکتب',
    );
    final all = await _readAll();
    all.add(cert);
    await _writeAll(all);
    return cert;
  }

  /// ابطال/حذف گواهی‌نامه توسط مدیر.
  @override
  Future<void> revoke(String certificateId) async {
    final all = await _readAll();
    all.removeWhere((c) => c.id == certificateId);
    await _writeAll(all);
  }
}
