#!/bin/sh
set -f

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
#MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
#WMMAIL="$BASEDIR/$MAILS"
WRTPI="$BASEDIR/rtpi"
#MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
#ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
THRESHOLD=`$BASEDIR/iniget.sh mon.ini locks threshold`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB
    LOGF=$LOGDIR/mon_lock_${HOST}_${DB}.log
    $WRTPI $HOST $DB lock  > $LOGF
    CUR_VAL=`egrep "HOLDER|Waiter" $LOGF | sort -nk 11 | head -1 | awk -v lim=$THRESHOLD '{if($NF+0>=lim) {print $NF}}'`

    if [ -n "$CUR_VAL" ]; then
#       cat $LOGF | $WMMAIL -s "$MPREFIX Locks warning: ${HOST} / ${DB}  (current: $CUR_VAL min, threshold: $THRESHOLD min)" $ADMINS
       cat $LOGF | $BASEDIR/send_msg.sh $HOST $DB "Locks warning: (current: $CUR_VAL min, threshold: $THRESHOLD min)"
       rm $LOGF 
    fi
  done # DB
done # HOST

