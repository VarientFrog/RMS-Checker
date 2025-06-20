#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# --- Accept drag-and-drop or show folder picker ---
if [[ -z "$1" ]]; then
  INPUT_DIR=$(osascript -e 'POSIX path of (choose folder with prompt "Select the folder containing audio files:")')
else
  INPUT_DIR="$1"
fi

INPUT_DIR="${INPUT_DIR%/}"

if [[ ! -d "$INPUT_DIR" ]]; then
  osascript -e 'display dialog "❌ Invalid folder path. Please select or drop a valid folder." buttons {"OK"}'
  exit 1
fi

# --- Prompt for RMS thresholds ---
MIN_RMS=$(osascript -e 'text returned of (display dialog "Enter minimum RMS (e.g. -23):" default answer "-23")')
MAX_RMS=$(osascript -e 'text returned of (display dialog "Enter maximum RMS (e.g. -18):" default answer "-18")')
MAX_PEAK=$(osascript -e 'text returned of (display dialog "Enter maximum peak volume (e.g. -3):" default answer "-3")')

# --- Validate numeric inputs ---
if ! [[ "$MIN_RMS" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ "$MAX_RMS" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ "$MAX_PEAK" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
  osascript -e 'display dialog "❌ One or more threshold values were not valid numbers." buttons {"OK"}'
  exit 1
fi

# --- Prepare output ---
OUTPUT_CSV="$INPUT_DIR/rms_report.csv"
DEBUG_LOG="$HOME/Desktop/rms_debug.log"
echo "Filename,Mean RMS (dB),Max Volume (dB),Status" > "$OUTPUT_CSV"
echo "=== RMS Analysis Log ===" > "$DEBUG_LOG"

# --- Process audio files ---
find "$INPUT_DIR" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.aiff" \) | while read -r f; do
  echo "=== $f ===" >> "$DEBUG_LOG"
  RMS=$(ffmpeg -hide_banner -nostats -t 30 -i "$f" -af volumedetect -f null /dev/null 2>&1)
  echo "$RMS" >> "$DEBUG_LOG"

  MEAN=$(echo "$RMS" | grep 'mean_volume' | awk '{print $5}')
  PEAK=$(echo "$RMS" | grep 'max_volume' | awk '{print $5}')
  STATUS="✅ OK"

  if [[ -n "$MEAN" && -n "$PEAK" ]]; then
    if (( $(echo "$MEAN < $MIN_RMS" | bc -l) )); then
      STATUS="❌ Too quiet (< $MIN_RMS)"
    elif (( $(echo "$MEAN > $MAX_RMS" | bc -l) )); then
      STATUS="❌ Too loud (> $MAX_RMS)"
    elif (( $(echo "$PEAK > $MAX_PEAK" | bc -l) )); then
      STATUS="❌ Clipping risk (> $MAX_PEAK)"
    fi
  else
    STATUS="⚠️ No audio or ffmpeg error"
  fi

  # Clean relative path fallback
  if [[ "$f" == "$INPUT_DIR"* ]]; then
    RELATIVE_PATH="${f#$INPUT_DIR/}"
  else
    RELATIVE_PATH="$(basename "$f")"
  fi

  echo "$RELATIVE_PATH,$MEAN,$PEAK,$STATUS" >> "$OUTPUT_CSV"
  echo "Processed $RELATIVE_PATH - $STATUS"
done

open "$OUTPUT_CSV"
