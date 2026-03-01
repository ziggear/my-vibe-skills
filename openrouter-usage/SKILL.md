---
name: openrouter-usage
description: General notes, limits, and conventions when calling the OpenRouter API. Reference when integrating or modifying OpenRouter calls in any project.
---

# OpenRouter API Conventions and Limits

General rules: notes and constraints to follow when calling OpenRouter in any project.

## 1 Keys and Configuration

- **API Key**: Obtain from https://openrouter.ai; format is `sk-or-v1-xxxxx`.
- **Storage**: Keys must be injected via environment variables or runtime config; never hardcode in code or commit to the repo. In production use the platform's Secrets / environment variable mechanism.
- **Missing or invalid**: Calls will fail; implementations should distinguish "key not configured" from "OpenRouter-returned error" for easier debugging.

## 2 Request Conventions

- **Base URL**: `https://openrouter.ai/api/v1`; chat endpoint is `POST /chat/completions`.
- **Headers**: Must include `Authorization: Bearer <API_KEY>` and `Content-Type: application/json`. Prefer setting `HTTP-Referer` and `X-Title` for OpenRouter analytics and policy.
- **Body**: Compatible with OpenAI Chat Completions. Common fields: `model`, `messages`; optional `temperature`, `max_tokens`, etc. Model IDs per OpenRouter docs (e.g. `openai/gpt-4o-mini`, `anthropic/claude-3.5-sonnet`).

## 3 Message and content Format

- **messages**: Each message's `content` may be a string or a **ContentPart array**. Supports `type: 'text'` and `type: 'input_audio'` (audio input).
- **Multimodal (including audio)**: Text instructions and audio should be in the **same** user message's `content` array (e.g. text then input_audio), ordered per OpenRouter docs, so the model does not treat audio as a separate turn.

## 4 input_audio Limits (Important)

- **Base64 only, no URL**: Audio must be sent in the request body as **base64** in `input_audio.data`; URL-based audio is not supported (you cannot pass only an audio URL).
- **Format**: `input_audio.format` support is **model-dependent**. OpenRouter commonly lists: `wav`, `mp3`, `aiff`, `aac`, `ogg`, `flac`, `m4a`, `pcm16`, `pcm24`. Not every model supports all of these; confirm the chosen model's supported formats in OpenRouter or the model's docs before implementing.
- **Convention**: Client/gateway output format must match the chosen model; server validation should only accept formats supported by the current model to avoid invalid requests.
- **Request fields**: `input_audio` object has `data` (base64 string) and `format` (extension name matching the list above, e.g. `wav`, `m4a`).

## Speech-to-Text Notes

When using OpenRouter for speech-to-text or "transcribe + process by instruction", follow sections 1–4 above and in addition:

- **Model choice**: Use a model that supports audio input, e.g. `openai/gpt-audio-mini`, `openai/gpt-4o-audio-preview`, `google/gemini-2.5-flash`. On [OpenRouter Models](https://openrouter.ai/models) filter by **input modality: audio**; formats, pricing, and quality vary by model—check official docs when choosing.
- **Request structure**: Use an **array** for one user message's `content`, containing:
  - `type: 'text'`: Transcribe instruction or task (e.g. "output only the transcript", "transcribe and lightly clean").
  - `type: 'input_audio'`: `{ data: base64 string, format: extension }` (e.g. `wav`, `m4a`).
  Put text and audio in the same message; order per docs or convention (text then input_audio or vice versa, depending on model behavior).
- **Audio format**: Same as section 4—send `format` according to the **chosen model's** supported list. If the client records m4a, confirm the model supports m4a; otherwise convert to wav/mp3 on client or server before calling OpenRouter.
- **Base64 encoding (edge/Worker)**: In Cloudflare Workers, Deno, browser, or other **non-Node** environments there is no `Buffer`; use Web APIs: `const base64 = btoa(String.fromCharCode(...new Uint8Array(audioBuffer)))` or equivalent loop; do not use `Buffer.from(...).toString('base64')`.
- **Single-request transcription**: For transcription only or "transcribe + template output", one request with `input_audio` is enough; no need to call Whisper then a text model unless the product explicitly requires a two-stage pipeline.
- **Parameter tips**: Pure transcription: `temperature: 0`; set `max_tokens` to expected text length to avoid truncation.
- **Errors and rate limits**: Same as section 6; invalid format or unsupported format returns 4xx; map errors and log in the application layer.

## 5 Parameter Constraints

- **temperature**: Typically 0–2; use 0 for deterministic tasks like transcription.
- **max_tokens**: Set an upper bound as needed; see OpenRouter and per-model docs for limits.
- **model**: Must use a model ID listed in OpenRouter docs; cost and capability vary by model.

## 5.1 Structured JSON and long analysis-style outputs

When the task is to return a **single large JSON** (e.g. segment list with long transcript text per segment), the **entire** response counts toward `max_tokens`. If the expected output is large (e.g. many segments × long text per segment), set `max_tokens` high enough (e.g. 32768 or 65536) or the model may truncate mid-JSON, producing invalid JSON or missing/last fields.

- **Explicit prompt for full content**: For fields that must contain full verbatim content (e.g. per-segment transcript), add instructions like “verbatim extraction, do not summarize or abbreviate” so the model does not shorten with "..." or summaries to save tokens.
- **Pitfall**: Stored input (e.g. full transcript) can be correct while the **returned** segment fields are short; if the UI shows segment content from the model’s JSON, truncation or summarization in that JSON is the usual cause.

## 5.2 Text generation: avoid example leakage

When the task is to **generate one line or short text** from user-provided content (e.g. infer a title, summary, or label from a transcript or document), the model can **echo concrete examples** from the prompt instead of inferring from the user's input.

- **Pitfall**: Putting a specific example first (e.g. "例如：Spark Mobile技术面试") often leads the model to return that same string for every request.
- **Fix**: (1) In the prompt and system message, state explicitly that the output **must be inferred only from the user-provided content** and must not use example names or placeholders from the instructions. (2) Move examples to the **end** of the prompt or phrase them generically (e.g. "某公司 技术面试", "日期 + 类型"). (3) Optionally add a system line like "Do not use example or placeholder text from the instructions; infer from the user's content only."

## 6 Errors and Response Handling

- **Non-2xx HTTP**: Do not return OpenRouter's raw response body or stack to the client; parse and map to unified error codes/messages; log on the server when needed.
- **Success**: Use `choices[0].message.content` for text; `usage` for billing or metrics. `content` may be empty—handle with trim or default.
- **Retries and rate limits**: For 429 or transient failures, decide retry and backoff per product needs; avoid retrying when the key is missing or parameters are wrong so as not to waste quota.

## 7 Billing and Usage

- OpenRouter bills by usage; prices differ by model. Evaluate cost when adding models or increasing `max_tokens`/call frequency.
- Use cheaper models for intermediate steps (e.g. cleaning, transcription) and more expensive ones for final generation; splitting by use case helps control cost.

## References

- Official audio input guide: <https://openrouter.ai/docs/guides/overview/multimodal/audio>
