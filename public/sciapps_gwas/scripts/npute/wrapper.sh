#!/bin/bash
set -euo pipefail

# input
INPUT_IF=${i}
extension="${INPUT_IF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_IF}; INPUT_IF="${INPUT_IF%.*}"; fi

# arguments
MODE=${mode}
OUTPUT=npt_${INPUT_IF}
LABEL=${header}
EXTRACOLS=${extracols}
PLOIDY=${ploidy}
MISSING=${missing}
STARTWIN=${startWindow}
ENDWIN=${endWindow}
STEP=${stepWindow}

touch temp.txt temp1.txt
#Remove extra columns
if [ ${EXTRACOLS} -gt 0 ]; then
	sm=$(echo "scale=1; ${EXTRACOLS}+1" | bc)
	cut -f ${sm}- ${INPUT_IF} > temp.txt
else
	cp ${INPUT_IF} temp.txt
fi

#Remove headlines
if [ ${LABEL} -gt 0 ] ; then
	#awk -v nc=${LABEL} '{if(NR>nc) {print}}' temp.txt > temp1.txt
    sed -e "1,${LABEL}d" < temp.txt > temp1.txt
	cp temp1.txt temp.txt
fi

#Convert genotype coding to one letter
#http://www.panzea.org/lit/README_MaizeHapMapV2.txt
if [ ${PLOIDY} -eq 2 ] ; then
	awk '{gsub(/AA/, "A"); print;}' temp.txt > temp1.txt
        awk '{gsub(/CC/, "C"); print;}' temp1.txt > temp.txt
        awk '{gsub(/GG/, "G"); print;}' temp.txt > temp1.txt
        awk '{gsub(/TT/, "T"); print;}' temp1.txt > temp.txt

        awk '{gsub(/AC/, "M"); print;}' temp.txt > temp1.txt
        awk '{gsub(/AG/, "R"); print;}' temp1.txt > temp.txt
        awk '{gsub(/AT/, "W"); print;}' temp.txt > temp1.txt

        awk '{gsub(/CG/, "S"); print;}' temp1.txt > temp.txt
        awk '{gsub(/CT/, "Y"); print;}' temp.txt > temp1.txt

        awk '{gsub(/GT/, "K"); print;}' temp1.txt > temp.txt
        
        awk '{gsub(/CA/, "M"); print;}' temp.txt > temp1.txt
        awk '{gsub(/GA/, "R"); print;}' temp1.txt > temp.txt
        awk '{gsub(/TA/, "W"); print;}' temp.txt > temp1.txt

        awk '{gsub(/GC/, "S"); print;}' temp1.txt > temp.txt
        awk '{gsub(/TC/, "Y"); print;}' temp.txt > temp1.txt

        awk '{gsub(/TG/, "K"); print;}' temp1.txt > temp.txt
fi

#awk '{gsub(/${MISSING}/, "?"); print;}' temp.txt > temp1.txt
sed "s/${MISSING}/?/g" temp.txt > temp1.txt

sed -i 's/\t/,/g' temp1.txt 

#Imputing
if [ ${MODE} == "Testing" ] ; then

SW=$(echo "scale=1; ${STARTWIN} + ${STEP}" | bc)

echo "Launch job array...." 

echo "#!/bin/bash" > str.list    
echo "#SBATCH -J array_job" >> str.list
echo "#SBATCH -o array_job_out_%A_%a.txt" >> str.list 
echo "#SBATCH -e array_job_err_%A_%a.txt" >> str.list
echo "#SBATCH -t 2:00:00" >> str.list
echo "#SBATCH --mem-per-cpu=16000" >> str.list
echo "#SBATCH --array=${SW}-${ENDWIN}:${STEP}" >> str.list
echo "#SBATCH -n 1" >> str.list
echo "#SBATCH -p parallel" >> str.list
## old script: echo "/data/agave/npute/NPUTE.py -m 1 -r \$SLURM_ARRAY_TASK_ID:\$SLURM_ARRAY_TASK_ID -i temp1.txt -o ${OUTPUT}.\$SLURM_ARRAY_TASK_ID" >> str.list
echo "${CONDA_PREFIX}/bin/python ${CONDA_PREFIX}/share/NPUTEv1/NPUTE.py -m 1 -r \$SLURM_ARRAY_TASK_ID:\$SLURM_ARRAY_TASK_ID -i temp1.txt -o ${OUTPUT}.\$SLURM_ARRAY_TASK_ID" >> str.list

