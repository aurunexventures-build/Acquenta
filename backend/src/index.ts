import { verifyAuth } from './auth';

export interface Env {
  metcue_db: D1Database;
  VECTORIZE: VectorizeIndex;
  AI: any;
  FIREBASE_PROJECT_ID: string;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    try {
      // 1. Health check & status
      if (url.pathname === "/" || url.pathname === "/health") {
        return Response.json({
          app: "MetCue Edge API",
          status: "online",
          region: "Cloudflare Edge",
          database: "D1 metcue-db",
          vectorIndex: "metcue-index (384-dim cosine)",
          firebaseProject: env.FIREBASE_PROJECT_ID,
        }, { headers: CORS_HEADERS });
      }

      // 2. Web Card Landing Page (/c/:cardId) - No auth required for recipients!
      if (url.pathname.startsWith("/c/")) {
        const cardId = url.pathname.split("/")[2];
        const eventName = url.searchParams.get("event") || "";

        const cardResult = await env.metcue_db.prepare(
          "SELECT * FROM contact_cards WHERE id = ?"
        ).bind(cardId).first();

        if (!cardResult) {
          return new Response("Card not found or inactive.", { status: 404 });
        }

        const fullName = String(cardResult.full_name || "Contact");
        const title = String(cardResult.title || "");
        const role = String(cardResult.role || "");
        const company = String(cardResult.company || "");
        const headline = String(cardResult.headline || "");
        const email = String(cardResult.email || "");
        const phone = String(cardResult.phone || "");
        const color = String(cardResult.theme_color_hex || "#2563EB");

        const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${fullName} • MetCue</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-50 min-h-screen flex items-center justify-center p-4 font-sans">
  <div class="max-w-md w-full bg-white rounded-3xl shadow-xl overflow-hidden border border-slate-100">
    <div class="h-4" style="background: ${color}"></div>
    <div class="p-6">
      <div class="flex items-center space-x-4 mb-4">
        <div class="w-16 h-16 rounded-full flex items-center justify-center text-white font-bold text-xl" style="background: ${color}">
          ${fullName.split(' ').map(n => n[0]).join('')}
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-900">${fullName}</h1>
          <p class="text-sm font-medium text-slate-500">${role} ${company ? '@ ' + company : ''}</p>
        </div>
      </div>
      ${headline ? `<p class="text-slate-600 text-sm mb-4">${headline}</p>` : ''}
      ${eventName ? `<div class="bg-amber-50 text-amber-900 text-xs font-semibold px-3 py-1.5 rounded-full inline-block mb-4">📍 Met at ${eventName}</div>` : ''}

      <div class="space-y-2 mb-6">
        ${email ? `<a href="mailto:${email}" class="block w-full py-2.5 px-4 bg-slate-100 hover:bg-slate-200 text-slate-800 text-sm font-semibold rounded-xl text-center">✉️ Email: ${email}</a>` : ''}
        ${phone ? `<a href="tel:${phone}" class="block w-full py-2.5 px-4 bg-slate-100 hover:bg-slate-200 text-slate-800 text-sm font-semibold rounded-xl text-center">📞 Call / SMS: ${phone}</a>` : ''}
      </div>

      <!-- Reciprocal 5-Second Contact Drop -->
      <div class="bg-blue-50 border border-blue-100 rounded-2xl p-4">
        <h3 class="text-xs font-bold text-blue-900 uppercase tracking-wider mb-1">Share your details back in 5s</h3>
        <p class="text-xs text-blue-700 mb-3">Send your contact info directly to ${fullName}'s MetCue app.</p>
        <form action="/api/v1/reciprocal" method="POST" class="space-y-2">
          <input type="hidden" name="card_id" value="${cardId}">
          <input type="hidden" name="event_name" value="${eventName}">
          <input type="text" name="name" required placeholder="Your Name" class="w-full text-xs p-2.5 rounded-lg border border-blue-200 focus:outline-none focus:ring-1 focus:ring-blue-500">
          <input type="text" name="contact" required placeholder="Email or Phone / LinkedIn" class="w-full text-xs p-2.5 rounded-lg border border-blue-200 focus:outline-none focus:ring-1 focus:ring-blue-500">
          <input type="text" name="note" placeholder="Quick note (e.g. what you build)" class="w-full text-xs p-2.5 rounded-lg border border-blue-200 focus:outline-none focus:ring-1 focus:ring-blue-500">
          <button type="submit" class="w-full py-2.5 text-xs font-bold text-white rounded-lg transition" style="background: ${color}">Beam My Contact Back</button>
        </form>
      </div>
    </div>
  </div>
</body>
</html>`;
        return new Response(html, {
          headers: { "Content-Type": "text/html; charset=utf-8" },
        });
      }

      // 3. Reciprocal Contact Submission Form
      if (url.pathname === "/api/v1/reciprocal" && request.method === "POST") {
        const formData = await request.formData();
        const cardId = String(formData.get("card_id") || "");
        const name = String(formData.get("name") || "");
        const contact = String(formData.get("contact") || "");
        const note = String(formData.get("note") || "");
        const event = String(formData.get("event_name") || "Networking");

        const card = await env.metcue_db.prepare(
          "SELECT user_id FROM contact_cards WHERE id = ?"
        ).bind(cardId).first();

        if (card && card.user_id) {
          const id = crypto.randomUUID();
          await env.metcue_db.prepare(`
            INSERT INTO saved_connections (id, user_id, full_name, email, headline, event_name, event_date, discussion_notes, tech_stack, links, event_tags)
            VALUES (?, ?, ?, ?, ?, ?, datetime('now'), ?, '[]', '[]', '[]')
          `).bind(id, card.user_id, name, contact, note, event, `Reciprocal contact received via MetCue Web Card: ${note}`).run();
        }

        return new Response(`<!DOCTYPE html><html><body style="font-family:sans-serif;text-align:center;padding:50px"><h2>✅ Contact shared with ${name}!</h2><p>Your details were sent to their MetCue app.</p></body></html>`, {
          headers: { "Content-Type": "text/html; charset=utf-8" },
        });
      }

      // --- PROTECTED API ENDPOINTS (Require Firebase JWT) ---
      const userId = await verifyAuth(request, env.FIREBASE_PROJECT_ID || "metcue09");

      // 4. Delta Synchronization (/api/v1/sync)
      if (url.pathname === "/api/v1/sync" && request.method === "POST") {
        const body: any = await request.json();
        const { lastSyncedAt, mutations } = body;

        if (Array.isArray(mutations)) {
          for (const item of mutations) {
            await env.metcue_db.prepare(`
              INSERT INTO saved_connections (id, user_id, full_name, company, role, headline, email, phone, event_name, event_date, location, discussion_notes, tech_stack, event_tags, is_favorite, saved_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                full_name=excluded.full_name,
                company=excluded.company,
                role=excluded.role,
                headline=excluded.headline,
                email=excluded.email,
                phone=excluded.phone,
                event_name=excluded.event_name,
                event_date=excluded.event_date,
                location=excluded.location,
                discussion_notes=excluded.discussion_notes,
                tech_stack=excluded.tech_stack,
                event_tags=excluded.event_tags,
                is_favorite=excluded.is_favorite
            `).bind(
              item.id, userId, item.fullName, item.company || '', item.role || '',
              item.headline || '', item.email || '', item.phone || '',
              item.eventName || '', item.eventDate || new Date().toISOString(),
              item.location || '', item.discussionNotes || '',
              JSON.stringify(item.techStack || []), JSON.stringify(item.eventTags || []),
              item.isFavorite ? 1 : 0, item.savedAt || new Date().toISOString()
            ).run();

            // Generate dense vector embedding & upsert into Cloudflare Vectorize
            const textToEmbed = `${item.fullName} ${item.role || ''} ${item.company || ''} ${item.eventName || ''} ${(item.techStack || []).join(' ')} ${item.discussionNotes || ''}`.trim();
            if (textToEmbed) {
              const embeddingRes = await env.AI.run("@cf/baai/bge-small-en-v1.5", {
                text: [textToEmbed],
              });
              if (embeddingRes?.data?.[0]) {
                await env.VECTORIZE.upsert([{
                  id: item.id,
                  values: embeddingRes.data[0],
                  namespace: userId,
                  metadata: {
                    fullName: item.fullName,
                    eventName: item.eventName || '',
                  },
                }]);
              }
            }
          }
        }

        const changes = await env.metcue_db.prepare(
          "SELECT * FROM saved_connections WHERE user_id = ?"
        ).bind(userId).all();

        return Response.json({
          success: true,
          changes: changes.results,
          timestamp: new Date().toISOString(),
        }, { headers: CORS_HEADERS });
      }

      // 5. Cloud Semantic Vector Search (/api/v1/search/semantic)
      if (url.pathname === "/api/v1/search/semantic" && request.method === "POST") {
        const { query, topK = 10 }: any = await request.json();
        if (!query) {
          return Response.json({ error: "Missing query parameter." }, { status: 400, headers: CORS_HEADERS });
        }

        const embeddingRes = await env.AI.run("@cf/baai/bge-small-en-v1.5", {
          text: [query],
        });
        const queryVector = embeddingRes.data[0];

        const vectorMatches = await env.VECTORIZE.query(queryVector, {
          topK: topK,
          namespace: userId,
        });

        const connectionIds = vectorMatches.matches.map(m => m.id);
        let records: any[] = [];
        if (connectionIds.length > 0) {
          const placeholders = connectionIds.map(() => "?").join(",");
          const recordsResult = await env.metcue_db.prepare(
            `SELECT * FROM saved_connections WHERE id IN (${placeholders})`
          ).bind(...connectionIds).all();
          records = recordsResult.results;
        }

        return Response.json({
          success: true,
          query,
          matches: vectorMatches.matches,
          connections: records,
        }, { headers: CORS_HEADERS });
      }

      // 6. Voice Memo Ingest (/api/v1/capture/memo)
      if (url.pathname === "/api/v1/capture/memo" && request.method === "POST") {
        const formData = await request.formData();
        const audioFile = formData.get("audio") as File;
        if (!audioFile) {
          return Response.json({ error: "Audio file is required." }, { status: 400, headers: CORS_HEADERS });
        }
        const audioBuffer = await audioFile.arrayBuffer();

        const transcription = await env.AI.run("@cf/openai/whisper", {
          audio: [...new Uint8Array(audioBuffer)],
        });

        const prompt = `Extract networking contact data from this transcript to strict JSON: {"name": string|null, "company": string|null, "role": string|null, "discussion_summary": string, "tags": string[], "action_item": string|null}. Transcript: "${transcription.text}"`;
        const extraction = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
          prompt,
          max_tokens: 512,
        });

        let structured = {};
        try {
          structured = JSON.parse(extraction.response);
        } catch (_) {
          structured = { text: transcription.text };
        }

        return Response.json({
          rawText: transcription.text,
          structured,
        }, { headers: CORS_HEADERS });
      }

      return new Response("Not Found", { status: 404, headers: CORS_HEADERS });
    } catch (err: any) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
  },
};
