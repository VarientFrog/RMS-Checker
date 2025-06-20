#!/bin/bash

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if [[ -z "$1" ]]; then
  INPUT_DIR=$(osascript -e 'POSIX path of (choose folder with prompt "Select the folder containing audio files:")')
else
  INPUT_DIR="$1"
fi

INPUT_DIR="${INPUT_DIR%/}"  # remove trailing slash
INPUT_DIR="${INPUT_DIR%/}"

if [[ ! -d "$INPUT_DIR" ]]; then
  osascript -e 'display dialog "❌ Invalid folder path. Please drop a valid folder onto the app." buttons {"OK"}'
  exit 1
fi

# Prompt user for RMS thresholds
MIN_RMS=$(osascript -e 'text returned of (display dialog "Enter minimum RMS (e.g. -23):" default answer "-23")')
MAX_RMS=$(osascript -e 'text returned of (display dialog "Enter maximum RMS (e.g. -18):" default answer "-18")')
MAX_PEAK=$(osascript -e 'text returned of (display dialog "Enter maximum peak volume (e.g. -3):" default answer "-3")')

# Check if inputs are numbers
if ! [[ "$MIN_RMS" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ "$MAX_RMS" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || \
   ! [[ "$MAX_PEAK" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
  osascript -e 'display dialog "❌ One or more threshold values were not valid numbers." buttons {"OK"}'
  exit 1
fi

# Output file
OUTPUT_CSV="$INPUT_DIR/rms_report.csv"
echo "Filename,Mean RMS (dB),Max Volume (dB),Status" > "$OUTPUT_CSV"

# Start analysis
find "$INPUT_DIR" -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.aiff" \) | while read -r f; do
  RMS=$(ffmpeg -hide_banner -nostats -i "$f" -af volumedetect -f null /dev/null 2>&1)
MEAN=$(echo "$RMS" | grep 'mean_volume' | awk '{print $5}')
PEAK=$(echo "$RMS" | grep 'max_volume' | awk '{print $5}')
  MEAN=$(echo "$RMS" | grep mean_volume | awk '{print $5}')
  PEAK=$(echo "$RMS" | grep max_volume | awk '{print $5}')
  STATUS="✅ OK"

  # Only evaluate if MEAN and PEAK are present
  if [[ -n "$MEAN" && -n "$PEAK" ]]; then
    if (( $(echo "$MEAN < $MIN_RMS" | bc -l) )); then
      STATUS="❌ Too quiet (< $MIN_RMS)"
    elif (( $(echo "$MEAN > $MAX_RMS" | bc -l) )); then
      STATUS="❌ Too loud (> $MAX_RMS)"
    elif (( $(echo "$PEAK > $MAX_PEAK" | bc -l) )); then
      STATUS="❌ Clipping risk (> $MAX_PEAK)"
    fi
  else
    STATUS="⚠️ RMS data unavailable"
  fi

  RELATIVE_PATH="${f#$INPUT_DIR/}"
  echo "$RELATIVE_PATH,$MEAN,$PEAK,$STATUS" >> "$OUTPUT_CSV"
  echo "Processed $RELATIVE_PATH - $STATUS"
done

open "$OUTPUT_CSV"
