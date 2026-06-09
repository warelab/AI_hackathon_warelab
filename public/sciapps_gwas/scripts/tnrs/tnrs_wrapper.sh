#!/bin/bash
set -euo pipefail
echo ${trait}
#input
INPUT_G=${sid}.txt
INPUT_GF=$(basename ${INPUT_G})

INPUT_T=${trait}
INPUT_TF=$(basename ${INPUT_T})

# arguments
OUT="ct_${INPUT_TF}"
HEADER=${header}

# run
perl tnrs4gwas.pl --sid ${INPUT_GF} --trait ${INPUT_TF} --header ${HEADER} --out williamscshlout1

# post processing
awk -v OFS="\t" '$1=$1' williamscshlout1 > williamscshlout2

# Count columns
ncols=$(awk 'BEGIN{FS="\t"}; {print NF; exit}' williamscshlout2)

# Print header lines
HEAD="<Trait>"
for (( c=1; c<${ncols}; c++ ))
do
	HEAD=${HEAD}\\tTrait${c}
done
#echo ${HEAD}

awk -v h=${HEAD} 'BEGIN{print h}1' williamscshlout1 > ${OUT}

#tar -czf tnrs.open.tar.gz tnrs_output.txt
#rm tnrs_output.txt

trap "rm -fr Arabidopsis.txt Maize.txt Rice.txt Sorghum.txt tnrs4gwas.pl ${INPUT_TF} *.ipcexe williamscshlout1 williamscshlout2 *.sh" exit
