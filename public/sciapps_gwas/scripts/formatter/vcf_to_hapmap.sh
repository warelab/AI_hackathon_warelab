#!/bin/bash
set -euo pipefail

INPUT_VCF="${1}"
OUTPUT_HMP="${2}"

if [[ -z "$INPUT_VCF" || -z "$OUTPUT_HMP" ]]; then
    echo "Usage: bash vcf_to_hapmap.sh <input.vcf[.gz]> <output.hmp.txt.gz>" >&2
    exit 1
fi

zcat -f "$INPUT_VCF" | awk -F'\t' -v OFS='\t' '
/^##/ { next }
/^#CHROM/ {
    printf "rs#\talleles\tchrom\tpos\tstrand\tassembly#\tcenter\tprotLSID\tassayLSID\tpanelLSID\tQCcode"
    for (i = 10; i <= NF; i++) printf "\t%s", $i
    printf "\n"
    next
}
{
    if (gt_pos == 0) {
        n = split($9, fmt, ":")
        for (i = 1; i <= n; i++) if (fmt[i] == "GT") gt_pos = i
    }
    if (length($4) > 1 || length($5) > 1 || index($5, ",")) next
    ref = $4
    alt = $5
    printf "%s\t%s/%s\t%s\t%s\t+\t.\t.\t.\t.\t.\t.", $3, ref, alt, $1, $2
    for (i = 10; i <= NF; i++) {
        split($i, vals, ":")
        gt = (gt_pos && vals[gt_pos] != "") ? vals[gt_pos] : "./."
        split(gt, alleles, "[/|]")
        if (alleles[1] == "." || alleles[2] == ".") {
            printf "\tNN"
        } else {
            printf "\t%s%s", (alleles[1] == 0 ? ref : alt), (alleles[2] == 0 ? ref : alt)
        }
    }
    printf "\n"
}
' | gzip > "$OUTPUT_HMP"

echo "Wrote: $OUTPUT_HMP"
