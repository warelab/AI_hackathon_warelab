#!/bin/bash
set -euo pipefail
gunzip structure.gz
chmod a+x structure
# input
INPUT_I=${i}
INPUT_IF=$(basename ${INPUT_I})
extension="${INPUT_IF##*.}"
if [ ${extension} == "gz" ]; then gunzip ${INPUT_IF}; INPUT_IF="${INPUT_IF%.*}"; fi

INPUT_E=${e}
if [ -n "${INPUT_E}" ]; then
	INPUT_EF=$(basename ${INPUT_E})
	echo "#define RANDOMIZE    0" >> ${INPUT_EF}
else
	INPUT_E=extraparams
	# prepare extraparams
	echo "#define FREQSCORR 1" >> extraparams
	echo "#define ONEFST 0" >> extraparams
	echo "#define INFERALPHA  1" >> extraparams
	echo "#define POPALPHAS   0" >> extraparams
	echo "#define INFERLAMBDA 0" >> extraparams
	echo "#define POPSPECIFICLAMBDA 0" >> extraparams
	echo "#define NOADMIX     0" >> extraparams
	echo "#define LINKAGE     0" >> extraparams
	echo "#define PHASED      0" >> extraparams
	echo "#define LOG10RMIN     -4.0" >> extraparams
	echo "#define LOG10RMAX      1.0" >> extraparams
	echo "#define LOG10RPROPSD   0.1" >> extraparams
	echo "#define LOG10RSTART   -2.0" >> extraparams
	echo "#define COMPUTEPROB 1" >> extraparams
	echo "#define ADMBURNIN   500" >> extraparams
	echo "#define USEPOPINFO  0" >> extraparams
	echo "#define GENSBACK    1" >> extraparams
	echo "#define MIGRPRIOR 0.001" >> extraparams
	echo "#define PFROMPOPFLAGONLY 0" >> extraparams
	echo "#define PRINTKLD     1" >> extraparams
	echo "#define PRINTLAMBDA  1" >> extraparams
	echo "#define PRINTQSUM    1" >> extraparams
	echo "#define SITEBYSITE 0" >> extraparams
	echo "#define PRINTQHAT    0" >> extraparams
	echo "#define UPDATEFREQ   5" >> extraparams
	echo "#define PRINTLIKES   0" >> extraparams
	echo "#define INTERMEDSAVE 0" >> extraparams
	echo "#define ECHODATA     1" >> extraparams
	echo "#define ANCESTDIST   0" >> extraparams
	echo "#define NUMBOXES   1000" >> extraparams
	echo "#define ANCESTPINT 0.90" >> extraparams
	echo "#define ALPHA      1.0" >> extraparams
	echo "#define FPRIORMEAN 0.01" >> extraparams
	echo "#define FPRIORSD   0.05" >> extraparams
	echo "#define LAMBDA      1.0" >> extraparams
	echo "#define UNIFPRIORALPHA 1" >> extraparams
	echo "#define ALPHAMAX     20.0" >> extraparams
	echo "#define ALPHAPRIORA  0.05" >> extraparams
	echo "#define ALPHAPRIORB  0.001" >> extraparams
	echo "#define ALPHAPROPSD 0.025" >> extraparams
	echo "#define STARTATPOPINFO 0" >> extraparams
	echo "#define RANDOMIZE    0" >> extraparams
	echo "#define METROFREQ    10" >> extraparams
	echo "#define REPORTHITRATE 0" >> extraparams
	INPUT_EF=$(basename ${INPUT_E})
fi

# arguments
MAXPOPS=${maxpops}
NUMLOCI=${numloci}
NUMINDS=${numinds}
OUTPUT=s
#KRUNS=${kruns}
LABEL=${label}
POPDATA=${popdata}
POPFLAG=${popflag}
PHENOTYPE=${phenotype}
EXTRACOLS=${extracols}
PHASEINFO=${phaseinfo}
MARKOVPHASE=${markovphase}
MISSING=${missing}
PLOIDY=${ploidy}
ONEROWPERIND=${onerowperind}
MARKERNAMES=${markernames}
MAPDISTANCES=${mapdistances}
BURNIN=${burnin}
NUMREPS=${numreps}

