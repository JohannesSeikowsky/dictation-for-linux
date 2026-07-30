#!/usr/bin/env bash
# One-shot setup: venv, deps, .env, hotkey.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
DIR="$PWD"

echo "== venv =="
[ -d myenv ] || python3 -m venv myenv
./myenv/bin/pip install -q --upgrade pip
./myenv/bin/pip install -q -r requirements.txt

echo "== config =="
[ -f .env ] || { cp .env.example .env; echo "created .env — add your ELEVENLABS_API_KEY"; }
[ -f vocab.txt ] || { cp vocab.example.txt vocab.txt; echo "created vocab.txt — add your own jargon"; }

chmod +x dictate dictate.py

if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  echo "!! Wayland session detected — xdotool cannot type into other windows. This needs X11."
fi

echo "== hotkeys =="
if command -v xfconf-query >/dev/null; then
  set_shortcut() {  # $1 = key combo, $2 = command
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$1" -n -t string -s "$2" \
      2>/dev/null || xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$1" -s "$2"
  }
  set_shortcut '<Super>q' "$DIR/dictate toggle"
  set_shortcut '<Super><Shift>q' "$DIR/dictate cancel"
  HOTKEY_NOTE="  2. Super+Q to start dictating, Super+Q again to transcribe and type
     Super+Shift+Q discards a recording"
else
  HOTKEY_NOTE="  2. no xfconf-query, so this isn't XFCE — bind these two by hand in your
     desktop's keyboard settings:
       Super+Q        $DIR/dictate toggle
       Super+Shift+Q  $DIR/dictate cancel"
fi

cat <<EOF

Done. Next:
  1. put your ELEVENLABS_API_KEY (and ANTHROPIC_API_KEY) in $DIR/.env
$HOTKEY_NOTE

No daemon to run — each press is a one-shot command.
EOF
