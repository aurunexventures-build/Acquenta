# Groq trial setup

Create a free Groq account at https://console.groq.com and create an API key under API Keys. Do not put the key in source control, browser code, or chat.

From the repository root, install the server-side secret interactively:

```sh
node backend/node_modules/wrangler/bin/wrangler.js secret put GROQ_API_KEY --config wrangler.jsonc
```

Paste the key only into Wrangler's hidden prompt. The shared text adapter selects `openai/gpt-oss-120b` when this secret exists; otherwise the existing Workers AI provider remains active. Activating this secret on a deployed adapter affects text organisation, card conversations/drafts, skill suggestions, and recall cue generation. Embeddings, microphone recognition, and spoken output stay on their existing engines.

For local Worker development only, put GROQ_API_KEY in an ignored `.dev.vars` file. Never include it in Flutter dart-defines.

Deploy the reviewed adapter before installing the live secret. Verify a disposable-account card conversation, name confirmation, ambiguity clarification, skills and bio review before enabling wider usage. Usage logs contain provider/model/token counts only. Groq failures return a retry message without silently falling back to Llama.

Remove the secret to roll back text generation to Workers AI. Free-tier quota exhaustion returns a retry error; no paid billing is required for the initial trial. Current provider rates and quotas should be checked in Groq Console.
