import '../../../../core/errors/failures.dart';
import '../../../../shared_models/seminar.dart';

/// مخزن مشترک و واحد سمینارها (Singleton) — منبع حقیقت یکسان برای
/// شاگرد، والد، استاد سمینار و مدیر ارشد. در فاز ۱ داده در حافظه است؛
/// از فاز ۲ این کلاس با سرویس واقعی `/api/v1/seminars` جایگزین می‌شود
/// (بخش ۱۹.۸ سند) بدون تغییر در Interface.
class SeminarStore {
  SeminarStore._();
  static final SeminarStore instance = SeminarStore._();

  final List<Seminar> _seminars = [
    Seminar(
      id: 'sem-live-1',
      title: 'مهارت‌های مطالعهٔ مؤثر',
      description: 'تکنیک‌های علمی برای مطالعهٔ عمیق، مدیریت زمان و آمادگی امتحان.',
      instructorId: 'u-instructor-demo',
      instructorName: 'استاد رحیمی',
      scheduledStart: DateTime.now().subtract(const Duration(minutes: 5)),
      durationMinutes: 60,
      status: SeminarStatus.live,
      capacity: 100,
      audience: SeminarAudience.students,
      registeredUserIds: _mockIds(62),
    ),
    Seminar(
      id: 'sem-up-1',
      title: 'آمادگی برای امتحان کانکور',
      description: 'مرور استراتژی‌های پاسخ‌دهی، مدیریت استرس و برنامه‌ریزی هفتگی.',
      instructorId: 'u-instructor-demo',
      instructorName: 'استاد رحیمی',
      scheduledStart: DateTime.now().add(const Duration(days: 1, hours: 2)),
      durationMinutes: 60,
      status: SeminarStatus.published,
      capacity: 50,
      audience: SeminarAudience.students,
      registeredUserIds: _mockIds(49),
    ),
    Seminar(
      id: 'sem-up-2',
      title: 'برنامه‌نویسی برای نوجوانان',
      description: 'آشنایی با دنیای برنامه‌نویسی و ساخت اولین پروژهٔ کوچک.',
      instructorId: 'u-instructor-2',
      instructorName: 'استاد کریمی',
      scheduledStart: DateTime.now().add(const Duration(days: 4)),
      durationMinutes: 45,
      status: SeminarStatus.published,
      capacity: 80,
      audience: SeminarAudience.students,
      registeredUserIds: _mockIds(31),
    ),
    Seminar(
      id: 'sem-par-1',
      title: 'نقش والدین در آموزش دیجیتال',
      description: 'چگونه از فرزند خود در مسیر یادگیری آنلاین حمایت کنیم؟ (ویژهٔ والدین)',
      instructorId: 'u-instructor-demo',
      instructorName: 'استاد رحیمی',
      scheduledStart: DateTime.now().add(const Duration(minutes: 3)),
      durationMinutes: 45,
      status: SeminarStatus.published,
      capacity: 60,
      audience: SeminarAudience.parents,
      registeredUserIds: _mockIds(18),
    ),
    Seminar(
      id: 'sem-par-2',
      title: 'ایمنی آنلاین فرزندان',
      description: 'راهنمای عملی والدین برای محافظت از فرزندان در فضای مجازی.',
      instructorId: 'u-instructor-2',
      instructorName: 'استاد کریمی',
      scheduledStart: DateTime.now().add(const Duration(days: 3)),
      durationMinutes: 40,
      status: SeminarStatus.published,
      capacity: 60,
      audience: SeminarAudience.parents,
      registeredUserIds: _mockIds(7),
    ),
  ];

  static Set<String> _mockIds(int count) => {for (var i = 0; i < count; i++) 'mock-u-$i'};

  Future<void> _latency([int ms = 250]) => Future.delayed(Duration(milliseconds: ms));

  Future<List<Seminar>> getAll() async {
    await _latency();
    final list = [..._seminars]..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return List.unmodifiable(list);
  }

  /// سمینارهای قابل مشاهده برای شاگرد یا والد — فقط مخاطب مربوطه و
  /// فقط سمینارهای منتشرشده/زنده که هنوز پایان نیافته‌اند.
  Future<List<Seminar>> getVisibleFor(SeminarAudience audience) async {
    await _latency();
    final list = _seminars
        .where((s) =>
            s.audience == audience &&
            (s.status == SeminarStatus.published ||
                s.status == SeminarStatus.registrationClosed ||
                s.status == SeminarStatus.live) &&
            !s.hasEnded)
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return List.unmodifiable(list);
  }

