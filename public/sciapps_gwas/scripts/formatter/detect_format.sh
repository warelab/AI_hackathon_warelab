#!/bin/bash
set -euo pipefail

INPUT="${1:--}"

reader() {
  if [ "$INPUT" = "-" ]; then
    cat
  elif [[ "$INPUT" == *.gz ]]; then
    zcat -f "$INPUT"
  else
    cat "$INPUT"
  fi
}

# Read first two lines (pipefail-safe with || true)
first_line=$(reader | head -1 || true)
second_line=$(reader | head -2 | tail -1 || true)

case "$first_line" in
  "##fileformat=VCF"* | "#CHR"*)
    echo "vcf"
    exit 0
    ;;
  "rs#"* | rs[[:space:]]*)
    result=$(echo "$second_line" | awk '
      {
        count=0
        for(i=12;i<=NF && count<5;i++) {
          gsub(/^[ \t]+/,"",$i)
          if(length($i)==2) { print "regular"; exit }
          if(length($i)==1) count++
        }
        if(count>0) print "iupac"
        else        print "unknown"
        exit
      }
    ' || true)
    echo "hapmap_$result"
    exit 0
    ;;
  *)
    echo "unknown"
    exit 1
    ;;
esac
