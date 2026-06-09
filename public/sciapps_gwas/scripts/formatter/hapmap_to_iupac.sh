#!/bin/bash
set -euo pipefail

INPUT_HMP="$1"
OUTPUT_HMP="$2"

if [[ -z "$INPUT_HMP" || -z "$OUTPUT_HMP" ]]; then
  echo "Usage: bash hapmap_to_iupac.sh <input.hmp.txt[.gz]> <output.hmp.txt[.gz]>" >&2
  exit 1
fi

conv() {
  awk -F'\t' -v OFS='\t' '
  {
    for (i = 1; i <= NF; i++) {
      if (i > 11) {
        gsub(/AA/,"A",$i); gsub(/CC/,"C",$i); gsub(/GG/,"G",$i); gsub(/TT/,"T",$i)
        gsub(/AC|CA/,"M",$i); gsub(/AG|GA/,"R",$i); gsub(/AT|TA/,"W",$i)
        gsub(/CG|GC/,"S",$i); gsub(/CT|TC/,"Y",$i); gsub(/GT|TG/,"K",$i)
        gsub(/NN/,"N",$i)
      }
      printf "%s%s", $i, (i < NF ? OFS : "")
    }
    printf "\n"
  }'
}

if [[ "$INPUT_HMP" == *.gz ]]; then
  zcat "$INPUT_HMP" | conv | gzip > "$OUTPUT_HMP"
else
  conv < "$INPUT_HMP" > "$OUTPUT_HMP"
fi
