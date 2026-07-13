import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/certificates_local_datasource.dart';
import '../../data/datasources/certificates_remote_datasource.dart';
import '../../domain/entities/certificate.dart';

/// محلی (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final certificatesDataSourceProvider = Provider<CertificatesDataSource>((ref) {
  if (kUseLiveBackend) {
    return CertificatesRemoteDataSource(ref.watch(apiClientProvider));
  }
  return CertificatesLocalDataSource();
});

/// همهٔ گواهی‌نامه‌های صادرشده (برای مدیر / حالت نمایشی).
final allCertificatesProvider = FutureProvider<List<Certificate>>(
    (ref) => ref.read(certificatesDataSourceProvider).getAll());

/// گواهی‌نامه‌های یک شاگرد مشخص.
final certificatesForStudentProvider =
    FutureProvider.family<List<Certificate>, String>((ref, studentId) =>
        ref.read(certificatesDataSourceProvider).getForStudent(studentId));

class IssueCertificateParams {
  final String studentId;
  final String studentName;
  final int grade;
  final String yearLabel;
  final double average;
  final String honor;
  const IssueCertificateParams({
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.yearLabel,
    required this.average,
    required this.honor,
  });
}

/// کنترلر اکشن‌های مدیر: صدور/ارسال و ابطال گواهی‌نامه.
class CertificateActions {
  final Ref ref;
  CertificateActions(this.ref);

  Future<Certificate> issue(IssueCertificateParams p) async {
    final cert = await ref.read(certificatesDataSourceProvider).issue(
          studentId: p.studentId,
          studentName: p.studentName,
          grade: p.grade,
          yearLabel: p.yearLabel,
          average: p.average,
          honor: p.honor,
        );
    ref.invalidate(allCertificatesProvider);
    ref.invalidate(certificatesForStudentProvider);
    return cert;
  }

  Future<void> revoke(String certificateId) async {
    await ref.read(certificatesDataSourceProvider).revoke(certificateId);
    ref.invalidate(allCertificatesProvider);
    ref.invalidate(certificatesForStudentProvider);
  }
}

final certificateActionsProvider = Provider((ref) => CertificateActions(ref));
