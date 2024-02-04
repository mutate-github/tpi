#!/bin/sh
set -f

CLIENT="$1"
CONFIG="mon.ini"
if [ -n "$CLIENT" ]; then
  shift
  CONFIG=${CONFIG}.${CLIENT}
  if [ ! -s "$CONFIG" ]; then echo "Exiting... Config not found: "$CONFIG ; exit 128; fi
fi
echo "Using config: ${CONFIG}"

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
WRTPI="$BASEDIR/rtpi"
HOSTS=`$BASEDIR/iniget.sh $CONFIG servers host`
limPER=`$BASEDIR/iniget.sh $CONFIG tbs limitPER`
limGB=`$BASEDIR/iniget.sh $CONFIG tbs limitGB`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh $CONFIG $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB
    LOGF=$LOGDIR/mon_tbs_${HOST}_${DB}.log
    LOGF_TRG=$LOGDIR/mon_tbs_${HOST}_${DB}_trg.log
    LOGF_HEAD=$LOGDIR/mon_tbs_${HOST}_${DB}_heading_$$.log
    $WRTPI $HOST $DB tbs free | awk '/Tablespace Name/,/Elapsed/' | egrep -v "Elapsed" > $LOGF
    awk -v lim=$limPER '{if($NF+0>=lim) {print $0}}' $LOGF > $LOGF_TRG

    if [ -s $LOGF_TRG ]; then
       echo "Fired: "$0"\n" > $LOGF_HEAD
       head -2 $LOGF >> $LOGF_HEAD
       LST=`cat $LOGF_TRG`
       CUR_VAL=`awk '{print $NF}' $LOGF_TRG | head -1`
       echo $LST  | xargs -n7 echo | while read a b c d e f g; do
           echo "" >> $LOGF_TRG
           echo "Datafiles information:" >> $LOGF_TRG
           $WRTPI $HOST $DB df | awk '/TABLESPACE_NAME/,/Elapsed/' | sed '/^ *$/d' | egrep "^$a"  | uniq
#           echo "" >> $LOGF_TRG
#           echo "Growseg information last 3 hours:" >> $LOGF_TRG
#           $WRTPI $HOST $DB dhash growseg $a | awk '/OBJECT_NAME/,/Elapsed/' | egrep -v "Elapsed" | head -30 >>  $LOGF_TRG
#           echo "" >> $LOGF_TRG
       done  >>  $LOGF_TRG

       cat $LOGF_HEAD $LOGF_TRG  | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "TBS usage warning: free space too low current: ${CUR_VAL}%, threshold: ${limPER}%"
       rm $LOGF $LOGF_TRG $LOGF_HEAD
    fi
  done # DB
done # HOST

