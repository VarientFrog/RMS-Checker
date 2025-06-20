# Audio RMS Checker

A macOS shell script to scan a folder of audio files and report their RMS and peak volume levels in a CSV.

## Features

- Supports `.wav`, `.mp3`, `.flac`, `.aiff` files.
- Prompts user to select folder and enter RMS and peak volume thresholds.
- Outputs a CSV report with filename, mean RMS, max volume, and status.
- Highlights files that are too quiet, too loud, or risk clipping.

## Requirements

- macOS
- [ffmpeg](https://ffmpeg.org/) installed and in your PATH
- Bash shell (default on macOS)

## Usage

1. Run the script:

   ```bash
   ./rms_checker.sh
