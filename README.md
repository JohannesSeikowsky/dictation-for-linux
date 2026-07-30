# dictation-for-linux

Press Super+Q, talk, press Super+Q again — a couple of seconds later the cleaned-up text is typed
into whatever window has focus. Under the hood `arecord` captures your voice to a wav file,
ElevenLabs Scribe v2 transcribes it, Claude Haiku 4.5 fixes the punctuation and drops the filler
words, and `xdotool` replays the result as keystrokes, which is why it works in any application
rather than one particular editor. The whole thing is a single ~350-line Python script with no
daemon and no background process: each keypress is a one-shot command, and the only state between
the two presses is a pidfile. Run `./setup.sh` to install — X11 only, and the hotkeys bind
themselves on XFCE.
