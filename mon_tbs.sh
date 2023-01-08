#!/bin/sh
set -f

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL="$BASEDIR/$MAILS"
WRTPI="$BASEDIR/rtpi"
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
limPER=`$BASEDIR/iniget.sh mon.ini tbs limitPER`
limGB=`$BASEDIR/iniget.sh mon.ini tbs limitGB`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
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
       CUR_VAL=`awk '{print $NF}' $LOGF_TRG`
       echo $LST  | xargs -n7 echo | while read a b c d e f g; do
           echo "" >> $LOGF_TRG
           echo "Datafiles information:" >> $LOGF_TRG
           $WRTPI $HOST $DB df | awk '/TABLESPACE_NAME/,/Elapsed/' | sed '/^ *$/d' | egrep "^$a"  | uniq
           echo "" >> $LOGF_TRG
           echo "Growseg information last 3 hours:" >> $LOGF_TRG
           $WRTPI $HOST $DB dhash growseg $a | awk '/OBJECT_NAME/,/Elapsed/' | egrep -v "Elapsed" | head -30 >>  $LOGF_TRG
           echo "" >> $LOGF_TRG
       done  >>  $LOGF_TRG

       cat $LOGF_HEAD $LOGF_TRG | $WMMAIL -s "$MPREFIX TBS usage warning: ${HOST} / ${DB} free space too low (current: $CUR_VAL %, threshold: $limPER %)" $ADMINS
       rm $LOGF $LOGF_TRG $LOGF_HEAD
    fi
  done # DB
done # HOST

