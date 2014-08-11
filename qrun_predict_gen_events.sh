#!/bin/bash
# Select Queue
#$ -l short=TRUE,h_vmem=1000M
#
# Select Working Dir
#$ -cwd
#
# Merge stdout und stderr
#$ -j y
#
# Generate Logfile
#$ -o /nfs/mds/user/slietzau/predict/logs/ 

# ----------- Command Line Arguments -----------
EXECUTABLE=$1
CARD=$2
TPRIME=$3
MODEL=$4
NAME=$5
LOGDIR=$6
LOWER=$7
UPPER=$8
WHICHFIT=$9
INTDIR=${10}
BINWIDTH=${11}
LOWER_EDGE=`echo $TPRIME | awk -F"-" '{print $1}'`
UPPER_EDGE=`echo $TPRIME | awk -F"-" '{print $2}'`
RUN=`printf "%06d" $SGE_TASK_ID`

echo Startet: `date`

#---------- Constant Arguments ------------

echo
echo Setting Environment
echo 

SOURCE=/nfs/nas/data/compass/hadron/2008/comSkim/MC/PS-MC/trees_for_integrals/m-bins/0.100-1.000/
#INTDIR=/nfs/hicran/scratch/user/fhaas/PWA/integrals/F_f0_980_Flatte/
CARDFOLDER=/nfs/hicran/project/compass/analysis/fkrinner/fkrinner/trunk/predict/
TARGET=/nfs/mds/user/fkrinner/predict/$CARD-$NAME/$RUN/$TPRIME/
#WHICHFIT=/nfs/hicran/scratch/user/fhaas/PWA/fits/2008-all-lH-DT0/F_f0_980_Flatte/

#---------- Variables --------------------

#BINWIDTH=0.020
#NEVENTS=1000 #For test-run (t < 15s)
NEVENTS=200000 #Estimated time to stay under one hour (with some air)

#------------- Preparation --------------

echo 
echo '>>>Preparing<<<'
echo 
#. prepare_root 5.34.10
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/nfs/mnemosyne/sys/slc6/sw/root/x86-64/5.34.18/root/lib
#export PATH=/nfs/hicran/project/compass/analysis/slietzau/PWA_old/bin/:$PATH

TEMPDIR=`mktemp -t -d PREDICT_MC.XXXXX`
echo $TEMPDIR
trap "rm -rf \"$TEMPDIR\"" EXIT
cd $TEMPDIR

echo copying Stuff

cp -a $WHICHFIT/$TPRIME/param_$TPRIME.dat .
cp -a $WHICHFIT/$TPRIME/sfit_$TPRIME.dat .

cp -a $CARDFOLDER/addwave* .
cp -a $CARDFOLDER/ampl* .
cp -a $CARDFOLDER/$CARD card_gen_events.dat

#####################################################
configName=config
#configName=config_$LOWER
#####################################################

echo Reading $configName of gen_weight
cp -a $TARGET/$configName .
. ./$configName


# Generate random seed... do not use the seed from 'config'.
echo Generating SEED...
if [[ -z $INITSEED ]]; then 
    INITSEED=$JOB_ID
fi
RANDOM=$INITSEED
for i in `seq $SGE_TASK_ID`; do echo "$RANDOM" >/dev/null; done
SEED=$RANDOM
echo SEED=$SEED
#-------------- Setup gen_events -------

echo Preparing card_gen_events.dat
cat >>card_gen_events.dat <<EOF
C NAME_TREE_MC_IN  'USR51MCout'
C TYPE_TREE_MC_IN  1
C *MC_BINS_PREFIX '$SOURCE'
C *MC_BINS_SUFFIX '.root'
MCGEN
INOACC
NO_CUTS
EBEAM_LIM_MCGEN 180. 200.
TPRIME_LIM_MCGEN $LOWER_EDGE $UPPER_EDGE
NO_RECOIL 0
NMC1 $NEVENTS
MC_SEED $SEED
C*FILEFIT 'fit_${LOWER_EDGE}-${UPPER_EDGE}.dat'
*FILEPARAM 'param_$TPRIME.dat'
DIRINTEGRALS  '$INTDIR/$TPRIME/'
WEIGHT_1
WEIGHT_MAX_NORM $WEIGHT_MAX_NORM
FILE_HIST_PAW_PREDICTMC 'wMC_histos_$MODEL.dat'
FILE_HIST_ROOT_PREDICTMC 'wMC_histos_$MODEL.root'
WRITEMC_ROOT
C TYPE_TREE_MC_OUT    0
NAME_TREE_MC_OUT    'wMC'
FILE_ROOT_MC_OUT    'wMC_tree_$MODEL.root'
WRITEMC_CG
FILEWRITEMC_CG  'wMC_events_$MODEL.dat'
*INTBIN  0.500  2.500  $LOWER_EDGE  $UPPER_EDGE  0.010
*BIN 0.500 2.500 ${LOWER_EDGE} ${UPPER_EDGE} $BINWIDTH
EOF

#------------- Running gen_events ------

echo time $EXECUTABLE card_gen_events.dat $LOWER $UPPER $SEED
time $EXECUTABLE card_gen_events.dat  $LOWER $UPPER $SEED >gen_events.log 2>&1
#time $EXECUTABLE card_gen_events.dat  >$LOGDIR/events_$TPRIME_$SEED.log 2>&1

echo Generating Target: $TARGET
mkdir -p $TARGET

echo Saving Workdir
gzip -9 gen_events.log
cp -a gen_events.log.gz w* card_gen_events.dat $TARGET/

echo Deleting TEMPDIR
rm -rf $TEMPDIR

echo Ended: `date`

exit 0