JID=`sbatch str.list | awk '{print $4}'`
#Following command will hold the new job but not the script so while loop is used instead.
#$ srun -d "afterany:$JID" true 

# Small window size testing takes longer time to complete so following job will take longer than the job array
## old script: python /data/agave/npute/NPUTE.py -m 1 -r ${STARTWIN}:${STARTWIN} -i temp1.txt -o ${OUTPUT}.${STARTWIN}
python ${CONDA_PREFIX}/share/NPUTEv1/NPUTE.py -m 1 -r ${STARTWIN}:${STARTWIN} -i temp1.txt -o ${OUTPUT}.${STARTWIN}

    while true;do

    # Check array job status
    STATUS=`sacct --format=state -n -j $JID`
	
    # For simplicity, following script is checking for RUNNING/PENDING/CONFIGURING/COMPLETING/RESIZING
    if [[ "$STATUS" =~ "ING" ]]; then
    	sleep 300s
    else
    # output all array job outputs
    for (( c=${SW}; c<=${ENDWIN}; c=c+${STEP} )); do
        	head -n 200 array_job_out_${JID}_${c}.txt
    done
	# Job is completed, break the while loop
		break
    fi
    done
	
echo "..Done"
    

	# post processing
	echo "Window,Accuracy" >> summary.txt

        for (( c=${STARTWIN}; c<=${ENDWIN}; c=c+${STEP} )); do
        	cat ${OUTPUT}.${c} >> summary.txt
        done
	mv summary.txt ${OUTPUT}

else
    
	## old script: python /data/agave/npute/NPUTE.py -m 0 -w ${STARTWIN} -i temp1.txt -o ${OUTPUT} #> npute.log 2>&1
	python ${CONDA_PREFIX}/share/NPUTEv1/NPUTE.py -m 0 -w ${STARTWIN} -i temp1.txt -o ${OUTPUT} #> npute.log 2>&1
    
    if [ ${LABEL} -gt 0 ] ; then
		awk -v nc=${LABEL} '{if(NR>nc) {print}}' ${INPUT_IF} > temp.txt
	else
		cp ${INPUT_IF} temp.txt
	fi
    awk '{ print toupper($0) }' ${OUTPUT} > temp1.txt
	sed -i 's/,/\t/g' temp1.txt
    if [ ${EXTRACOLS} -gt 0 ] ; then
		cut -f 1-${EXTRACOLS} temp.txt > extra.txt    
		paste extra.txt temp1.txt | column -s $'\t' -t > temp.txt
    else
    	mv temp1.txt temp.txt
    fi
    if [ ${LABEL} -gt 0 ] ; then
		head -n ${LABEL} ${INPUT_IF} > head.txt
		cat head.txt temp.txt > ${OUTPUT}
	else
		mv temp.txt ${OUTPUT}
	fi
	# replace white spaces with tab
	awk -v OFS="\t" '$1=$1' ${OUTPUT} > temp1.txt

	# remove lines with less columns
	ncols=$(awk 'BEGIN{FS="\t"}; {print NF; exit}' temp1.txt)
	awk -v nc=${ncols} 'NF>=nc' temp1.txt >${OUTPUT}
	
	nrows=$(wc -l < ${OUTPUT})
	NUMLOCI=$(echo "scale=1; ${nrows} - ${LABEL}" | bc)
	NUMINDS=$(echo "scale=1; ${ncols} - ${EXTRACOLS}" | bc)
	echo "NUMLOCI	NUMINDS" >> summary.txt
	echo "${NUMLOCI}	${NUMINDS}" >> summary.txt
fi

gzip ${OUTPUT}
 
trap "rm -rf ${INPUT_IF} extra.txt impute.txt head.txt temp* *.pyc semp1.txt array_job_* str.list *.sh" exit