  Future<List<Seminar>> getByInstructor(String instructorId) async {
    await _latency();
    return byInstructorSync(instructorId);
  }

  /// نسخهٔ همگام — برای نمای «مدیریت استادان» (محاسبهٔ آمار فعالیت هر
  /// استاد در لیست مدیر، بدون تأخیر مصنوعی به‌ازای هر کارت).
  List<Seminar> byInstructorSync(String instructorId) {
    final list = _seminars.where((s) => s.instructorId == instructorId).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return List.unmodifiable(list);
  }

  Seminar? getByIdSync(String id) {
    final idx = _seminars.indexWhere((s) => s.id == id);
    return idx == -1 ? null : _seminars[idx];
  }

  Future<Seminar> getById(String id) async {
    await _latency(120);
    final s = getByIdSync(id);
    if (s == null) throw const ServerFailure('سمینار یافت نشد', code: 'NOT_FOUND');
    return s;
  }

  /// ثبت‌نام «فقط یک‌بار» — طبق `POST /seminars/{id}/register` بخش ۱۹.۸:
  /// کاربر تکراری، ظرفیت تکمیل و ثبت‌نام بسته همگی با خطای مشخص رد می‌شوند.
  Future<void> register(String seminarId, String userId) async {
    await _latency();
    final idx = _seminars.indexWhere((s) => s.id == seminarId);
    if (idx == -1) throw const ServerFailure('سمینار یافت نشد', code: 'NOT_FOUND');
    final s = _seminars[idx];
    if (s.isRegistered(userId)) {
      throw const ValidationFailure('شما قبلاً در این سمینار ثبت‌نام کرده‌اید');
    }
    if (s.hasEnded) {
      throw const ValidationFailure('این سمینار پایان یافته است');
    }
    if (s.status == SeminarStatus.registrationClosed) {
      throw const ValidationFailure('ثبت‌نام این سمینار بسته شده است');
    }
    if (s.isFull) {
      throw const ValidationFailure('ظرفیت این سمینار تکمیل شده است');
    }
    _seminars[idx] = s.copyWith(registeredUserIds: {...s.registeredUserIds, userId});
  }

  Future<Seminar> create({
    required String title,
    required String description,
    required String instructorId,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience = SeminarAudience.students,
    SeminarStatus status = SeminarStatus.published,
    String meetingLink = '',
  }) async {
    await _latency(350);
    final seminar = Seminar(
      id: 'sem-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      instructorId: instructorId,
      instructorName: instructorName,
      scheduledStart: scheduledStart,
      durationMinutes: durationMinutes,
      status: status,
      capacity: capacity,
      audience: audience,
      meetingLink: meetingLink,
    );
    _seminars.add(seminar);
    return seminar;
  }

  Future<void> update({
    required String id,
    String? title,
    String? description,
    String? instructorId,
    String? instructorName,
    DateTime? scheduledStart,
    int? durationMinutes,
    SeminarStatus? status,
    int? capacity,
    bool clearCapacity = false,
    SeminarAudience? audience,
    String? meetingLink,
  }) async {
    await _latency(350);
    final idx = _seminars.indexWhere((s) => s.id == id);
    if (idx == -1) throw const ServerFailure('سمینار یافت نشد', code: 'NOT_FOUND');
    _seminars[idx] = _seminars[idx].copyWith(
      title: title,
      description: description,
      instructorId: instructorId,
      instructorName: instructorName,
      scheduledStart: scheduledStart,
      durationMinutes: durationMinutes,
      status: status,
      capacity: capacity,
      clearCapacity: clearCapacity,
      audience: audience,
      meetingLink: meetingLink,
    );
  }

  Future<void> delete(String id) async {
    await _latency(200);
    _seminars.removeWhere((s) => s.id == id);
  }

  /// تغییر وضعیت (شروع زنده / پایان و…) — State Machine بخش ۱۲.۲.
  Future<void> setStatus(String id, SeminarStatus status) async {
    await _latency(150);
    final idx = _seminars.indexWhere((s) => s.id == id);
    if (idx == -1) throw const ServerFailure('سمینار یافت نشد', code: 'NOT_FOUND');
    _seminars[idx] = _seminars[idx].copyWith(status: status);
  }
}
