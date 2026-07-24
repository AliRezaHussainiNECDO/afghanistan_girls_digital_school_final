/**
 * test/progress.test.ts — lib/progress.ts::averagePercent، تابعی که «پیشرفت
 * کلی صنف» را در داشبورد شاگرد/والد/مدیر یکسان محاسبه می‌کند (طبق کامنت خودِ
 * فایل: قبلاً این محاسبه در ۵ جای مختلف تکرار می‌شد و اعداد باهم فرق
 * می‌کردند — این تست تضمین می‌کند منطق مشترک درست کار می‌کند).
 */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { averagePercent, type SubjectProgress } from '../src/lib/progress';

const subj = (percent: number): SubjectProgress => ({
  subjectId: 'x',
  nameFa: 'x',
  totalLessons: 10,
  viewedLessons: Math.round((percent / 100) * 10),
  percent,
  status: 'inProgress',
});

describe('averagePercent', () => {
  test('لیست خالی → صفر (نه NaN یا خطا)', () => {
    assert.equal(averagePercent([]), 0);
  });

  test('یک مضمون → همان عدد', () => {
    assert.equal(averagePercent([subj(50)]), 50);
  });

  test('میانگین چند مضمون درست محاسبه می‌شود', () => {
    assert.equal(averagePercent([subj(100), subj(0), subj(50)]), 50);
  });

  test('گرد کردن تا یک رقم اعشار (نه بیشتر)', () => {
    // (10 + 20 + 25) / 3 = 18.333... → باید 18.3 شود.
    const result = averagePercent([subj(10), subj(20), subj(25)]);
    assert.equal(result, 18.3);
  });

  test('همهٔ مضامین صد درصد → صد درصد', () => {
    assert.equal(averagePercent([subj(100), subj(100), subj(100)]), 100);
  });
});
