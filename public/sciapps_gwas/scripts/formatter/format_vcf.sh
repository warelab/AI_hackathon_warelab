#!/bin/bash
set -euo pipefail

while [[ $# -gt 0 ]]; do
    case $1 in
        --input) INPUT="$2"; shift 2 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

: "${INPUT:?Missing --input}"

base=$(basename "$INPUT")
stem=${base%.gz}

if [[ "$INPUT" == *.gz ]]; then
    GZIPPED=true
else
    GZIPPED=false
fi

proc() {
    awk -F'\t' -v OFS='\t' '
/^##/ { print; next }
/^#CHROM/ {
    for (i=10; i<=NF; i++) {
        gsub(/_/, "", $i)
    }
    print; next
}
{
    # skip indels (multi-char REF or ALT, or ALT containing ",")
    if (length($4) > 1 || length($5) > 1 || index($5, ",")) next

    if ($3 == ".") {
        c = $1; sub(/^Chr/, "", c); c += 0
        $3 = sprintf("S%02d_%s", c, $2)
    }
    print
}
'
}

run_proc() {
    if [[ "$GZIPPED" == true ]]; then
        zcat "$INPUT" | proc | gzip
    else
        proc < "$INPUT"
    fi
}

indir=$(dirname "$INPUT")
if [[ "$indir" == "." || "$indir" == "$PWD" ]]; then
    temp=$(mktemp "$INPUT.XXXXXX")
    run_proc > "$temp"
    mv "$INPUT" "${INPUT}.bak"
    mv "$temp" "$INPUT"
    final="$INPUT"
else
    output="$PWD/$stem"
    [[ "$GZIPPED" == true ]] && final="${output}.gz" || final="$output"
    run_proc > "$final"
fi

echo "Wrote: $final"
