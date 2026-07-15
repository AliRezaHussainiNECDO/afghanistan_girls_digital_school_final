import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/ai_teacher_management_data_source.dart';
import '../../data/datasources/ai_teacher_management_local_datasource.dart';
import '../../data/datasources/ai_teacher_management_remote_datasource.dart';
import '../../data/repositories_impl/ai_teacher_management_repository_impl.dart';
import '../../domain/entities/ai_teacher_config.dart';
import '../../domain/repositories/ai_teacher_management_repository.dart';
import '../../domain/usecases/ai_teacher_management_usecases.dart';

/// رفع اشکال: قبلاً همیشه از دادهٔ محلی (SharedPreferences) استفاده می‌شد و
/// این بخش هرگز به سرور/دیتابیس وصل نبود. اکنون مانند بقیهٔ ماژول‌ها با
/// سوییچ `kUseLiveBackend` بین محلی (فاز ۱ / آفلاین) و Backend واقعی جابه‌جا
/// می‌شود.
final aiTeacherMgmtDataSourceProvider = Provider<AiTeacherManagementDataSou