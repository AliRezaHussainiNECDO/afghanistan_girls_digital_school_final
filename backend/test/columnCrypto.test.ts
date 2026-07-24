/**
 * test/columnCrypto.test.ts — lib/columnCrypto.ts (رمزگذاری ستونی AES-256-GCM
 * برای تلفن/تاریخ تولد، اضافه‌شده در همین نشست). چون این ماژول باید
 * Fail-safe باشد (هرگز نباید ثبت‌نام/نمایش پروفایل را بشکند)، تست‌ها روی
 * حالت‌های خطا (کلید نبودن، دادهٔ دستکاری‌شده) هم تمرکز دارند، نه فقط مسیر
 * موفق.
 */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { encryptField, decryptField, resolveEncryptedContact } from '../src/lib/columnCrypto';

// یک کلید ۳۲بایتی معتبر برای تست — با همان دستوری که در wrangler.toml/DNS
// مستند شده تولید می‌شود: `openssl rand -base64 32`.
const TEST_KEY = Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString('base64');

describe('encryptField / decryptField — مسیر موفق', () => {
  test('رمزگشاییِ متنِ رمزشده، دقیقاً همان متن اصلی را برمی‌گرداند', async () => {
    const enc = await encryptField({ COLUMN_ENCRYPTION_KEY: TEST_KEY }, '+93700000001');
    assert.ok(enc);
    const dec = await decryptField({ COLUMN_ENCRYPTION_KEY: TEST_KEY }, enc);
    assert.equal(dec, '+93700000001');
  });

  test('دو رمزنگاری از یک متن یکسان، خروجی متفاوت می‌دهند (IV تصادفی)', async () => {
    const env = { COLUMN_ENCRYPTION_KEY: TEST_KEY };
    const a = await encryptField(env, 'same-value');
    const b = await encryptField(env, 'same-value');
    assert.notEqual(a, b);
    // اما هر دو باید درست رمزگشایی شوند.
    assert.equal(await decryptField(env, a), 'same-value');
    assert.equal(await decryptField(env, b), 'same-value');
  });

  test('متن با کاراکترهای فارسی/یونیکد هم درست رمزگشایی می‌شود', async () => {
    const env = { COLUMN_ENCRYPTION_KEY: TEST_KEY };
    const text = 'کابل، افغانستان — ۱۴۰۵/۰۵/۰۲';
    const enc = await encryptField(env, text);
    assert.equal(await decryptField(env, enc), text);
  });
});

describe('encryptField / decryptField — Fail-safe (هرگز نباید پرتاب کند)', () => {
  test('بدون کلید، encryptField مقدار null برمی‌گرداند (نه خطا)', async () => {
    assert.equal(await encryptField({}, 'some-phone'), null);
  });

  test('بدون کلید، decryptField رشتهٔ خالی برمی‌گرداند', async () => {
    assert.equal(await decryptField({}, 'anything'), '');
  });

  test('ورودی خالی/null در encryptField → null', async () => {
    const env = { COLUMN_ENCRYPTION_KEY: TEST_KEY };
    assert.equal(await encryptField(env, null), null);
    assert.equal(await encryptField(env, undefined), null);
    assert.equal(await encryptField(env, ''), null);
  });

  test('رمزگشایی با کلید اشتباه، رشتهٔ خالی می‌دهد نه استثنا', async () => {
    const wrongKey = Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString('base64');
    const enc = await encryptField({ COLUMN_ENCRYPTION_KEY: TEST_KEY }, 'secret-value');
    const dec = await decryptField({ COLUMN_ENCRYPTION_KEY: wrongKey }, enc);
    assert.equal(dec, '');
  });

  test('دادهٔ دستکاری‌شده (Ciphertext خراب) → رشتهٔ خالی، نه استثنا', async () => {
    const env = { COLUMN_ENCRYPTION_KEY: TEST_KEY };
    const enc = await encryptField(env, 'secret-value');
    const tampered = enc!.slice(0, -4) + 'XXXX';
    const dec = await decryptField(env, tampered);
    assert.equal(dec, '');
  });

  test('رشتهٔ کاملاً نامعتبر (نه Base64 حتی) → رشتهٔ خالی', async () => {
    const dec = await decryptField({ COLUMN_ENCRYPTION_KEY: TEST_KEY }, 'not-valid-base64-!!!');
    assert.equal(dec, '');
  });
});

describe('resolveEncryptedContact — سازگاری با ردیف‌های قدیمی و جدید', () => {
  test('ردیف تازه (فقط ستون رمزشده پر است) → مقدار رمزگشایی‌شده', async () => {
    const env = { COLUMN_ENCRYPTION_KEY: TEST_KEY };
    const enc = await encryptField(env, '+93700000009');
    const result = await resolveEncryptedContact(env, { phone_enc: enc, phone: null });
    assert.equal(result.phone, '+93700000009');
  });

  test('ردیف قدیمی (فقط ستون متن‌سادهٔ قبلی پر است) → مقدار متن‌ساده به‌عنوان fallback', async () => {
    const env = { COLUMN_ENCRYPTION_KEY: TEST_KEY };
    const result = await resolveEncryptedContact(env, { phone_enc: null, phone: '+93700000008' });
    assert.equal(result.phone, '+93700000008');
  });

  test('هیچ‌کدام پر نیست → رشتهٔ خالی', async () => {
    const env = { COLUMN_ENCRYPTION_KEY: TEST_KEY };
    const result = await resolveEncryptedContact(env, {});
    assert.equal(result.phone, '');
    assert.equal(result.dateOfBirth, '');
  });
});
