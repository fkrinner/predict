#!/bin/bash



if [[ -n $1 ]]; then
	name=$1
else
    echo No Name specified, aborting!
#    exit 1
    name=unnamed
fi

#################################################################################################
# Normal run: generate weights -> use weights to generate events
predictType=0
#################################################################################################
# Assume weights are already there -> generate No weights
#predictType=1
#################################################################################################

massLow=1.500
#massUp=2.500
massUp=1.540
massBin=.040

lower=$massLow
upper=`echo " $lower + $massBin " | bc -l`


#whichfit=/nfs/hicran/scratch/user/fhaas/PWA/fits/2008-all-lH-DT0/F_f0_980_Flatte/
#whichfit=/nfs/mds/user/fkrinner/massIndepententFits/fit/isobared/
whichfit=/nfs/mds/user/fkrinner/massIndepententFits/fits/isobarred/fit/

#intdir=/nfs/hicran/scratch/user/fhaas/PWA/integrals/F_f0_980_Flatte/
#intdir=/nfs/mds/user/fkrinner/massIndepententFits/integrals/pipiS/
intdir=/nfs/mds/user/fkrinner/massIndepententFits/fits/isobarred/integrals/


#target=/nfs/mds/user/fhaas/PWA/weightedMC/2008-all-lH-DT0/test
#target=/nfs/hicran/project/compass/analysis/slietzau/predict/output/
#only for testing purpose because nfs is slow:
#target=/tmp/slietzau/predict/output/

#executable=predictmc_3pic_compass_2008florian_dfunc.exe
#executable=predictmc_3pic_compass_2008florian_dfunc.exe
#executable=/nfs/hicran/project/compass/analysis/fkrinner/workDir/compassPWAbin/bin/predictmc_3pic_compass_2008florian3_dfunc.exe
executable=/nfs/hicran/project/compass/analysis/fkrinner/workDir/compassPWAbin_new/bin/predictmc_3pic_compass_2008florian3_dfunc.static

logdir=/nfs/mds/user/fkrinner/predict/log/

#card=card_F_f0_980_Flatte_predict_optimized.dat
#card=card_F_f0_980_Flatte_predict_optimized-main_wave.dat
#card=mainCard_isobared.dat
card=card_isobarred_switch.dat
#card=card_isobarred.dat

#model=Flatte
model=isobarred


#binwidth=0.020
binwidth=$massBin
START=1
END=9

#TBINS=0.112853-0.127471 0.326380-0.448588 #LOOP OVER t' BINS DOES NOT WORK.
#TBINS=0.326380-0.448588
#TBIN=0.326380-0.448588
#TBIN=0.10000-0.14077
TBIN=0.14077-0.19435
#TBIN=0.19435-0.32617
#TBIN=0.32617-1.00000

mkdir -p $logdir
i=$TBIN

while [ `echo " $upper <= $massUp " | bc` -gt 0 ] 
do


#for i in $TBINS; do

if [ $predictType == 0 ]    
then
    #time ./run_predict_gen_weight.sh $executable $card $i $model $name&
    #qsub -l short=TRUE,h_vmem=2100M -j y -o $logdir/run_predict_$model_$i.log  -wd $target/$i ./run_predict.sh $executable $target/$i/card.dat $target/$i/$config $logdir $i $model
    echo qsub  -l short=TRUE,h_vmem=1000M -terse -j y -t $START-$END -N predict_gen_weight -o $logdir/run_weights_$i.log qrun_predict_gen_weight.sh $executable $card $i $model $name $logdir $lower $upper $whichfit $intdir $binwidth
    jid=`qsub  -l short=TRUE,h_vmem=1000M -terse -j y -t $START-$END -N predict_gen_weight -o $logdir/run_weights_$i.log qrun_predict_gen_weight.sh $executable $card $i $model $name $logdir $lower $upper $whichfit $intdir $binwidth | sed -r "s/\.(.*)//"`
    echo Submitted weight job: $jid
    echo qsub  -l short=TRUE,h_vmem=1000M -terse -j y -t $START-$END -hold_jid_ad $jid -N predict_gen_events -o $logdir/run_events_$i.log qrun_predict_gen_events.sh $executable $card $i $model $name $logdir $lower $upper $whichfit $intdir $binwidth
    jid=`qsub  -l short=TRUE,h_vmem=1000M -terse -j y -t $START-$END -hold_jid_ad $jid -N predict_gen_events -o $logdir/run_events_$i.log qrun_predict_gen_events.sh $executable $card $i $model $name $logdir $lower $upper $whichfit $intdir $binwidth | sed -r "s/\.(.*)//"`
    echo Submitted event job: $jid
fi

if [ $predictType == 1 ]
then
    echo qsub  -l short=TRUE,h_vmem=1000M -terse -j y -t $START-$END -N predict_gen_events -o $logdir/run_events_$i.log qrun_predict_gen_events.sh $executable $card $i $model $name $logdir $lower $upper $whichfit $intdir $binwidth
    jid=`qsub  -l short=TRUE,h_vmem=1000M -terse -j y -t $START-$END -N predict_gen_events -o $logdir/run_events_$i.log qrun_predict_gen_events.sh $executable $card $i $model $name $logdir $lower $upper $whichfit $intdir $binwidth | sed -r "s/\.(.*)//"`
    echo Submitted event job: $jid
fi
#done

lower=$upper
upper=`echo " $upper + $massBin " | bc -l`

done
