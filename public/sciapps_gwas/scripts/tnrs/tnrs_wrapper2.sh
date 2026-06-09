#!/bin/bash
echo ${trait}
#input
INPUT_T=${iget_trait}
iget ${INPUT_T}

# arguments
INPUT_GF=${sid}.txt
OUT="ct_${INPUT_TF}"
HEADER=${header}

# run
perl tnrs4gwas.pl --sid ${INPUT_GF} --trait ${INPUT_TF} --header ${HEADER} --out williamscshlout1

# post processing
awk -v OFS="\t" '$1=$1' williamscshlout1 > williamscshlout2

# Count columns
ncols=$(awk '{FS='\t'}; {print NF; exit}' williamscshlout2)

# Print header lines
HEAD="<Trait>"
for (( c=1; c<${ncols}; c++ ))
do
	HEAD=${HEAD}\\tTrait${c}
done
#echo ${HEAD}

awk -v h=${HEAD} 'BEGIN{print h}1' williamscshlout1 > ${OUT}

AR_PATH=${iput_path}
iput ${OUT} ${AR_PATH}

#tar -czf tnrs.open.tar.gz tnrs_output.txt
#rm tnrs_output.txt

trap "rm -fr Arabidopsis.txt Maize.txt Rice.txt Sorghum.txt tnrs4gwas.pl ${INPUT_TF} *.ipcexe williamscshlout1 williamscshlout2 *.sh" exit
