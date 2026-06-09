#!/bin/bash
set -euo pipefail

# input files
INPUT_P=${pheno}
INPUT_M=${marker}

INPUT_PF=$(basename ${INPUT_P})
INPUT_MF=$(basename ${INPUT_M})

extension="${INPUT_MF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_MF}; INPUT_MF="${INPUT_MF%.*}"; fi

# parameters
OUTPUT=mlmm
KIN=${kin_method}
STEPS=${max_steps}
TRAIT_ID=${trait_id}

/opt/apps/python/2.7.3/bin/python /data/agave/mlmm/mlmm.py -m ${INPUT_MF} -p ${INPUT_PF} -r ${OUTPUT} -k ${KIN} -s ${STEPS} -t ${TRAIT_ID}

trap "rm -fr ${INPUT_PF} ${INPUT_MF} *.sh *.pickled *.ipcexe" exit
