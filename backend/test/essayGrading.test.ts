/**
 * test/essayGrading.test.ts — lib/essayGrading.ts::extractCompleteJsonObjects،
 * منطقِ نجاتِ اشیاء کامل از پاسخ بریدهٔ AI که ریشهٔ باگ «فقط سه سؤال ساخته
 * می‌شود» بود (سقف max_tokens باعث بریده‌شدن آرایه وسط راه می‌شد و کل پاسخ
 * دور انداخته می‌شد). این تست تضمین می‌کند رفتار نجات همیشه درست کار کند.
 */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { extractCompleteJsonObjects } from '../src/lib/essayGrading';

describe('extractCompleteJsonObjects', () => {
  test('آرایهٔ کامل و معتبر — هر سه شیء استخراج می‌شود', () => {
    const text = '[{"id":"q1","score":0.8},{"id":"q2","score":0.5},{"id":"q3","score":1}]';
    const result = extractCompleteJsonObjects(text);
    assert.equal(result.length, 3);
    assert.deepEqual(result.map((r) => r.id), ['q1', 'q2', 'q3']);
  });

  test('پاسخ بریده وسط شیء سوم — فقط دو شیء کامل نجات پیدا می‌کند', () => {
    // این دقیقاً همان الگوی باگ اصلی است: max_tokens تمام می‌شود و آخرین
    // شیء ناقص می‌ماند.
    const text = '[{"id":"q1","score":0.8,"feedback":"خوب"},{"id":"q2","score":0.5,"feedback":"متوسط"},{"id":"q3","score":0.';
    const result = extractCompleteJsonObjects(text);
    assert.equal(result.length, 2);
    assert.equal(result[0].id, 'q1');
    assert.equal(result[1].id, 'q2');
  });

  test('بریدگی وسط یک رشتهٔ متنی (نه فقط بین اشیاء) — همچنان اشیاء قبلی سالم می‌مانند', () => {
    const text = '[{"id":"q1","feedback":"پاسخ درست بود"},{"id":"q2","feedback":"نیمه‌کاره چون بریده شد در وسط این جم';
    const result = extractCompleteJsonObjects(text);
    assert.equal(result.length, 1);
    assert.equal(result[0].id, 'q1');
  });

  test('آکولاد داخل رشته (مثل متن فارسی حاوی { یا }) عمق شمارش را به‌هم نمی‌زند', () => {
    const text = '[{"id":"q1","feedback":"این یک { تست } عجیب است"},{"id":"q2","feedback":"سالم"}]';
    const result = extractCompleteJsonObjects(text);
    assert.equal(result.length, 2);
    assert.equal(result[0].feedback, 'این یک { تست } عجیب است');
  });

  test('رشتهٔ خالی → آرایهٔ خالی، بدون خطا', () => {
    assert.deepEqual(extractCompleteJsonObjects(''), []);
  });

  test('متنی بدون هیچ شیء JSON معتبر → آرایهٔ خالی', () => {
    assert.deepEqual(extractCompleteJsonObjects('این اصلاً JSON نیست'), []);
  });

  test('یک شیء منفرد (بدون پرانتز آرایه دورش) هم شناسایی می‌شود', () => {
    const text = '{"id":"q1","score":1}';
    const result = extractCompleteJsonObjects(text);
    assert.equal(result.length, 1);
    assert.equal(result[0].id, 'q1');
  });

  test('اشیاء تودرتو (nested) به‌درستی به‌عنوان یک واحد کامل شمرده می‌شوند', () => {
    const text = '[{"id":"q1","meta":{"difficulty":"easy","tags":["a","b"]}},{"id":"q2"}]';
    const result = extractCompleteJsonObjects(text);
    assert.equal(result.length, 2);
    assert.equal(result[0].meta.difficulty, 'easy');
  });
});
