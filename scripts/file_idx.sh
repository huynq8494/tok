#!/usr/bin/env bash

set -euo pipefail

DIR="$PWD"
INDEX=""
NAME=""
UPDATE_FILE=""
DELETE_FILE=""

usage() {
cat <<EOF
Usage:

Create:
  $0 -p <dir> -i <index> -n <file_name>

Update / Move:
  $0 -p <dir> -i <index> -u <file_name>

Delete:
  $0 -p <dir> -d <file_name>

Examples:

  $0 -p . -i 2 -n yolo.py

  $0 -p . -i 1 -u yolo.py

  $0 -p . -d yolo.py
EOF
exit 1
}

###############################################################################
# argument parsing
###############################################################################

while getopts "p:i:n:u:d:" opt; do
    case "$opt" in
        p) DIR="$OPTARG" ;;
        i) INDEX="$OPTARG" ;;
        n) NAME="$OPTARG" ;;
        u) UPDATE_FILE="$OPTARG" ;;
        d) DELETE_FILE="$OPTARG" ;;
        *) usage ;;
    esac
done

[[ -d "$DIR" ]] || {
    echo "Directory not found: $DIR"
    exit 1
}

###############################################################################
# helpers
###############################################################################

validate_index() {
    [[ "$1" =~ ^[0-9]+$ ]] || {
        echo "Invalid index: $1"
        exit 1
    }

    (( $1 > 0 )) || {
        echo "Index must be greater than 0"
        exit 1
    }
}

list_files_asc() {
    find "$DIR" -maxdepth 1 -type f -printf "%f\n" |
        grep -E '^[0-9]+_' |
        sort -t_ -k1,1n || true
}

list_files_desc() {
    find "$DIR" -maxdepth 1 -type f -printf "%f\n" |
        grep -E '^[0-9]+_' |
        sort -t_ -k1,1nr || true
}

find_target() {
    local name="$1"

    if [[ -f "$DIR/$name" ]]; then
        echo "$DIR/$name"
        return
    fi

    find "$DIR" -maxdepth 1 -type f \
        -name "*_${name}" | head -n 1
}

parse_file() {
    local file
    file=$(basename "$1")

    FILE_INDEX=""
    FILE_NAME="$file"
    FILE_INDEXED=false

    if [[ "$file" =~ ^([0-9]+)_(.+)$ ]]; then
        FILE_INDEX="${BASH_REMATCH[1]}"
        FILE_NAME="${BASH_REMATCH[2]}"
        FILE_INDEXED=true
    fi
}

shift_up_from() {
    local start="$1"

    while read -r file; do
        [[ -z "$file" ]] && continue

        local idx="${file%%_*}"
        local name="${file#*_}"

        if (( idx >= start )); then
            mv "$DIR/$file" "$DIR/$((idx+1))_$name"
        fi
    done < <(list_files_desc)
}

shift_down_from() {
    local start="$1"

    while read -r file; do
        [[ -z "$file" ]] && continue

        local idx="${file%%_*}"
        local name="${file#*_}"

        if (( idx > start )); then
            mv "$DIR/$file" "$DIR/$((idx-1))_$name"
        fi
    done < <(list_files_asc)
}

###############################################################################
# delete index from file
###############################################################################

if [[ -n "$DELETE_FILE" ]]; then

    TARGET=$(find_target "$DELETE_FILE")

    [[ -n "$TARGET" ]] || {
        echo "Indexed file not found: $DELETE_FILE"
        exit 1
    }

    parse_file "$TARGET"

    if ! $FILE_INDEXED; then
        echo "File is already unindexed: $DELETE_FILE"
        exit 0
    fi

    OLD_INDEX="$FILE_INDEX"
    REAL_NAME="$FILE_NAME"

    mv "$TARGET" "$DIR/$REAL_NAME"

    shift_down_from "$OLD_INDEX"

    echo "Removed index from: ${OLD_INDEX}_${REAL_NAME}"

    exit 0
fi

###############################################################################
# create
###############################################################################

if [[ -n "$NAME" ]]; then

    [[ -n "$INDEX" ]] || {
        echo "-i is required"
        exit 1
    }

    validate_index "$INDEX"

    if find "$DIR" -maxdepth 1 -type f \
        -name "${INDEX}_*" | grep -q .; then
        shift_up_from "$INDEX"
    fi

    NEW_FILE="$DIR/${INDEX}_${NAME}"

    [[ ! -e "$NEW_FILE" ]] || {
        echo "File already exists: $(basename "$NEW_FILE")"
        exit 1
    }

    touch "$NEW_FILE"

    echo "Created: $(basename "$NEW_FILE")"
    exit 0
fi

###############################################################################
# update
###############################################################################

if [[ -n "$UPDATE_FILE" ]]; then

    [[ -n "$INDEX" ]] || {
        echo "-i is required"
        exit 1
    }

    validate_index "$INDEX"

    TARGET=$(find_target "$UPDATE_FILE")

    [[ -n "$TARGET" ]] || {
        echo "File not found: $UPDATE_FILE"
        exit 1
    }

    parse_file "$TARGET"

    REAL_NAME="$FILE_NAME"

    #
    # Plain file (yolo.py)
    #
    if ! $FILE_INDEXED; then

        shift_up_from "$INDEX"

        mv "$TARGET" "$DIR/${INDEX}_${REAL_NAME}"

        echo "Moved: ${REAL_NAME} -> ${INDEX}_${REAL_NAME}"
        exit 0
    fi

    OLD_INDEX="$FILE_INDEX"

    #
    # Nothing to do
    #
    if (( INDEX == OLD_INDEX )); then
        echo "No changes"
        exit 0
    fi

    TMP_FILE=$(mktemp "$DIR/.reindex.XXXXXX")

    mv "$TARGET" "$TMP_FILE"

    #
    # Move toward beginning
    #
    if (( INDEX < OLD_INDEX )); then

        while read -r file; do
            [[ -z "$file" ]] && continue

            idx="${file%%_*}"
            name="${file#*_}"

            if (( idx >= INDEX && idx < OLD_INDEX )); then
                mv "$DIR/$file" "$DIR/$((idx+1))_$name"
            fi
        done < <(list_files_desc)

    #
    # Move toward end
    #
    else

        while read -r file; do
            [[ -z "$file" ]] && continue

            idx="${file%%_*}"
            name="${file#*_}"

            if (( idx > OLD_INDEX && idx <= INDEX )); then
                mv "$DIR/$file" "$DIR/$((idx-1))_$name"
            fi
        done < <(list_files_asc)

    fi

    mv "$TMP_FILE" "$DIR/${INDEX}_${REAL_NAME}"

    echo "Moved: ${OLD_INDEX}_${REAL_NAME} -> ${INDEX}_${REAL_NAME}"
    exit 0
fi

usage