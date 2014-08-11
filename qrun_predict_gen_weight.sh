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
NEVENTS=1000
#NEVENTS=1
#------------- Preparation --------------

#####################################################
configName=config
#configName=config_$LOWER
#####################################################

echo 
echo '>>>Preparing<<<'
echo 
#. prepare_root 5.34.10
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/nfs/mnemosyne/sys/slc6/sw/root/x86-64/5.34.18/root/lib
. prepare_root
#export PATH=/nfs/hicran/project/compass/analysis/slietzau/PWA_old/bin/:$PATH

TEMPDIR=`mktemp -t -d PREDICT_MC.XXXXX`
echo $TEMPDIR
trap "rm -rf \"$TEMPDIR\"" EXIT
cd $TEMPDIR

echo copying Stuff

cp -a $WHICHFIT/$TPRIME/param_$TPRIME.dat .
echo param_file is:
echo $WHICHFIT/$TPRIME/param_$TPRIME.dat
cp -a $WHICHFIT/$TPRIME/sfit_$TPRIME.dat .

cp -a $CARDFOLDER/addwave* .
cp -a $CARDFOLDER/ampl* .
cp -a $CARDFOLDER/$CARD card.dat

echo Generating SEED...
if [[ -z $INITSEED ]]; then 
    INITSEED=$JOB_ID
fi
RANDOM=$INITSEED
for i in `seq $SGE_TASK_ID`; do echo "$RANDOM" >/dev/null; done
SEED=$RANDOM
echo SEED=$SEED

#-------------- Setup gen weight ------------------
cp -a card.dat card_gen_weight.dat

echo Preparing card_weight.dat
cat >>card_gen_weight.dat <<EOF
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
C *FILEFIT 'fit_${LOWER_EDGE}-${UPPER_EDGE}.dat'
*FILEPARAM 'param_$TPRIME.dat'
DIRINTEGRALS  '$INTDIR/$TPRIME/'
FILE_HIST_PAW_PREDICTMC 'wMC_histos_$MODEL.dat'
FILE_HIST_ROOT_PREDICTMC 'wMC_histos_$MODEL.root'
*INTBIN  0.500  2.500  $LOWER_EDGE  $UPPER_EDGE  0.010
*BIN 0.500 2.500 ${LOWER_EDGE} ${UPPER_EDGE} $BINWIDTH
EOF

#------------- Running gen_weight ----------------

echo $EXECUTABLE card_gen_weight.dat $LOWER $UPPER $SEED
time $EXECUTABLE card_gen_weight.dat $LOWER $UPPER $SEED >gen_weight.log 2>&1
#time $EXECUTABLE card_gen_weight.dat >$LOGDIR/weight_$TPRIME_$SEED.log 2>&1

#------------- finding WEIGHT_MAX_NORM -----------

WEIGHT_MAX_NORM=`grep 'weight_max_norm=' gen_weight.log |tail -n 1 |awk '{ printf "%f", $2*1.1}'`
echo 'WEIGHT_MAX_NORM + 10% =' $WEIGHT_MAX_NORM




cat >> $configName <<EOF
WEIGHT_MAX_NORM=$WEIGHT_MAX_NORM
SEED=$SEED
EOF

chmod +x $configName

echo Generating Target: $TARGET
mkdir -p $TARGET

echo Saving Workdir
gzip -9 gen_weight.log
cp -a -t $TARGET $configName gen_weight.log.gz card_gen_weight.dat

echo Deleting TEMPDIR
rm -rf $TEMPDIR

echo Ended: `date`

exit 0
