/**
 * test/inviteCode.test.ts — نرمال‌سازی کد دعوت (routes/auth.ts) پیش از
 * مقایسه با دیتابیس. این منطق باید فاصلهٔ اضافه، حروف کوچک، و ارقام
 * فارسی/عربی را طوری یکسان‌سازی کند که کاربر واقعی (که ممکن است کیبورد
 * فارسی داشته باشد) هرگز با پیام اشتباهِ «کد نامعتبر» مواجه نشود.
 */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeInviteCode } from '../src/routes/auth';

describe('normalizeInviteCode', () => {
  test('حروف کوچک به بزرگ تبدیل می‌شود', () => {
    assert.equal(normalizeInviteCode('stu-000123'), 'STU-000123');
  });

  test('فاصلهٔ ابتدا/انتها و وسط حذف می‌شود', () => {
    assert.equal(normalizeInviteCode('  STU-000123  '), 'STU-000123');
    assert.equal(normalizeInviteCode('STU - 000123'), 'STU-000123');
  });

  test('ارقام فارسی به لاتین تبدیل می‌شود', () => {
    assert.equal(normalizeInviteCode('STU-۰۰۰۱۲۳'), 'STU-000123');
  });

  test('ارقام عربی به لاتین تبدیل می‌شود', () => {
    assert.equal(normalizeInviteCode('STU-٠٠٠١٢٣'), 'STU-000123');
  });

  test('ترکیب همهٔ موارد بالا با هم', () => {
    assert.equal(normalizeInviteCode('  stu - ۰۰۰۱۲۳  '), 'STU-000123');
  });

  test('کد از قبل تمیز، بدون تغییر باقی می‌ماند', () => {
    assert.equal(normalizeInviteCode('TCH-ABC123'), 'TCH-ABC123');
  });

  test('رشتهٔ خالی، رشتهٔ خالی برمی‌گرداند (نه خطا)', () => {
    assert.equal(normalizeInviteCode(''), '');
    assert.equal(normalizeInviteCode('   '), '');
  });
});
