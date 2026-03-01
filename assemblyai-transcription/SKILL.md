---
name: assemblyai-transcription
description: AssemblyAI speech transcription with speaker diarization and timestamps. Use when integrating AssemblyAI for audio-to-text, speaker labels (A/B/C), or playback-synced transcripts. Covers REST vs SDK config alignment, common API pitfalls, and verification with real data.
---

# AssemblyAI Speech Transcription, Speaker Diarization, and Timestamps

Summary from real-world usage: configuration and gotchas when using AssemblyAI for transcription with **speaker diarization** and **timestamps (start/end)**.

---

## Capabilities Overview

| Capability | Description | Required params |
|------------|-------------|-----------------|
| Speech transcription | Audio → text | Required |
| Speaker diarization | Distinguish speakers A/B/C, etc. | `speaker_labels: true` |
| Timestamps | start/end per utterance (milliseconds) | Same as above, plus correct `speech_models` / `language_*` |

**Important**: Enabling `speaker_labels` alone does not guarantee timestamps. Request parameters must match the "Recommended config" below, or the API may return empty `utterances` or errors.

---

## Recommended Config (keep REST and SDK aligned)

### REST API (POST /v2/transcript body)

```json
{
  "audio_url": "<URL from upload response>",
  "speaker_labels": true,
  "language_detection": true,
  "speech_models": ["universal-3-pro", "universal-2"]
}
```

### Python SDK

```python
config = aai.TranscriptionConfig(
    speech_models=["universal-3-pro", "universal-2"],
    language_detection=True,
    speaker_labels=True,
)
transcript = aai.Transcriber(config=config).transcribe(audio_file)
# transcript.utterances[i].start / .end are in milliseconds
```

- **Do not** send both `language_code` and `language_detection: true`; the API returns: `language_detection is not available when language_code is specified`.
- **Do not** use only `speech_models: ["universal-2"]` without `language_detection`; you may not get `utterances` with `start`/`end`.

---

## Common Issues and Notes

### 1. No timestamps / empty utterances

- **Cause**: Request params differ from the recommended config (e.g. only universal-2, no language_detection, or wrong language_code).
- **Fix**: Use the config above exactly. For REST, read `data["utterances"]` and use `u["start"]`, `u["end"]` (milliseconds).

### 2. 400 on submit / language_detection vs language_code conflict

- **Cause**: Request includes both `language_code` (e.g. `"en"`) and `language_detection: true`.
- **Fix**: Use one or the other. For auto language detection, keep only `language_detection: true` and omit `language_code`.

### 3. 401 / upload failure

- **Cause**: Invalid or missing API key. REST requires header `Authorization: <api_key>` (no "Bearer " prefix).
- **Fix**: Check `ASSEMBLYAI_API_KEY` in env or config and ensure the key is valid.

### 4. utterances much shorter than top-level text

- Sometimes the concatenated `utterances` text is much shorter than the top-level `text`; storing only utterances can lose content.
- **Fix**: If `len(text) > max(800, len(utterances_text) * 2)`, use the top-level `text` as the full transcript and keep utterances for timestamps and speaker alignment.

### 5. REST vs SDK behaviour mismatch

- **Fix**: Keep REST request params (speech_models, language_detection, speaker_labels) in sync with the SDK `TranscriptionConfig` so a local SDK demo can validate before REST integration.

---

## Response Shape (REST GET /v2/transcript/{id})

- **status**: `"completed"` when done; check **error** when `"error"`.
- **text**: Full transcript (string).
- **utterances**: Present only when `speaker_labels: true` and config is correct; each item example:

```json
{
  "speaker": "A",
  "text": "Hello, welcome.",
  "start": 1000,
  "end": 2500
}
```

- `start` / `end` are in **milliseconds**. Divide by 1000 for seconds downstream.
- Speakers are typically `"A"`, `"B"`, `"C"`; map to business labels (e.g. Interviewer A / Candidate) as needed.

---

## Verification: use real data

Before claiming "API returns timestamps" or "playback highlight works", **verify with real data**—do not rely only on reading code or asking the user to check:

1. **Query DB**: For the current environment, query the latest transcript/segments row and confirm `start_time`/`end_time` and per-line `start`/`end` are set (escape SQL reserved words like `index`).
2. **Real request**: Run "upload → transcribe → fetch detail" with a real or test audio file and inspect the response JSON for non-empty `start`/`end` in `utterances` or segments.

---

## Unit test suggestion

- Mock the API to return `utterances` with `start` and `end`; assert that your service output includes `start_ms`/`end_ms` (or equivalent) so parameter changes do not silently drop timestamps.

---

## References

- In-repo summary: `docs/ASSEMBLYAI_TIMESTAMPS_FIX.md`
- Standalone demo: `demo_assemblyai_transcribe.py` (defaults to `hr_screen_call.m4a` in repo root)
- AssemblyAI docs: https://www.assemblyai.com/docs
