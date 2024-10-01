#!/bin/bash
set -f

CLIENT="$1"
BASEDIR=$(dirname $0)
CONFIG="mon.ini"
if [ -n "$CLIENT" ]; then
  shift
  CONFIG=${CONFIG}.${CLIENT}
  if [ ! -s "$BASEDIR/$CONFIG" ]; then echo "Exiting... Config not found: "$CONFIG ; exit 128; fi
fi
echo "Using config: ${CONFIG}"

LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
WRTPI="$BASEDIR/rtpi"
HOSTS=$($BASEDIR/iniget.sh $CONFIG servers host)

for HOST in $(xargs -n1 echo <<< "$HOSTS"); do
  echo "HOST="$HOST
  ssh -q $HOST exit && : || ( echo "SSH on $HOST not answered. loop for hosts continues..."; $BASEDIR/send_msg.sh $CONFIG $HOST NULL "SSH on $HOST not answered"; continue)
  DBS=$($BASEDIR/iniget.sh $CONFIG $HOST db)
  for DB in $(xargs -n1 echo <<< "$DBS"); do
    echo "DB="$DB
    LOGF=$LOGDIR/mon_db_${HOST}_${DB}.log
    $WRTPI $HOST $DB db | sed -n '/v$instance:/,/v$database:/p' | egrep -v '\----|v\$database:' | sed '/^$/d' > $LOGF

    LOGF_DB_DIFF=$LOGDIR/mon_db_${HOST}_${DB}_db_diff.log
    LOGF_DB_OLD=$LOGDIR/mon_db_${HOST}_${DB}_db_old.log
    touch $LOGF_DB_OLD
    LOGF_DB=$LOGDIR/mon_db_${HOST}_${DB}_db.log
    cat $LOGF | sed -n '1,3p' > $LOGF_DB
    diff $LOGF_DB_OLD $LOGF_DB > $LOGF_DB_DIFF

    if [ -s $LOGF_DB_DIFF ]; then
        cat $LOGF_DB_DIFF | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "DB status has been changed:"
    fi
    cp $LOGF_DB $LOGF_DB_OLD
    rm $LOGF_DB_DIFF $LOGF_DB
  done
done

