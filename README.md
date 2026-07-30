# dictation-for-linux

Dictation for Linux. Press Super+Q, talk, press Super+Q again — cleaned-up text gets returned. Under the hood `arecord` captures your voice,
ElevenLabs Scribe v2 transcribes it, Claude Haiku 4.5 does a clean up, and `xdotool` replays the result as keystrokes.

The whole thing is a single ~350-line Python script with no daemon and no background process. Run `./setup.sh` to install. Your agent will find the instructions in `CLAUDE.md`.

An ElevenLabs and an Anthropic API key need to be added to `.env`. The estimated cost is roughly $0.09 a day for 20 minutes of dictation.

You can tell your coding agent to set this up for you and to adjust it in whichever way you want.
Maybe you want to use different models? Maybe you want to skip the cleanup step to increase speed? Just tell your agent.
