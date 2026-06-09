#!/bin/bash
set -euo pipefail

INPUT_F=${h}
extension="${INPUT_F##*.}"
if [ "${extension}" == "gz" ]; then gunzip "${INPUT_F}"; INPUT_F="${INPUT_F%.*}"; fi

Transform=${numericalGenoTransform}
OUTPUT=nt1_marker.txt
MINFREQ=${minfreq}
MARKERFORMAT=${markerformat}

INPUT_M=${mapfile:-}
if [ -n "${INPUT_M}" ]; then
        INPUT_MF=$(basename "${INPUT_M}")
fi

case ${MARKERFORMAT} in
        "Hapmap")         F_FLAG="-h";;
        "HDF5")           F_FLAG="-h5";;
        "VCF")            F_FLAG="-vcf";;
        "Plink")          F_FLAG="-plink -map ${INPUT_MF} -ped";;
        "Flapjack")       F_FLAG="-flapjack -map ${INPUT_MF} -geno";;
esac

INPUT_FF="${INPUT_F}"
if [ -n "${MINFREQ}" ]; then
    run_pipeline.pl -Xms32g -Xmx128g -fork1 "${F_FLAG}" "${INPUT_F}" -filterAlign -filterAlignMinFreq "${MINFREQ}" -export filters.hmp.txt -runfork1
    if [ -f "filters.hmp.txt" ]; then
        INPUT_FF="filters.hmp.txt"
    elif [ -f "filters1.hmp.txt" ]; then
        INPUT_FF="filters1.hmp.txt"
    fi
fi

run_pipeline.pl -Xms32g -Xmx128g -fork1 "${F_FLAG}" "${INPUT_FF}" -NumericalGenotypePlugin -endPlugin -export "${OUTPUT}" -runfork1
mv "${OUTPUT}.hmp.txt" "${OUTPUT}"

# remove first two lines
tail -n+3 "${OUTPUT}" > temp

# replacing
sed -i 's/0\.0/0/g' temp
sed -i 's/1\.0/1/g' temp
sed -i 's/NaN/-9/g' temp
sed -i 's/0\.5/-9/g' temp
sed -i 's/<Trait>//g' temp
mv temp "${OUTPUT}"

# generate tped for emmax
# convert hapmap format to plink format (bypass TASSEL Plink export)
awk -v plink_prefix="${INPUT_F}.plk" '
BEGIN { OFS="\t" }
NR == 1 {
    for(i = 12; i <= NF; i++) samples[++n] = $i
    next
}
{
    print $3, $1, -9, $4 > plink_prefix ".map"
    for(i = 12; i <= NF; i++) {
        a1 = substr($i, 1, 1)
        if(a1 == "A"||a1=="a") { a1="A"; a2="A" }
        else if(a1 == "C"||a1=="c") { a1="C"; a2="C" }
        else if(a1 == "G"||a1=="g") { a1="G"; a2="G" }
        else if(a1 == "T"||a1=="t") { a1="T"; a2="T" }
        else if(a1 == "R"||a1=="r") { a1="A"; a2="G" }
        else if(a1 == "Y"||a1=="y") { a1="C"; a2="T" }
        else if(a1 == "S"||a1=="s") { a1="G"; a2="C" }
        else if(a1 == "W"||a1=="w") { a1="A"; a2="T" }
        else if(a1 == "K"||a1=="k") { a1="G"; a2="T" }
        else if(a1 == "M"||a1=="m") { a1="A"; a2="C" }
        else { a1=0; a2=0 }
        g[i-11] = g[i-11] " " a1 " " a2
    }
}
END {
    for(i = 1; i <= n; i++)
        print -9, samples[i], -9, -9, 0, -9 g[i] > plink_prefix ".ped"
}
' "${INPUT_FF}"

# transpose
plink --file "${INPUT_F}.plk" --recode12 --output-missing-genotype 0 --transpose --out "${INPUT_F}" --noweb

# prepare marker file for mlmm
cut -d ' ' -f 1,4- "${INPUT_F}.tped" > temp0
awk '{for(i=4;i<=NF;i=i+2)$i=""; print }' temp0 > temp1
head -n 1 "${INPUT_FF}" > temp2
cut -d '	' -f3,4,12- temp2 > temp3
sed -i 's/chrom/Chromosome/g' temp3
sed -i 's/pos/Positions/g' temp3
sed -i 's/PI//g' temp3
cat temp3 temp1 > temp4
awk -v OFS="," '$1=$1' temp4 > nt2mlmm.txt
sed -i 's/,1,/,0,/g' nt2mlmm.txt
sed -i 's/,1,/,0,/g' nt2mlmm.txt
sed -i 's/,2,/,1,/g' nt2mlmm.txt
sed -i 's/,2,/,1,/g' nt2mlmm.txt
sed -i 's/,1$/,0/g' nt2mlmm.txt
sed -i 's/,2$/,1/g' nt2mlmm.txt

mv "${INPUT_F}.tped" nt4.tped
mv "${INPUT_F}.tfam" nt3.tfam
mv "${INPUT_F}.log" nt5.log

gzip nt4.tped
gzip "${OUTPUT}"
gzip nt2mlmm.txt

trap "rm -rf *.sh temp* ${INPUT_F} ${INPUT_F}.plk.* ${INPUT_F}.nof ${INPUT_F}.nosex filters.hmp.txt filters1.hmp.txt" exit
