#!/bin/bash

# input
#INPUT_I={i}
INPUT_I="/lwang/applications/structure/data/mdp.str"
#iget -frVT "${INPUT_I}"
INPUT_IF=$(basename ${INPUT_I})
#INPUT_E=${e}
INPUT_E="/lwang/applications/structure/data/extraparams"

if [ -n "${INPUT_E}" ]; then
	iget -frVT "${INPUT_E}"
else
	INPUT_E="extraparams"
	echo "EXTRA PARAMS FOR THE PROGRAM structure." >> extraparams
	echo "" >> extraparams
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
fi
INPUT_EF=$(basename ${INPUT_E})

# arguments
#MAXPOPS=${maxpops}
#NUMLOCI=${numloci}
#NUMINDS=${numinds}
#OUTPUT=${o}
#OUTPUT_F=$(basename ${OUTPUT})
#KRUNS=${kruns}
#LABEL=${label}
#POPDATA=${popdata}
#POPFLAG=${popflag}
#PHENOTYPE=${phenotype}
#EXTRACOLS=${extracols}
#PHASEINFO=${phaseinfo}
#MARKOVPHASE=${markovphase}
#MISSING=${missing}
#PLOIDY=${ploidy}
#ONEROWPERIND=${onerowperind}
#MARKERNAMES=${markernames}
#MAPDISTANCES=${mapdistances}
#BURNIN=${burnin}
#NUMREPS=${numreps}

MAXPOPS=10
NUMLOCI=3093
NUMINDS=281
OUTPUT="test"
OUTPUT_F=$(basename ${OUTPUT})
KRUNS=5
LABEL=1
POPDATA=0
POPFLAG=0
PHENOTYPE=0
EXTRACOLS=0
PHASEINFO=0
MARKOVPHASE=0
MISSING=-9
PLOIDY=1
ONEROWPERIND=0
MARKERNAMES=1
MAPDISTANCES=0
BURNIN=1000
NUMREPS=1000

# prepare mainparams
echo "MAIN PARAMS FOR THE PROGRAM structure. " >> mainparams
echo "" >> mainparams
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

# run estimation
chmod a+x structure

for ((c=1; c<=${MAXPOPS}; c++)); do
	for (( cc=1; cc<=${KRUNS}; cc++ )); do
		rn=$(echo "10000*$RANDOM+$RANDOM" | bc)
		echo "structure -i ${INPUT_IF} -L ${NUMLOCI} -N ${NUMINDS} -K ${c} -m mainparams -e ${INPUT_EF} -o ${OUTPUT_F}.${c}_${cc} -D ${rn}" >> str.list
	done
done

echo "Launcher...." 
EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
$TACC_LAUNCHER_DIR/paramrun $EXECUTABLE str.list
echo "..Done"

# post processing
echo "K	mean		tests" >> summary.txt

for ((c=1; c<=${MAXPOPS}; c++)); do
        sm=0.0
        for (( cc=1; cc<=${KRUNS}; cc++ )); do
		Max_value[${cc}-1]=$(sed -n '/Estimated Ln Prob of Data   = \(-[0-9]*\.[0-9]*\)$/s//\1/p' ${OUTPUT_F}.${c}_${cc}_f)
		sm=$(echo "scale=1; ${sm} + ${Max_value[${cc}-1]}" | bc)
	done
        mn=$(echo "scale=1; ${sm} / ${KRUNS}" | bc)
        echo "${c}	${mn}	${Max_value[@]}" >> summary.txt
done

rm -rf bin str.list ${INPUT_IF}

