# FLAC → Opus Batch Converter (Linux)

A robust, high-performance **FLAC to Opus** batch conversion script for
Linux, designed for **very large music libraries**.

This script: - Converts FLAC files to Opus (`opusenc`) - Preserves
directory structure - Runs **artist-by-artist**, in **alphabetical
order** - Uses **all CPU cores by default** - Safely handles filenames
with spaces, Unicode, and special characters - Normalizes **metadata and
filenames to ASCII** - Supports **resume**, **dry-run**, and **database
rebuild** - Produces clean, timestamped logs with per-artist summaries

------------------------------------------------------------------------

## Features

-   Fast & parallel --- defaults to number of CPU cores (`nproc`)
-   Safe for huge libraries
-   Unicode → ASCII metadata normalization
-   ASCII-safe output filenames
-   Resume support using a success database
-   Artist-level progress summaries
-   Timestamped, real-time logging
-   Graceful Ctrl+C handling
-   Dry-run mode
-   Optional deletion of original FLAC files
-   Rebuild success database from existing Opus files

------------------------------------------------------------------------

## Requirements

Install required tools:

``` bash
sudo apt install opus-tools flac ffmpeg parallel
```

Required binaries: - opusenc - metaflac - parallel - iconv - nproc

------------------------------------------------------------------------

## Usage

``` bash
./flac_to_opus.sh SRC_DIR DEST_DIR [options]
```

Example:

``` bash
./flac_to_opus.sh ./music ./music_opus
```

------------------------------------------------------------------------

## Options

  Option                     Description
  -------------------------- ----------------------------------------------------
  --dry-run                  Show what would be converted without writing files
  --delete-originals         Delete FLAC files after successful conversion
  --jobs N                   Override number of parallel jobs
  --rebuild-db               Rebuild success database
  --continue-after-rebuild   Continue converting after rebuild

------------------------------------------------------------------------

## Resume & Logging

-   Success database: `flac_to_opus_success.db`
-   Failed log: `flac_to_opus_failed.log`
-   Timestamped logs: `flac_to_opus_YYYYMMDD_HHMMSS.log`

------------------------------------------------------------------------

## License

GNU GPLv3 License
