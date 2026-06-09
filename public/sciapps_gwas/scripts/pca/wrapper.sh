#!/bin/bash
set -euo pipefail
#which R
# input (can be used for parameter passing but hard to manipulate, e.g. unzip)
INPUT_IF=${input}

extension="${INPUT_IF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_IF}; INPUT_IF="${INPUT_IF%.*}"; fi

# arguments (for parameter passing, double quote is essential for non int parameter)
# white space after the paramter flag (in json) is critical
METHOD="${model}"
NUMPCS="${numPCs}"

# output won't work for parameter passing unless it is specified as another parameter
OUTPUT="-o pca_output.txt"

# run
cp ${CONDA_PREFIX}/share/pca/pca.R .
Rscript pca.R -i ${INPUT_IF} -m ${METHOD} -n ${NUMPCS} ${OUTPUT} -e eigval_out -s scree_out -p pcplot_out


# delete
trap "rm -fr ${INPUT_IF} getopt *.sh *.ipcexe" exit
