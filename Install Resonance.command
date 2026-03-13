#!/bin/bash
# Resonance — Installer


trap 'echo ""; echo "Something went wrong. See error above."; read -p "Press Enter to close..." _' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
EXT_ID="com.resonance.premiere"
CEP_DIR="$HOME/Library/Application Support/Adobe/CEP/extensions"
DEST="$CEP_DIR/$EXT_ID"

# Approve a binary: strip all extended attributes + ad-hoc sign
approve_binary() {
  local bin="$1"
  [ -f "$bin" ] || return 0
  chmod +x "$bin"
  xattr -c "$bin" 2>/dev/null || true
  codesign --sign - --force "$bin" 2>/dev/null || true
}

# Strip quarantine from this installer and the whole folder first
xattr -dr com.apple.quarantine "$SCRIPT_DIR" 2>/dev/null || true

clear
echo "╔══════════════════════════════════════════╗"
echo "║       Resonance for Premiere Pro         ║"
echo "║             Installer v1.0               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "This will install the Resonance panel and all"
echo "required tools. Takes 1-3 minutes."
echo ""
read -p "Press Enter to begin..." _
echo ""

# ── Step 1: yt-dlp ────────────────────────────────────────────────────
echo "[ 1/4 ] Installing yt-dlp..."
mkdir -p "$BIN_DIR"
YTDLP_BIN="$BIN_DIR/yt-dlp"
if [ ! -f "$YTDLP_BIN" ] || [ ! -s "$YTDLP_BIN" ]; then
  echo "  Downloading yt-dlp..."
  curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" \
    -o "$YTDLP_BIN" --progress-bar
  chmod +x "$YTDLP_BIN"
fi
approve_binary "$YTDLP_BIN"
echo "  Done."

# ── Step 2: ffmpeg ────────────────────────────────────────────────────
echo ""
echo "[ 2/4 ] Checking ffmpeg..."

# Detect Homebrew prefix (Apple Silicon vs Intel)
BREW_PREFIX=""
[ -d "/opt/homebrew" ] && BREW_PREFIX="/opt/homebrew"
[ -d "/usr/local/Homebrew" ] && BREW_PREFIX="/usr/local"

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
    BREW_PREFIX="$(brew --prefix 2>/dev/null)"
  fi
  brew install ffmpeg
  FFMPEG_PATH="$(command -v ffmpeg || echo ${BREW_PREFIX}/bin/ffmpeg)"
fi

echo "  Found: $FFMPEG_PATH"
FFMPEG_DIR="$(dirname "$FFMPEG_PATH")"

# Copy ffmpeg + ffprobe into bin/ so the extension finds them alongside yt-dlp
# (Homebrew binaries can't be re-signed in place — a fresh copy can be)
echo "  Copying to extension bin/..."
cp "$FFMPEG_PATH" "$BIN_DIR/ffmpeg"
[ -f "$FFMPEG_DIR/ffprobe" ] && cp "$FFMPEG_DIR/ffprobe" "$BIN_DIR/ffprobe"

# Strip ALL extended attributes then ad-hoc sign — same treatment as yt-dlp
for bin in "$BIN_DIR/ffmpeg" "$BIN_DIR/ffprobe"; do
  [ -f "$bin" ] || continue
  chmod +x "$bin"
  xattr -c "$bin" 2>/dev/null || true
  codesign --sign - --force "$bin" 2>/dev/null || true
done
echo "  Done."

# ── Step 3: whisper ───────────────────────────────────────────────────
echo ""
echo "[ 3/4 ] Checking whisper..."
WHISPER_OK=false
command -v whisper &>/dev/null && WHISPER_OK=true
[ -f "/opt/homebrew/bin/whisper" ] && WHISPER_OK=true

if ! $WHISPER_OK; then
  echo "  Not found — installing via pip..."
  PIP=""
  command -v pip3 &>/dev/null && PIP="pip3"
  command -v pip  &>/dev/null && [ -z "$PIP" ] && PIP="pip"
  if [ -n "$PIP" ]; then
    $PIP install openai-whisper --quiet && echo "  Done." || \
      echo "  Warning: pip failed. Run manually: pip3 install openai-whisper"
  else
    echo "  Warning: Python not found. Install Python 3, then: pip3 install openai-whisper"
  fi
fi

for p in "/opt/homebrew/bin/whisper" "/usr/local/bin/whisper" "$(command -v whisper 2>/dev/null)"; do
  approve_binary "$p"
done

# ── Step 4: Install extension ─────────────────────────────────────────
echo ""
echo "[ 4/4 ] Installing Resonance extension..."
mkdir -p "$CEP_DIR"
[ -e "$DEST" ] && rm -rf "$DEST"
[ -L "$DEST" ] && rm -rf "$DEST"
cp -R "$SCRIPT_DIR" "$DEST"

# Strip quarantine + approve every binary in the installed extension
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
for f in $(find "$DEST/bin" -type f 2>/dev/null); do
  approve_binary "$f"
done

echo "  Enabling unsigned extension support..."
for v in 8 9 10 11 12 13 14 15; do
  defaults write com.adobe.CSXS.$v PlayerDebugMode 1 2>/dev/null || true
done


# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          Installation complete!          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  1. Restart Premiere Pro"
echo "  2. Window -> Extensions -> Resonance"
echo "  3. You're ready to go."
echo ""
read -p "Press Enter to close..." _
