#!/bin/bash
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
THRESHOLD=`$BASEDIR/iniget.sh $CONFIG locks threshold`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh $CONFIG $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB
    LOGF=$LOGDIR/mon_lock_${HOST}_${DB}.log
    $WRTPI $HOST $DB lock  > $LOGF
    CUR_VAL=$(egrep "Waiter" $LOGF | awk '{print $NF}' | sort -n | awk -v lim=$THRESHOLD '{if($NF+0>=lim) {print $NF}}')

    if [ -n "$CUR_VAL" ]; then
       cat $LOGF | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "Locks warning: (current: $CUR_VAL min, threshold: $THRESHOLD min)"
       rm $LOGF 
    fi
  done # DB
done # HOST

