/**
 * lib/embeddings.ts — بازیابی معنایی (RAG) برای معلم هوشمند.
 *
 * به‌جای تطابق سادهٔ کلمه‌ای (که در نبود عین همان کلمات، متن درست را پیدا
 * نمی‌کند)، متن هر درس و هر پرسش شاگرد را به یک بردار عددی (embedding)
 * تبدیل می‌کنیم و با شباهت کسینوسی نزدیک‌ترین درس‌ها را پیدا می‌کنیم —
 * مستقل از عین کلمات، بر اساس معنا.
 *
 * از همان کلید سرویس هوش مصنوعی موجود (`AI_PROVIDER_KEY`) استفاده می‌شود؛
 * سرویس جداگانه/هزینهٔ اضافه‌ای لازم نیست. Fail-safe کامل: هر خطا فقط
 * `null` برمی‌گرداند، هرگز صفحهٔ شاگرد را خراب نمی‌کند (طبق همان اصل که در
 * TTS/STT این پروژه رعایت شده).
 */

const EMBEDDING_MODEL = 'text-embedding-3-small';

export async function embedText(
  apiKey: string | undefined,
  text: string,
  baseUrl?: string,
): Promise<number[] | null> {
  const trimmed = text.trim();
  if (!apiKey || !trimmed) return null;
  try {
    const url = (baseUrl ?? 'https://api.openai.com/v1/chat/completions').replace(
      '/chat/completions',
      '/embeddings',
    );
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      // محدود به ~۸۰۰۰ نویسه — کافی برای یک «درس» کوتاه، از سقف مدل embedding جلوگیری می‌کند.
      body: JSON.stringify({ model: EMBEDDING_MODEL, input: trimmed.slice(0, 8000) }),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as any;
    const vector = data?.data?.[0]?.embedding;
    return Array.isArray(vector) ? (vector as number[]) : null;
  } catch (_) {
    return null;
  }
}

export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length === 0 || b.length === 0 || a.length !== b.length) return 0;
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}
