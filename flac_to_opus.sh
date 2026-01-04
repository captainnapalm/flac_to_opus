#!/usr/bin/env bash
set -u
set -o pipefail

########################################
# Usage:
#   ./flac_to_opus.sh SRC_DIR DEST_DIR [options]
#
# Options:
#   --dry-run
#   --delete-originals
#   --rebuild-db
#   --continue-after-rebuild
#   --jobs N       # override number of parallel conversions per artist
########################################

SRC_DIR="${1:?Source directory required}"
DEST_DIR="${2:?Destination directory required}"
shift 2

DRY_RUN=false
DELETE_ORIGINALS=false
REBUILD_DB=false
CONTINUE_AFTER_REBUILD=false

# Default jobs = number of processors
JOBS=$(nproc)

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --delete-originals) DELETE_ORIGINALS=true ;;
        --rebuild-db) REBUILD_DB=true ;;
        --continue-after-rebuild) CONTINUE_AFTER_REBUILD=true ;;
        --jobs) shift; JOBS="$1" ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

########################################
# Setup logs
########################################

TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="./flac_to_opus_${TIMESTAMP}.log"
SUCCESS_DB="./flac_to_opus_success.db"
FAILED_LOG="./flac_to_opus_failed.log"

mkdir -p "$DEST_DIR"
touch "$SUCCESS_DB" "$FAILED_LOG" "$LOG_FILE"

log() { echo "$@" | tee -a "$LOG_FILE"; }

########################################
# Ctrl+C handling
########################################

cleanup() {
    log "Interrupted. Exiting cleanly."
    exit 130
}
trap cleanup INT

########################################
# Rebuild SUCCESS_DB
########################################

if [ "$REBUILD_DB" = true ]; then
    log "Rebuilding SUCCESS database from existing opus files..."
    : > "$SUCCESS_DB"

    while IFS= read -r -d '' opus; do
        rel="${opus#$DEST_DIR/}"
        echo "$SRC_DIR/${rel%.opus}.flac" | tee -a "$SUCCESS_DB" > /dev/null
    done < <(find "$DEST_DIR" -type f -name '*.opus' -print0)

    sort -u "$SUCCESS_DB" -o "$SUCCESS_DB"
    log "SUCCESS database rebuilt: $(wc -l < "$SUCCESS_DB") entries."

    if [ "$CONTINUE_AFTER_REBUILD" = false ]; then
        log "Exiting after rebuild. Use --continue-after-rebuild to continue conversions."
        exit 0
    fi
fi

########################################
# Conversion function
########################################

convert_flac_to_opus() {
    local src="$1"

    if grep -Fxq "$src" "$SUCCESS_DB"; then
        return 2
    fi

    # Extract and normalize metadata
    local artist album title track
    artist=$(metaflac --show-tag=ARTIST "$src" | sed 's/ARTIST=//' | iconv -f UTF-8 -t ASCII//TRANSLIT)
    album=$(metaflac --show-tag=ALBUM "$src" | sed 's/ALBUM=//' | iconv -f UTF-8 -t ASCII//TRANSLIT)
    title=$(metaflac --show-tag=TITLE "$src" | sed 's/TITLE=//' | iconv -f UTF-8 -t ASCII//TRANSLIT)
    track=$(metaflac --show-tag=TRACKNUMBER "$src" | sed 's/TRACKNUMBER=//')

    # Construct output path and normalize filename
    local rel="${src#$SRC_DIR/}"
    local dst="$DEST_DIR/${rel%.flac}.opus"

    local dst_dir dst_file
    dst_dir="$(dirname "$dst")"
    dst_file="$(basename "$dst" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr -cd '[:alnum:]._ -')"
    dst="$dst_dir/$dst_file"

    mkdir -p "$dst_dir"

    if [ "$DRY_RUN" = true ]; then
        return 0
    fi

    if opusenc --quiet \
        --artist "$artist" \
        --album "$album" \
        --title "$title" \
        --track "$track" \
        --bitrate 128 --vbr --comp 10 "$src" "$dst"; then
        echo "$src" | tee -a "$SUCCESS_DB" > /dev/null
        if [ "$DELETE_ORIGINALS" = true ]; then
            rm -f "$src"
        fi
        return 0
    else
        echo "$src" | tee -a "$FAILED_LOG" > /dev/null
        return 1
    fi
}

export -f convert_flac_to_opus
export SRC_DIR DEST_DIR DRY_RUN DELETE_ORIGINALS SUCCESS_DB FAILED_LOG

########################################
# Main loop — alphabetical artist-level
########################################

mapfile -d '' artist_dirs < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

for artist_dir in "${artist_dirs[@]}"; do
    artist="$(basename "$artist_dir")"

    mapfile -d '' files < <(find "$artist_dir" -type f -name '*.flac' -print0)
    total="${#files[@]}"
    [ "$total" -eq 0 ] && continue

    converted=0
    skipped=0
    failed=0

    status_file=$(mktemp)
    temp_file=$(mktemp)

    # Only add files that need conversion
    for f in "${files[@]}"; do
        if grep -Fxq "$f" "$SUCCESS_DB"; then
            skipped=$((skipped + 1))
            continue
        fi
        printf '%s\0' "$f" >> "$temp_file"
    done

    # Parallel conversion safely with null-delimited filenames
    if [ -s "$temp_file" ]; then
        parallel -0 -j "$JOBS" --will-cite bash -c '
            convert_flac_to_opus "$0"
            echo $? >> "$1"
        ' {} "$status_file" < "$temp_file"
    fi

    # Count results
    while IFS= read -r rc; do
        case "$rc" in
            0) converted=$((converted + 1)) ;;
            1) failed=$((failed + 1)) ;;
            2) skipped=$((skipped + 1)) ;;
        esac
    done < "$status_file"

    rm -f "$temp_file" "$status_file"

    log "[$artist] $converted/$total converted (${skipped} skipped, ${failed} failed)"
done

log "Done."
log "Failed conversions (if any) are in $FAILED_LOG"
