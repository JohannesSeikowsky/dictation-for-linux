# dictation-for-linux

Simple dictation for Linux. Press Super+Q, talk, press Super+Q again — cleaned-up text is typed
into whatever window has focus. Under the hood `arecord` captures your voice,
ElevenLabs Scribe v2 transcribes it, Claude Haiku 4.5 does a clean up, and `xdotool` replays the result as keystrokes.

The whole thing is a single ~350-line Python script with no daemon and no background process.
Run `./setup.sh` to install — X11 only, and the hotkeys bind themselves on XFCE.

You can tell your coding agent to set this up for you and also to adjust it in whichever way you want.
Maybe use different models? or skip the cleanup for more speed? Just tell your agent.
