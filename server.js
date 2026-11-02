import express from 'express';
import cors from 'cors';
import 'dotenv/config';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const PORT = process.env.PORT || 3000;
const API_KEY = process.env.AI_API_KEY;
const BASE_URL = (process.env.AI_BASE_URL || 'https://openrouter.ai/api/v1').replace(/\/$/, '');
const MODEL = process.env.AI_MODEL || 'openai/gpt-4o-mini';

app.get('/health', (_req, res) => res.json({ ok: true, service: 'Jinni AlKaser' }));

app.post('/api/chat', async (req, res) => {
  try {
    if (!API_KEY) return res.status(500).json({ error: 'الخادم غير مضبوط: أضف AI_API_KEY في متغيرات البيئة.' });
    const messages = req.body?.messages;
    if (!Array.isArray(messages) || messages.length === 0 || messages.length > 60) {
      return res.status(400).json({ error: 'الرسائل غير صالحة.' });
    }
    const safeMessages = messages.map(m => {
      if (!['user', 'assistant'].includes(m.role) || typeof m.content !== 'string') {
        throw new Error('صيغة الرسالة غير صالحة.');
      }
      return { role: m.role, content: m.content.slice(0, 12000) };
    });
    const upstream = await fetch(`${BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${API_KEY}`, 'Content-Type': 'application/json',
        'X-OpenRouter-Title': 'Jinni AlKaser AI' },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: 'system', content: 'أنت جني الكاسر AI، مساعد ذكي ودود وقوي. أجب باللغة العربية افتراضياً، وكن واضحاً وصادقاً ولا تدّعِ قدرات غير متاحة.' },
          ...safeMessages
        ],
        temperature: 0.7,
        max_tokens: 1200
      })
    });
    const data = await upstream.json();
    if (!upstream.ok) {
      console.error('AI provider error:', upstream.status, data);
      return res.status(502).json({ error: data?.error?.message || `مزود الذكاء الاصطناعي أعاد ${upstream.status}` });
    }
    const reply = data?.choices?.[0]?.message?.content;
    if (!reply) return res.status(502).json({ error: 'لم يصل نص جواب من المزود.' });
    return res.json({ reply, model: data.model || MODEL });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message || 'خطأ داخلي في الخادم.' });
  }
});

app.listen(PORT, () => console.log(`Jinni AlKaser backend listening on ${PORT}`));
