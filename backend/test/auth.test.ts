/**
 * test/auth.test.ts — تست‌های واحد برای هستهٔ احراز هویت (lib/auth.ts):
 * هش/تأیید رمز عبور (PBKDF2) و صدور/تأیید JWT (HS256). این‌ها حساس‌ترین
 * منطق کل برنامه‌اند — یک باگ اینجا یعنی یا ورود همه می‌شکند، یا (بدتر) یک
 * توکن جعلی/منقضی پذیرفته می‌شود.
 *
 * اجرا:  npx tsx --test test/auth.test.ts   (یا  npm test)
 */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { hashPassword, verifyPassword, signJwt, verifyJwt, verifyBearer } from '../src/lib/auth';

describe('hashPassword / verifyPassword', () => {
  test('رمز درست بعد از هش، با موفقیت تأیید می‌شود', async () => {
    const hash = await hashPassword('SuperSecret123');
    assert.equal(await verifyPassword('SuperSecret123', hash), true);
  });

  test('رمز اشتباه رد می‌شود', async () => {
    const hash = await hashPassword('SuperSecret123');
    assert.equal(await verifyPassword('WrongPassword', hash), false);
  });

  test('هر بار هش، یک Salt متفاوت تولید می‌کند (دو هش از یک رمز یکسان نیستند)', async () => {
    const h1 = await hashPassword('SamePassword1');
    const h2 = await hashPassword('SamePassword1');
    assert.notEqual(h1, h2);
    // اما هر دو باید همان رمز را تأیید کنند.
    assert.equal(await verifyPassword('SamePassword1', h1), true);
    assert.equal(await verifyPassword('SamePassword1', h2), true);
  });

  test('فرمت نامعتبر/خراب باعث false می‌شود، نه پرتاب خطا', async () => {
    assert.equal(await verifyPassword('anything', 'not-a-valid-hash'), false);
    assert.equal(await verifyPassword('anything', 'pbkdf2$100000$onlytwoparts'), false);
    assert.equal(await verifyPassword('anything', ''), false);
  });

  test('خروجی با پیشوند pbkdf2$ و تعداد تکرار درست شروع می‌شود', async () => {
    const hash = await hashPassword('x');
    const parts = hash.split('$');
    assert.equal(parts[0], 'pbkdf2');
    assert.equal(Number(parts[1]), 100_000);
  });
});

describe('signJwt / verifyJwt', () => {
  const SECRET = 'test-secret-do-not-use-in-prod';

  test('توکن صادرشده با همان کلید، معتبر تأیید می‌شود و sub درست برمی‌گردد', async () => {
    const token = await signJwt({ sub: 'user-42', role: 'student' }, SECRET);
    const payload = await verifyJwt(token, SECRET);
    assert.ok(payload);
    assert.equal(payload!.sub, 'user-42');
    assert.equal(payload!.role, 'student');
  });

  test('توکن با کلید اشتباه رد می‌شود (null، نه پرتاب خطا)', async () => {
    const token = await signJwt({ sub: 'user-1' }, SECRET);
    const payload = await verifyJwt(token, 'a-completely-different-secret');
    assert.equal(payload, null);
  });

  test('توکنِ دستکاری‌شده (امضا/بدنه تغییرکرده) رد می‌شود', async () => {
    const token = await signJwt({ sub: 'user-1' }, SECRET);
    const [h, p, s] = token.split('.');
    // یک کاراکتر از امضا را عوض می‌کنیم — باید رد شود.
    const tamperedSig = s.slice(0, -1) + (s.at(-1) === 'A' ? 'B' : 'A');
    const payload = await verifyJwt(`${h}.${p}.${tamperedSig}`, SECRET);
    assert.equal(payload, null);
  });

  test('توکن منقضی‌شده رد می‌شود', async () => {
    const token = await signJwt({ sub: 'user-1' }, SECRET, -10); // ۱۰ ثانیه قبل منقضی شده
    const payload = await verifyJwt(token, SECRET);
    assert.equal(payload, null);
  });

  test('رشتهٔ کاملاً نامعتبر (نه سه بخشی) رد می‌شود، بدون کرش', async () => {
    assert.equal(await verifyJwt('not-a-jwt-at-all', SECRET), null);
    assert.equal(await verifyJwt('', SECRET), null);
  });
});

describe('verifyBearer', () => {
  const SECRET = 'test-secret-do-not-use-in-prod';

  test('هدر معتبر Bearer <token> پردازش می‌شود', async () => {
    const token = await signJwt({ sub: 'user-9' }, SECRET);
    const payload = await verifyBearer(`Bearer ${token}`, SECRET);
    assert.ok(payload);
    assert.equal(payload!.sub, 'user-9');
  });

  test('بدون پیشوند Bearer یا هدر خالی، null برمی‌گردد', async () => {
    const token = await signJwt({ sub: 'user-9' }, SECRET);
    assert.equal(await verifyBearer(token, SECRET), null); // بدون "Bearer "
    assert.equal(await verifyBearer(undefined, SECRET), null);
    assert.equal(await verifyBearer('', SECRET), null);
  });
});
