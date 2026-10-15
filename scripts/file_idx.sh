#!/usr/bin/env bash

set -euo pipefail

DIR=${PWD}

usage() {
    cat <<EOF
Usage:

Create/Insert:
  $0 -p <dir> -i <index> -n <name>

Update:
  $0 -p <dir> -i <index> -u <file_name>

Delete:
  $0 -p <dir> -d <file_name>
EOF
    exit 1
}

INDEX=""
NAME=""
UPDATE_FILE=""
DELETE_FILE=""

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

[[ -d "$DIR" ]] || { echo "Directory not found: $DIR"; exit 1; }

###############################################################################
# Helpers
###############################################################################

get_index() {
    local f
    f=$(basename "$1")
    [[ "$f" =~ ^([0-9]+)_(.+)$ ]] || return 1
    echo "${BASH_REMATCH[1]}"
}

get_name() {
    local f
    f=$(basename "$1")
    [[ "$f" =~ ^([0-9]+)_(.+)$ ]] || return 1
    echo "${BASH_REMATCH[2]}"
}

shift_up_from() {
    local start="$1"

    find "$DIR" -maxdepth 1 -type f -printf "%f\n" |
        grep -E '^[0-9]+_' |
        sort -t_ -k1,1nr |
        while read -r file; do

            idx="${file%%_*}"
            rest="${file#*_}"

            if (( idx >= start )); then
                mv "$DIR/$file" "$DIR/$((idx + 1))_$rest"
            fi
        done
}

shift_down_from() {
    local start="$1"

    find "$DIR" -maxdepth 1 -type f -printf "%f\n" |
        grep -E '^[0-9]+_' |
        sort -t_ -k1,1n |
        while read -r file; do

            idx="${file%%_*}"
            rest="${file#*_}"

            if (( idx > start )); then
                mv "$DIR/$file" "$DIR/$((idx - 1))_$rest"
            fi
        done
}

###############################################################################
# DELETE
###############################################################################

if [[ -n "$DELETE_FILE" ]]; then

    TARGET=$(find "$DIR" -maxdepth 1 -type f -name "*_${DELETE_FILE}" | head -n 1)

    [[ -n "$TARGET" ]] || {
        echo "File not found: $DELETE_FILE"
        exit 1
    }

    OLD_INDEX=$(get_index "$TARGET")

    rm -f "$TARGET"

    shift_down_from "$OLD_INDEX"

    exit 0
fi

###############################################################################
# CREATE
###############################################################################

if [[ -n "$NAME" ]]; then

    [[ -n "$INDEX" ]] || {
        echo "-i is required"
        exit 1
    }

    EXISTS=$(find "$DIR" -maxdepth 1 -type f -name "${INDEX}_*" | head -n 1)

    if [[ -n "$EXISTS" ]]; then
        shift_up_from "$INDEX"
    fi

    touch "$DIR/${INDEX}_${NAME}"

    exit 0
fi

###############################################################################
# UPDATE
###############################################################################

if [[ -n "$UPDATE_FILE" ]]; then

    [[ -n "$INDEX" ]] || {
        echo "-i is required"
        exit 1
    }

    TARGET=$(find "$DIR" -maxdepth 1 -type f -name "*_${UPDATE_FILE}" | head -n 1)

    [[ -n "$TARGET" ]] || {
        echo "File not found: $UPDATE_FILE"
        exit 1
    }

    OLD_INDEX=$(get_index "$TARGET")

    if (( INDEX == OLD_INDEX )); then
        exit 0
    fi

    BASE_NAME=$(basename "$TARGET")
    REAL_NAME="${BASE_NAME#*_}"

    TMP_FILE="$DIR/.tmp.$$.$REAL_NAME"

    mv "$TARGET" "$TMP_FILE"

    if (( INDEX < OLD_INDEX )); then

        find "$DIR" -maxdepth 1 -type f -printf "%f\n" |
            grep -E '^[0-9]+_' |
            sort -t_ -k1,1nr |
            while read -r file; do

                idx="${file%%_*}"
                rest="${file#*_}"

                if (( idx >= INDEX && idx < OLD_INDEX )); then
                    mv "$DIR/$file" "$DIR/$((idx + 1))_$rest"
                fi
            done

    else

        find "$DIR" -maxdepth 1 -type f -printf "%f\n" |
            grep -E '^[0-9]+_' |
            sort -t_ -k1,1n |
            while read -r file; do

                idx="${file%%_*}"
                rest="${file#*_}"

                if (( idx > OLD_INDEX && idx <= INDEX )); then
                    mv "$DIR/$file" "$DIR/$((idx - 1))_$rest"
                fi
            done
    fi

    mv "$TMP_FILE" "$DIR/${INDEX}_${REAL_NAME}"

    exit 0
fi

usage