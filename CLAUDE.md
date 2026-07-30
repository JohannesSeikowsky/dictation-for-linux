# CLAUDE.md — dictate

Replacement for nerd-dictation. Hotkey → record → cloud STT → Haiku cleanup → xdotool type.
See README.md for user-facing docs; this file is the working context.

## Layout

One file on purpose — the whole thing is ~350 lines and splitting it would add imports without
adding clarity.

| Path | Role |
|---|---|
| `dictate.py` | Everything: state machine, three transcription backends, cleanup, injection |
| `dictate` | Bash wrapper so `myenv/bin/python` is always used regardless of cwd |
| `setup.sh` | venv, deps, XFCE hotkeys via `xfconf-query` |
| `vocab.txt` | Bias terms → Scribe `keyterms` / Groq `prompt` / local `initial_prompt` (gitignored; `vocab.example.txt` is the template) |
| `.env` | Config + API keys (gitignored; `.env.example` is the template) |

## Architecture decisions

- **Cloud STT, not local.** Whisper `large-v3-turbo` on this CPU benchmarked at **0.6× realtime**
  (15 s to transcribe 10 s of speech), `small` at 2.5×. Both unusable interactively. Scribe v2 is
  also more accurate than any Whisper variant on English. `local` remains as an offline fallback.
- **No daemon.** The first design kept a warm faster-whisper model in a daemon behind a unix
  socket, because model load was 3–5 s. With a cloud backend there is nothing to keep warm, so it
  collapsed to a one-shot script with a pidfile. Don't reintroduce the daemon.
- **Toggle, not push-to-talk.** XFCE keyboard shortcuts fire on key *press* only — there is no
  key-release event to hang a "stop" on.
- **`arecord` subprocess, not `sounddevice`.** Avoids the `libportaudio2` system dependency, which
  would need sudo. ALSA is already present.
- **`start()` is import-light.** Only stdlib + dotenv load before `arecord` is spawned, so the
  hotkey feels instant. `httpx` and `anthropic` are imported lazily in the stop path.
- **Failed audio is preserved** to `~/.cache/dictate/failed-*.wav` rather than discarded — losing a
  paragraph of speech to a transient 500 is much worse than a stray file.
- **Replacements run before the LLM pass**, so the model sees real punctuation rather than the
  words "open paren".

## API notes

**ElevenLabs** `POST https://api.elevenlabs.io/v1/speech-to-text`, `xi-api-key` header,
multipart. `model_id=scribe_v2`. $0.22/hr batch.
- `tag_audio_events` defaults to **true** and must be set `"false"` or `(laughter)` etc. get
  inserted into your text.
- `keyterms` is repeated form fields and is **rejected on `scribe_v1`** — guard on the model id.
- Costed extras: keyterm prompting +$0.05/hr, entity detection +$0.07/hr.

**Groq** `POST https://api.groq.com/openai/v1/audio/transcriptions`, `Authorization: Bearer`,
OpenAI-compatible. `whisper-large-v3-turbo` ($0.04/hr, ~216× realtime) or `whisper-large-v3`.
Vocab bias goes in the single `prompt` string, capped around 224 tokens.

**Cleanup** uses `claude-haiku-4-5` ($1/$5 per MTok → ~$0.001 per dictation). Plain
`messages.create` with a system prompt; no thinking, no tools. Haiku 4.5 rejects `effort`.

## Gotchas

- **Line breaks go through the cleanup model as a `⏎` sentinel, not a real `\n`.** Haiku collapses
  actual newlines back into a single paragraph no matter how firmly the system prompt forbids it —
  two prompt revisions failed before the sentinel worked. `restore_newlines()` converts them back
  afterwards. Don't "simplify" this by putting real newlines in the pre-LLM replacements.
- **The transcript must be wrapped in `<transcript>` tags in the user turn.** Bare text made Haiku
  treat any short utterance as a chat opener and answer *"I'm ready to clean up transcripts for
  you. Please share the transcript…"* — which then got typed on screen. Reproduced with `okay`,
  `yes`, `Thank you.`, `.` and a lone `⏎`; silence often transcribes as exactly those. The tags
  plus the closing paragraph of `CLEANUP_SYSTEM` fix it. Don't unwrap them.
- **A whitespace-only user turn is a 400** (`text content blocks must be non-empty`), so `clean()`
  short-circuits on it and `stop()` tests `text.strip()`, not `text`.
- **Cleanup is tuned for prose, not code.** Dictating code through it loses indentation and it
  inserts stray paragraph breaks. Use `DICTATE_CLEANUP=0` for code.
- **httpx `data=` must be a dict, not requests-style `[(k, v)]` tuples** — the tuple form raises
  `sequence item 1: expected a bytes-like object, tuple found`. For repeated fields (`keyterms`)
  use a dict whose value is a **list**. This bit once already.
- `xdotool type` needs `--clearmodifiers`; without it the modifier still held from the hotkey
  corrupts the output.
- Recording is 16 kHz mono s16le → 32 KB/s. The `< 2000` byte check in `stop()` is the
  "you didn't actually record anything" guard.
- Scribe accepts `file_format=pcm_s16le_16` for lower latency, which matches what `arecord`
  produces — would need `-t raw` and skipping the wav container. Untried optimization.

## Verification status (2026-07-30)

Verified green with real keys: Scribe v2 transcription, Haiku cleanup across prose / email /
plain-speech cases, sentinel newline round trip, record → stop → error handling → audio
preservation, `cancel`, stale pidfile recovery, `status`, hotkey registration.

Measured latency (10 s clip): hotkey→recording **73 ms**; Scribe **1.3 s** median; Haiku **1.2 s**
mean; typing ~0.1 s. **~2.7 s total** from stopping to text on screen.

**Untested:** the `groq` and `local` backends. They are written but have never run against a real
key or model — the README says so, so don't quietly present them as working. A dummy Groq key
returned `403 Access denied` rather than a 401, which may just have been a network block from the
dev machine; recheck with a real key before concluding anything.

## Environment assumptions

- **X11 only.** `xdotool` cannot type into other windows under Wayland. Developed on Linux Mint /
  XFCE / PipeWire, which is also the only desktop `setup.sh` can bind hotkeys on (`xfconf-query`).
- `DICTATE_INJECT=type` is the default because `xclip` is not installed everywhere. Clipboard
  injection is much faster for long text if you have it.
- `myenv` is deliberately minimal (~70 MB): `httpx`, `anthropic`, `python-dotenv` and their
  transitive deps only. **`faster-whisper` is NOT installed**, so `DICTATE_BACKEND=local` fails
  until you run `./myenv/bin/pip install -r requirements-local.txt`. Don't reinstall it casually —
  it pulls in ~1 GB of model cache and the cloud backends are the tested path.
- `vocab.txt` is gitignored and personal; `vocab.example.txt` is the tracked template that
  `setup.sh` copies. Never commit the former.
