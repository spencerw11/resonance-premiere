/**
 * Resonance Proxy — Cloudflare Worker
 *
 * Secrets (set via wrangler secret put):
 *   ANTHROPIC_KEY    — Anthropic API key
 *   GROQ_KEY         — Groq API key
 *   RESONANCE_TOKEN  — Shared secret validated on every request
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-resonance-token',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });
    if (request.method !== 'POST') return json({ error: 'Not found' }, 404);

    // Validate shared secret
    const token = request.headers.get('x-resonance-token');
    if (!token || token !== env.RESONANCE_TOKEN) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const url = new URL(request.url);

    // ── /claude — proxy to Anthropic ─────────────────────────────────
    if (url.pathname === '/claude') {
      const body = await request.text();
      const upstream = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_KEY,
          'anthropic-version': '2023-06-01',
        },
        body,
      });
      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: { ...CORS, 'Content-Type': 'application/json' },
      });
    }

    // ── /transcribe — proxy to Groq Whisper ──────────────────────────
    if (url.pathname === '/transcribe') {
      const { audio } = await request.json(); // base64-encoded WAV

      // Decode base64 → binary
      const binaryStr = atob(audio);
      const bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) bytes[i] = binaryStr.charCodeAt(i);

      // Build multipart/form-data for Groq
      const boundary = 'ResonanceBoundary7x2k9m4p';
      const enc = new TextEncoder();
      const filePart = enc.encode(
        `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="audio.wav"\r\nContent-Type: audio/wav\r\n\r\n`
      );
      const textParts = enc.encode(
        `\r\n--${boundary}\r\nContent-Disposition: form-data; name="model"\r\n\r\nwhisper-large-v3-turbo\r\n` +
        `--${boundary}\r\nContent-Disposition: form-data; name="language"\r\n\r\nen\r\n` +
        `--${boundary}\r\nContent-Disposition: form-data; name="response_format"\r\n\r\njson\r\n` +
        `--${boundary}--\r\n`
      );

      const body = new Uint8Array(filePart.length + bytes.length + textParts.length);
      body.set(filePart, 0);
      body.set(bytes, filePart.length);
      body.set(textParts, filePart.length + bytes.length);

      const upstream = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.GROQ_KEY}`,
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
        },
        body,
      });

      const result = await upstream.json();
      if (!upstream.ok) return json({ error: result.error?.message || 'Transcription failed' }, upstream.status);
      return json({ text: result.text || '' });
    }

    return json({ error: 'Not found' }, 404);
  },
};
