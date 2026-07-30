# dictate

Dictation for Linux that gets the words right. Press a hotkey, speak, press it again — cleaned-up
text is typed into whatever window has focus.

Built as a replacement for [nerd-dictation](https://github.com/ideasman42/nerd-dictation). Same
workflow, much better engine: ElevenLabs Scribe v2 (~3–4% word error rate) instead of VOSK
(~15–20%), plus an LLM pass that fixes punctuation, drops filler words and breaks the text into
paragraphs.

## How it works

```
Super+Q ──► dictate toggle ──► arecord ──► wav
Super+Q ──► dictate toggle ──► Scribe v2 ──► Haiku 4.5 ──► xdotool type
```

No daemon, no background process — each keypress is a one-shot command. State between the two
presses is just a pidfile in `$XDG_RUNTIME_DIR`.

Nothing appears while you talk. Unlike VOSK-based tools there is no live streaming — the text
lands about 2.7 s after you stop. You trade immediacy for getting the words right.

## Models

Transcription is **ElevenLabs Scribe v2** (~3–4% word error rate on English, $0.22/hr of audio),
cleanup is **Claude Haiku 4.5**. That's the tested path. At normal dictation volume the cost is
noise: ~20 minutes of speech a day is about $0.07 on Scribe plus $0.02 for the cleanup.

There are also `groq` (Whisper large-v3-turbo, ~5× cheaper) and `local` (faster-whisper, offline)
backends in `dictate.py`, selected with `DICTATE_BACKEND` — both are written but **untested**, so
treat them as starting points rather than working features.

Swapping in a different transcription or cleanup model is a few lines in `dictate.py`. Point your
coding agent at the file and tell it what you want — `CLAUDE.md` in this repo gives it the context
it needs.

## Requirements

- **X11.** `xdotool` cannot type into other applications under Wayland, so this does not work
  there. Check with `echo $XDG_SESSION_TYPE`.
- `xdotool`, `arecord` (ALSA), `paplay`, `notify-send` — standard on Mint and most Debian desktops
- Python 3.10+
- An ElevenLabs API key, and an Anthropic key if you want the cleanup pass
- Hotkeys are registered automatically on **XFCE** (via `xfconf-query`). On GNOME, KDE or anything
  else `setup.sh` does everything else and prints the two commands to bind by hand.

## Install

```bash
git clone https://github.com/JohannesSeikowsky/dictation-for-linux.git
cd dictation-for-linux
./setup.sh          # venv, deps, config, Super+Q / Super+Shift+Q hotkeys
$EDITOR .env        # ELEVENLABS_API_KEY + ANTHROPIC_API_KEY
```

Then press **Super+Q**, talk, press **Super+Q** again.

## Usage

| Command | What it does |
|---|---|
| `dictate toggle` | Start recording, or stop and type the result. Bound to **Super+Q** |
| `dictate cancel` | Throw away an in-progress recording. Bound to **Super+Shift+Q** |
| `dictate status` | `idle` or `recording` |

A sound and a notification mark the start of recording, the transcription step, and what was typed.

## Configuration

Everything lives in `.env`; see `.env.example` for the full list. The ones worth knowing:

| Variable | Default | Notes |
|---|---|---|
| `DICTATE_BACKEND` | `elevenlabs` | `groq` or `local` — see Models above |
| `DICTATE_LANGUAGE` | `en` | Locking the language is slightly faster and more accurate than auto-detect |
| `DICTATE_CLEANUP` | `1` | `0` types the raw transcript and makes no Anthropic call |
| `DICTATE_INJECT` | `type` | `clipboard` is much faster for long text but needs `xclip` |

`vocab.txt` (copied from `vocab.example.txt` on first setup, and gitignored so it stays yours)
holds terms the recogniser should bias towards — names, jargon, product names. On
Scribe these are sent as **keyterms**, which uses surrounding context rather than blind
find-and-replace, so "eleven labs" becomes "ElevenLabs" without mangling ordinary words. One term
per line.

Spoken cues like "open paren", "new line", "new paragraph" and "underscore" become real characters
(see `REPLACEMENTS` in `dictate.py`); the LLM pass handles the rest of the punctuation.

The cleanup pass is tuned for prose. For dictating **code** it loses indentation and adds stray
line breaks — set `DICTATE_CLEANUP=0` for that.

## Speed

Measured on a 10-second dictation:

| Stage | Time |
|---|---|
| Hotkey → recording starts | 73 ms |
| Scribe v2 transcription | ~1.3 s |
| Haiku cleanup | ~1.2 s |
| Typing it out | ~0.1 s |
| **From stopping to text on screen** | **~2.7 s** |

`DICTATE_CLEANUP=0` roughly halves the wait if you want speed over polish.

## If something goes wrong

A failed transcription never loses your audio — the recording is moved to
`~/.cache/dictate/failed-<timestamp>.wav` and the error is shown in the notification.

| Symptom | Fix |
|---|---|
| "nothing recorded" | Check the default input in `pavucontrol`; test with `arecord -d 3 /tmp/t.wav` |
| 401 from the backend | Key missing or wrong in `.env` |
| Text appears unpunctuated | Cleanup failed — run `dictate toggle` from a terminal to see the error |
| Hotkey does nothing | Re-run `./setup.sh`, or add the shortcut by hand in your keyboard settings |
| Hotkey fires but nothing is typed | Are you on Wayland? `xdotool` only works under X11 |
| Stuck in "recording" | `dictate cancel` |
