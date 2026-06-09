#!/bin/bash
set -euo pipefail
#input
INPUT_GF=${sid}

INPUT_TF=${trait}

if [ ${INPUT_GF: -3} == ".gz" ]; then
	gunzip ${INPUT_GF}
    INPUT_GF=${INPUT_GF%.*}
fi
    
# arguments
EXTRACOLS=${extracols}
MARKER_OUTPUT="mm_${INPUT_GF}"
TRAIT_OUTPUT="mt1_$(basename "${INPUT_GF%%.*}").$(basename "${INPUT_TF}")"
HEADLINES=${headlines}

# count columns
head -n 1 ${INPUT_GF} > head.txt
ncols=$(awk '{print NF}' head.txt | sort -nu | head -n 1)

# run
perl mergeg2p.pl --sid ${INPUT_GF} --trait ${INPUT_TF} --ncols ${ncols} --extracols ${EXTRACOLS} --headlines ${HEADLINES} --marker_output ${MARKER_OUTPUT} --trait_output ${TRAIT_OUTPUT}


sed -i 's/PI//g' mlmm_${TRAIT_OUTPUT}

mv mlmm_${TRAIT_OUTPUT} mt2_${INPUT_TF}
gzip ${MARKER_OUTPUT}

trap "rm -fr ${INPUT_GF} ${INPUT_TF} head.txt *.pl *.sh *.ipcexe" exit
