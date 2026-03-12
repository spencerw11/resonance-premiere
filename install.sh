#!/bin/bash
# Resonance for Premiere Pro — Remote Installer
# Share this one-liner with colleagues:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/spencerw11/resonance-premiere/main/install.sh)"

REPO="spencerw11/resonance-premiere"
EXT_ID="com.resonance.premiere"
CEP_DIR="$HOME/Library/Application Support/Adobe/CEP/extensions"
DEST="$CEP_DIR/$EXT_ID"

trap 'echo ""; echo "Something went wrong. See error above."' ERR

# ── Approve a binary (strip quarantine + ad-hoc sign) ──────────────────
approve() {
  local f="$1"; [ -f "$f" ] || return 0
  chmod +x "$f"
  xattr -c "$f" 2>/dev/null || true
  codesign --sign - --force "$f" 2>/dev/null || true
}

clear
echo "╔══════════════════════════════════════════╗"
echo "║       Resonance for Premiere Pro         ║"
echo "║             Installer v1.0               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "This will install the Resonance panel and all"
echo "required tools. Takes about 1-3 minutes."
echo ""
read -p "Press Enter to begin..." _
echo ""

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Step 1: Download extension from GitHub ──────────────────────────────
echo "[ 1/5 ] Downloading Resonance..."
curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.zip" \
  -o "$WORK/resonance.zip" --progress-bar
unzip -q "$WORK/resonance.zip" -d "$WORK"
SRC="$WORK/resonance-premiere-main"
BIN="$SRC/bin"
mkdir -p "$BIN"
echo "  Done."

# ── Step 2: yt-dlp ──────────────────────────────────────────────────────
echo ""
echo "[ 2/5 ] Installing yt-dlp..."
curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" \
  -o "$BIN/yt-dlp" --progress-bar
approve "$BIN/yt-dlp"
echo "  Done."

# ── Step 3: ffmpeg ──────────────────────────────────────────────────────
echo ""
echo "[ 3/5 ] Checking ffmpeg..."

FFMPEG_PATH=""
for p in "/opt/homebrew/bin/ffmpeg" "/usr/local/bin/ffmpeg" "/usr/bin/ffmpeg"; do
  [ -f "$p" ] && FFMPEG_PATH="$p" && break
done
command -v ffmpeg &>/dev/null && [ -z "$FFMPEG_PATH" ] && FFMPEG_PATH="$(command -v ffmpeg)"

if [ -z "$FFMPEG_PATH" ]; then
  echo "  Not found — installing via Homebrew..."
  if ! command -v brew &>/dev/null; then
    echo "  Installing Homebrew first..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null || true)"
  fi
  brew install ffmpeg
  FFMPEG_PATH="$(command -v ffmpeg)"
fi

echo "  Found: $FFMPEG_PATH"
FFMPEG_DIR="$(dirname "$FFMPEG_PATH")"
# Symlink into bin/ — preserves Homebrew Developer ID signature (no Gatekeeper issues)
ln -sf "$FFMPEG_PATH"             "$BIN/ffmpeg"
[ -f "$FFMPEG_DIR/ffprobe" ] && ln -sf "$FFMPEG_DIR/ffprobe" "$BIN/ffprobe"
echo "  Done."

# ── Step 4: Whisper ─────────────────────────────────────────────────────
echo ""
echo "[ 4/5 ] Checking Whisper..."

WHISPER_OK=false
for p in "/opt/homebrew/bin/whisper" "/usr/local/bin/whisper" "$(command -v whisper 2>/dev/null)"; do
  [ -f "$p" ] && WHISPER_OK=true && break
done

if ! $WHISPER_OK; then
  echo "  Not found — installing via pip..."
  PIP=""
  command -v pip3 &>/dev/null && PIP="pip3"
  command -v pip  &>/dev/null && [ -z "$PIP" ] && PIP="pip"
  if [ -n "$PIP" ]; then
    $PIP install openai-whisper --quiet \
      && echo "  Done." \
      || echo "  Warning: pip install failed. Run manually: pip3 install openai-whisper"
  else
    echo "  Warning: Python not found. Install Python 3, then: pip3 install openai-whisper"
  fi
fi

for p in "/opt/homebrew/bin/whisper" "/usr/local/bin/whisper" "$(command -v whisper 2>/dev/null)"; do
  approve "$p"
done

# ── Step 5: Install extension ────────────────────────────────────────────
echo ""
echo "[ 5/5 ] Installing Resonance extension..."

mkdir -p "$CEP_DIR"
[ -e "$DEST" ] && rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Re-create symlinks in the installed location (cp doesn't preserve symlinks correctly)
if [ -n "$FFMPEG_PATH" ]; then
  ln -sf "$FFMPEG_PATH"             "$DEST/bin/ffmpeg"
  [ -f "$FFMPEG_DIR/ffprobe" ] && ln -sf "$FFMPEG_DIR/ffprobe" "$DEST/bin/ffprobe"
fi

xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
for f in $(find "$DEST/bin" -type f 2>/dev/null); do
  approve "$f"
done

echo "  Enabling unsigned extension support..."
for v in 8 9 10 11 12 13 14 15; do
  defaults write com.adobe.CSXS.$v PlayerDebugMode 1 2>/dev/null || true
done

echo ""
echo "  Enter the Claude API key (get it from Spencer):"
read -r -p "  API key: " API_KEY
if [ -n "$API_KEY" ]; then
  echo "{\"claudeApiKey\": \"$API_KEY\"}" > "$HOME/.resonance-premiere.json"
  echo "  API key saved."
else
  echo "  Skipped — enter it later in Resonance via the ⚙ settings button."
fi

# ── Done ────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          Installation complete!          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  1. Restart Premiere Pro"
echo "  2. Window → Extensions → Resonance"
echo "  3. You're ready to go."
echo ""
read -p "Press Enter to close..." _
