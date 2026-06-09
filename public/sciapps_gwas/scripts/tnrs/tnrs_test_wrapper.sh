#!/bin/bash

#input
INPUT_G=${sid}
iget -frVT "${INPUT_G}"
INPUT_GF=$(basename ${INPUT_G})

INPUT_T=${trait}
iget -frVT "${INPUT_T}"
INPUT_TF=$(basename ${INPUT_T})

# arguments
OUT=${out}
HEADER=${header}

# run
perl tnrs4gwas.pl --sid ${INPUT_GF} --trait ${INPUT_TF} --header ${header} --out ${OUT}
