#!/bin/sh
set -f

WRTPI=`which rtpi`
BASEDIR=`dirname $0`
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL=`which $MAILS`
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
limPER=`$BASEDIR/iniget.sh mon.ini fra limitPER`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB
    LOGF=$BASEDIR/log/mon_fra_${HOST}_${DB}.log
    LOGF_HEAD=$BASEDIR/log/mon_fra_${HOST}_${DB}_head.log
    LOGF_TRG=$BASEDIR/log/mon_fra_${HOST}_${DB}_trg.log
    $WRTPI $HOST $DB fra | awk '/PCT_FULL/,/Elapsed/' | egrep -v "Elapsed" > $LOGF
    awk -v lim=$limPER '{if($NF+0>=lim) {print $0}}' $LOGF >  $LOGF_TRG

    if [ -s $LOGF_TRG ]; then
      echo "Fired: "$0"\n" > $LOGF_HEAD
      CUR_VAL=`cat $LOGF_TRG | tail -1 |  awk '{print $NF}'`
      cat $LOGF_HEAD $LOGF | $WMMAIL -s "$MPREFIX FRA usage warning: ${HOST} / ${DB} (current: $CUR_VAL %, threshold: $limPER %)" $ADMINS
      rm $LOGF_HEAD
    fi
    rm $LOGF $LOGF_TRG
  done # DB
done # HOST
