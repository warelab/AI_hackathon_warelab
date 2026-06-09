#!/bin/bash

#input
INPUT_G=${sid}
iget -frVT "${INPUT_G}"
INPUT_GF=$(basename ${INPUT_G})

INPUT_T=${trait}
iget -frVT "${INPUT_T}"
INPUT_TF=$(basename ${INPUT_T})

# arguments
EXTRACOLS=${extracols}
OUTPUT=${output}
OUTPUT2=${output2}
HEADER=${header}

# count columns
cols=$(awk '{print NF}' ${INPUT_GF} | sort -nu | head -n 1)

# run
perl mergeg2p.pl --sid ${INPUT_GF} --trait ${INPUT_TF} --extracols ${EXTRACOLS} --header ${header} --out ${OUTPUT} --out2 ${OUTPUT2}
