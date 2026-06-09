#!/bin/bash
set -euo pipefail

# input files
INPUT_PF=${pheno}
extension="${INPUT_PF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_PF}; INPUT_PF="${INPUT_PF%.*}"; fi

INPUT_TF=${tped}
extension="${INPUT_TF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_TF}; INPUT_TF="${INPUT_TF%.*}"; fi

INPUT_MF=${tfam}
extension="${INPUT_MF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_MF}; INPUT_MF="${INPUT_MF%.*}"; fi

INPUT_K=${kinship:-}
INPUT_C=${covariate:-}


EMMAXX="emmaxx"
cp ${INPUT_TF} ${EMMAXX}.tped
#sort -k 2,2 -k 1,1 ${INPUT_MF} > ${EMMAXX}.tfam
cp ${INPUT_MF} ${EMMAXX}.tfam
EMMAXX_F=$(basename ${EMMAXX})

# parameters
OUTPUT="EMMAX"
KIN=${kin_method}
HEADER=${header}

# Remove header lines from trait file
awk -v nc=${HEADER} '{if(NR>nc) {print}}' ${INPUT_PF} > temp.txt

# prepare trait file, assuming sorted same order as tfam file
ncols=$(awk 'BEGIN{FS="\t"}; {print NF; exit}' ${INPUT_PF})
if [ ${ncols} -lt 3 ] ; then
	cut -d ' ' -f 1 ${EMMAXX}.tfam > id.txt
	#sort -k 1,1 temp.txt > tmp2.txt
	paste id.txt temp.txt | column -s $'\t' -t > tmp.txt
else
	#sort -k 2,2 -k 1,1 temp.txt > tmp.txt
	mv temp.txt tmp.txt
fi

case ${KIN} in
	"IBS")	F_FLAG="-v -h -s -d 10";;
	"BN")	F_FLAG="-v -h -d 10";;
esac

if [ -n "${INPUT_K}" ]; then 
  INPUT_KF=$(basename ${INPUT_K})
else
	emmax-kin ${F_FLAG} ${EMMAXX_F}
  INPUT_K="${EMMAXX}.h${KIN}.kinf"
  INPUT_KF=$(basename ${INPUT_K})    
fi

if [ -n "${INPUT_C}" ]; then
  INPUT_CF=$(basename ${INPUT_C})
	emmax -v -d 10 -t ${EMMAXX_F} -c ${INPUT_CF} -p tmp.txt -k ${INPUT_KF} -o ${OUTPUT}
else
  INPUT_CF=''
	emmax -v -d 10 -t ${EMMAXX_F} -p tmp.txt -k ${INPUT_KF} -o ${OUTPUT}
fi

# merge SNP id with SNP position
cut -d ' ' -f 1,2,4 ${INPUT_TF} > id2pos.txt
sort -k 2 id2pos.txt > id.txt
sort -k 1 ${OUTPUT}.ps > o.txt
cut -d ' ' -f 1,3 id.txt > i.txt
paste i.txt o.txt | column -s $' ' -t > emmax.ps

# replace white spaces with tab
awk -v OFS="\t" '$1=$1' emmax.ps > emmaxxz.ps
rm -fr emmax.ps
mv emmaxxz.ps ${OUTPUT}.ps

# Format for shinny (SNP-2     CHR-3     BP-4      P-7)
echo "SNP	CHR	BP	P" > manhattan.plot
awk -v OFS='\t' '{print $3, $1, $2, $5}' ${OUTPUT}.ps >> manhattan.plot

# Rename output
mv ${OUTPUT}.ps pval_${OUTPUT}.ps

trap "rm -fr emmaxxz.ps tmp2.txt temp.txt id.txt ${EMMAXX}.* ${INPUT_PF} ${INPUT_CF} ${INPUT_KF} ${INPUT_MF} ${INPUT_TF} tmp.txt id2pos.txt id.txt o.txt i.txt *.sh *.ipcexe" exit 
