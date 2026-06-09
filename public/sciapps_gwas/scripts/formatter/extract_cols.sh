#!/bin/bash
set -euo pipefail

while [[ $# -gt 0 ]]; do
    case $1 in
        --input) INPUT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --key_column) KEY_COL="$2"; shift 2 ;;
        --value_column) VALUE_COL="$2"; VALUE_COL_PROVIDED=1; shift 2 ;;
        --header_lines) HEADER_LINES="$2"; shift 2 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

: "${INPUT:?Missing --input}"
KEY_COL="${KEY_COL:-1}"
VALUE_COL="${VALUE_COL:-2}"
HEADER_LINES="${HEADER_LINES:-1}"

base=$(basename "$INPUT")
name=${base%%.*}
if [ -z "${VALUE_COL_PROVIDED:-}" ]; then
  OUTPUT="${OUTPUT:-${name}_default.txt}"
else
  OUTPUT="${OUTPUT:-${name}_${VALUE_COL}.txt}"
fi

num() { [[ $1 =~ ^[0-9]+$ ]]; }

if num "$KEY_COL"; then
    KI="$KEY_COL"
else
    KI=$(head -1 "$INPUT" | awk -F'\t' -v k="$KEY_COL" '{ for(i=1;i<=NF;i++) if($i==k) print i }')
    : "${KI:?key_column not found}"
fi

if num "$VALUE_COL"; then
    VI="$VALUE_COL"
else
    VI=$(head -1 "$INPUT" | awk -F'\t' -v v="$VALUE_COL" '{ for(i=1;i<=NF;i++) if($i==v) print i }')
    : "${VI:?value_column not found}"
fi

awk -F'\t' -v ki="$KI" -v vi="$VI" -v h="$HEADER_LINES" '
NR == 1 { val_hdr = $vi; print "<Trait>\t" val_hdr }
NR > h  { print $ki "\t" $vi }
' "$INPUT" > "$OUTPUT" || exit 1
