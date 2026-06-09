#!/bin/bash
set -euo pipefail

INPUT=""
KEY_COLUMN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --input) INPUT="$2"; shift 2 ;;
        --key_column) KEY_COLUMN="$2"; shift 2 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

: "${INPUT:?Missing --input}"

num() { [[ $1 =~ ^[0-9]+$ ]]; }

HEADER=$(head -1 "$INPUT")

if [ -z "$KEY_COLUMN" ]; then
    KEY_IDX=1
elif num "$KEY_COLUMN"; then
    KEY_IDX=$KEY_COLUMN
else
    KEY_IDX=$(echo "$HEADER" | awk -F'\t' -v k="$KEY_COLUMN" '{ for(i=1;i<=NF;i++) if($i==k) { print i; exit } }')
    : "${KEY_IDX:?key_column not found in header}"
fi

echo "$KEY_IDX"
echo "$HEADER" | awk -F'\t' -v ki="$KEY_IDX" '{ for(i=ki+1;i<=NF;i++) print $i }'
