#!/bin/bash
# Resonance — Premiere Pro Extension Installer
# Run once. Then open Premiere > Window > Extensions > Resonance.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_ID="com.resonance.premiere"
CEP_DIR="$HOME/Library/Application Support/Adobe/CEP/extensions"
DEST="$CEP_DIR/$EXT_ID"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Resonance — Extension Installer    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Copy extension files ───────────────────────────────────────────
mkdir -p "$CEP_DIR"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  echo "→ Removing previous installation..."
  rm -rf "$DEST"
fi

echo "→ Installing extension..."
cp -R "$SCRIPT_DIR" "$DEST"
echo "  $DEST"

# ── 2. Enable unsigned extensions (debug mode) ────────────────────────
echo ""
echo "→ Enabling debug mode for unsigned extensions..."
for v in 8 9 10 11 12 13 14 15; do
  defaults write com.adobe.CSXS.$v PlayerDebugMode 1 2>/dev/null || true
done
echo "  Done."

# ── 3. Check required binaries ────────────────────────────────────────
echo ""
echo "→ Checking required tools..."

check_binary() {
  local name="$1"
  if command -v "$name" &>/dev/null; then
    echo "  ✓ $name  ($(command -v $name))"
    return 0
  fi
  for p in "/usr/local/bin/$name" "/opt/homebrew/bin/$name" "/usr/bin/$name"; do
    if [ -f "$p" ]; then
      echo "  ✓ $name  ($p)"
      return 0
    fi
  done
  echo "  ✗ $name  NOT FOUND"
  return 1
}

MISSING=()
check_binary "yt-dlp"  || MISSING+=("yt-dlp")
check_binary "ffmpeg"  || MISSING+=("ffmpeg")
check_binary "whisper" || check_binary "whisper.cpp" || MISSING+=("whisper")

# ── 4. Offer to install missing tools ────────────────────────────────
if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "  Missing: ${MISSING[*]}"
  echo ""
  read -p "  Install missing tools now via Homebrew/pip? [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! command -v brew &>/dev/null; then
      echo "  Homebrew not found. Install from https://brew.sh then re-run this script."
    else
      for tool in "${MISSING[@]}"; do
        if [ "$tool" = "whisper" ]; then
          echo "  Installing openai-whisper via pip..."
          pip3 install openai-whisper 2>/dev/null || \
          pip install openai-whisper 2>/dev/null || \
          echo "  ✗ pip not available — install Python 3 first, then: pip3 install openai-whisper"
        else
          echo "  brew install $tool..."
          brew install "$tool"
        fi
      done
    fi
  else
    echo "  Install them manually before using the extension:"
    for tool in "${MISSING[@]}"; do
      if [ "$tool" = "whisper" ]; then
        echo "    pip3 install openai-whisper"
      else
        echo "    brew install $tool"
      fi
    done
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║         Installation complete!       ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Restart Premiere Pro"
echo "  2. Window → Extensions → Resonance"
echo "  3. Click ⚙ and enter your Claude API key"
echo "     (get one free at console.anthropic.com)"
echo ""
