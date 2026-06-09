#!/bin/bash
set -euo pipefail

# input files
INPUT_GF=${hmarker}
extension="${INPUT_GF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_GF}; INPUT_GF="${INPUT_GF%.*}"; fi

INPUT_TF=${rtrait}
INPUT_Q=${qstructure}
INPUT_K=${kinship:-}
INPUT_M=${mapfile:-}

if [ -n "${INPUT_M}" ]; then
        INPUT_MF=$(basename ${INPUT_M})
fi

# parameters
MARKERFORMAT=${markerformat}
VARCOMP=${mlmVarCompEst}
COMP=${mlmCompressionLevel}
OUTPUT=MLM
LEVEL=${level}
FILTER=${filter}
MAXP=${maxp}

case ${MARKERFORMAT} in
        "Hapmap")         F_FLAG="-h";;
        "HDF5")           F_FLAG="-h5";;
        "VCF")            F_FLAG="-vcf";;
        "Plink")          F_FLAG="-plink -map ${INPUT_MF} -ped";;
        "Flapjack")       F_FLAG="-flapjack -map ${INPUT_MF} -geno";;
esac

if [ -n "${INPUT_K}" ]; then 
        echo "Kinship provided."
else
	run_pipeline.pl -Xms32g -Xmx128g -fork1 "${F_FLAG}" "${INPUT_GF}" -ck -export kinship -runfork1
        INPUT_K="kinship.txt"
fi 

INPUT_KF=$(basename ${INPUT_K})
OUTPUT_F=$(basename ${OUTPUT})

if [ ${COMP} == "Custom" ]; then COMP="$COMP $LEVEL"; fi

if [ -n "${INPUT_Q}" ]; then
	TITLE="Marker = Trait + Population Structure + Kinship"
	INPUT_QF=$(basename ${INPUT_Q})
	run_pipeline.pl -Xms32g -Xmx128g -fork1 "${F_FLAG}" "${INPUT_GF}" -filterAlign -filterAlignMinFreq "${FILTER}" -fork2 -r "${INPUT_TF}" -fork3 -q "${INPUT_QF}" -excludeLastTrait -fork4 -k "${INPUT_KF}" -combine5 -input1 -input2 -input3 -intersect -combine6 -input5 -input4 -mlm -mlmMaxP "${MAXP}" -mlmVarCompEst "${VARCOMP}" -mlmCompressionLevel "${COMP}" -export "${OUTPUT_F}" -runfork1 -runfork2 -runfork3 -runfork4
	rm -fr ${INPUT_QF}
else
	TITLE="Marker = Trait + Kinship"
	run_pipeline.pl -Xms32g -Xmx128g -fork1 "${F_FLAG}" "${INPUT_GF}" -filterAlign -filterAlignMinFreq "${FILTER}" -fork2 -r "${INPUT_TF}" -fork3 -k "${INPUT_KF}" -combine4 -input1 -input2 -intersect -combine5 -input4 -input3 -mlm -mlmMaxP "${MAXP}" -mlmVarCompEst "${VARCOMP}" -mlmCompressionLevel "${COMP}" -export "${OUTPUT_F}" -runfork1 -runfork2 -runfork3
fi

# remove second line (TASSEL bug)
sed -i '2d' ${OUTPUT_F}2.txt

# Format MLM2.txt for shinny (SNP-2     CHR-3     BP-4      P-7)
cut -d $'\t' -f2,3,4,7 MLM2.txt > manhattan_plot
sed -i '1!b;s/Marker/SNP/' manhattan_plot 
sed -i '1!b;s/Chr/CHR/' manhattan_plot 
sed -i '1!b;s/Pos/BP/' manhattan_plot 
sed -i '1!b;s/p/P/' manhattan_plot 

tar -czf manhattan_plot.view.tgz manhattan_plot

trap "rm -fr ${INPUT_GF} ${INPUT_TF} getopt manhattan_plot *.sh *.ipcexe" exit