# prepare mainparams
echo "#define LABEL ${LABEL}" >> mainparams 
echo "#define POPDATA ${POPDATA}" >> mainparams
echo "#define POPFLAG ${POPFLAG}" >> mainparams
echo "#define PHENOTYPE ${PHENOTYPE}" >> mainparams
echo "#define EXTRACOLS ${EXTRACOLS}" >> mainparams
echo "#define PHASEINFO ${PHASEINFO}" >> mainparams
echo "#define MARKOVPHASE ${MARKOVPHASE}" >> mainparams
echo "#define MISSING ${MISSING}" >> mainparams
echo "#define PLOIDY ${PLOIDY}" >> mainparams
echo "#define ONEROWPERIND ${ONEROWPERIND}" >> mainparams
echo "#define MARKERNAMES ${MARKERNAMES}" >> mainparams
echo "#define BURNIN ${BURNIN}" >> mainparams
echo "#define NUMREPS ${NUMREPS}" >> mainparams
echo "#define NUMLOCI ${NUMLOCI}" >> mainparams
echo "#define NUMINDS ${NUMINDS}" >> mainparams
echo "#define MAPDISTANCES ${MAPDISTANCES}" >> mainparams

# run estimation
rn=$(echo "10000*$RANDOM+$RANDOM" | bc)
SW=$(echo "scale=1; ${MAXPOPS} - 1" | bc)

echo "Launch job array...." 

echo "#!/bin/bash" > str.list    
echo "#SBATCH -J array_job" >> str.list
echo "#SBATCH -o array_job_out_%A_%a.txt" >> str.list 
echo "#SBATCH -e array_job_err_%A_%a.txt" >> str.list
echo "#SBATCH -t 24:00:00" >> str.list
echo "#SBATCH --mem-per-cpu=16000" >> str.list
echo "#SBATCH --array=1-${SW}" >> str.list
echo "#SBATCH -n 1" >> str.list
echo "#SBATCH -p parallel" >> str.list

echo "./structure -i ${INPUT_IF} -L ${NUMLOCI} -N ${NUMINDS} -K \$SLURM_ARRAY_TASK_ID -m mainparams -e ${INPUT_EF} -o ${OUTPUT}_\$SLURM_ARRAY_TASK_ID" -D ${rn} >> str.list

JID=`sbatch str.list | awk '{print $4}'`
#Following command will hold the new job but not the script so while loop is used instead.
#$ srun -d "afterany:$JID" true 

# Large cluster number testing takes longer time to complete so following job will take longer than the job array
./structure -i ${INPUT_IF} -L ${NUMLOCI} -N ${NUMINDS} -K ${MAXPOPS} -m mainparams -e ${INPUT_EF} -o ${OUTPUT}_${MAXPOPS} -D ${rn}

    while true;do

    # Check array job status
    STATUS=`sacct --format=state -n -j $JID`
	
    # For simplicity, following script is checking for RUNNING/PENDING/CONFIGURING/COMPLETING/RESIZING
    if [[ "$STATUS" =~ "ING" ]]; then
    	sleep 300s
    else
	# Job is completed, break the while loop
		break
    fi
    done
	
echo "..Done"
    

# post processing
echo "K		Estimated Ln Prob of Data" >> mysummary.txt


for ((c=1; c<=${MAXPOPS}; c++)); do
	Max_value=$(sed -n '/Estimated Ln Prob of Data   = \(-[0-9]*\.[0-9]*\)$/s//\1/p' ${OUTPUT}_${c}_f)
	echo "${c}		${Max_value}" >> mysummary.txt
    
    # Convert for TASSEL
    # Extract number of individuals
	TEMP=$(egrep '[0-9]+ individuals' ${OUTPUT}_${c}_f)
	NUMINDS=$(echo ${TEMP} | awk '{print $1;}')

	# Extract number of clusters
	TEMP=$(egrep '[0-9]+ populations assumed' ${OUTPUT}_${c}_f)
	NUMC=$(echo ${TEMP} | awk '{print $1;}')

	# Calculate max column number
	NUMR=$(echo "scale=1; ${NUMC} + 4" | bc)

	# Extract rows for clusters assignment
	#echo ${NUMINDS}
	awk -v ni=${NUMINDS} 'c&&c--;/:  Inferred clusters/{c=ni}' ${OUTPUT}_${c}_f > out1

	# Replace white space with tab
	awk -v OFS="\t" '$1=$1' out1 > out2
	rm -rf out1

	# Extract columns for cluster assignment
	cut -f2,5-${NUMR} out2 > out3
	rm -rf out2

	# Print header lines
	HEAD="<Covariate>\\n<Trait>"
	for (( cc=1; cc<=${NUMC}; cc++ ))
	do
		HEAD=${HEAD}\\tQ${cc}
	done
	#echo ${HEAD}
	awk -v h=${HEAD} 'BEGIN{print h}1' out3 > ${OUTPUT}${c}_f
done



trap "rm -rf structure str.list ${INPUT_IF} mainparams extraparams array_job* *.sh seed.txt *.ipcexe" exit

