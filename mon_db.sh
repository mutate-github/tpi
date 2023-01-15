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

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB
    LOGF=$LOGDIR/mon_db_${HOST}_${DB}.log
    $WRTPI $HOST $DB db > $LOGF
# v$instance
    LOGF_INST_DIFF=$LOGDIR/mon_db_${HOST}_${DB}_inst_diff.log
    LOGF_INST_OLD=$LOGDIR/mon_db_${HOST}_${DB}_inst_old.log
    touch $LOGF_INST_OLD
    LOGF_INST=$LOGDIR/mon_db_${HOST}_${DB}_inst.log
    cat $LOGF | egrep -A3 -i INSTANCE_NAME | grep -v '\----' > $LOGF_INST
    diff $LOGF_INST_OLD $LOGF_INST > $LOGF_INST_DIFF
    rc_inst=$?

# v$database
    LOGF_DB_DIFF=$LOGDIR/mon_db_${HOST}_${DB}_db_diff.log
    LOGF_DB_OLD=$LOGDIR/mon_db_${HOST}_${DB}_db_old.log
    touch $LOGF_DB_OLD
    LOGF_DB=$LOGDIR/mon_db_${HOST}_${DB}_db.log
    cat $LOGF | egrep -A3 -i OPEN_MODE | grep -v '\----' | cut -c 1-108 | cut --complement -b '46-62' > $LOGF_DB
    diff $LOGF_DB_OLD $LOGF_DB > $LOGF_DB_DIFF
    rc_db=$?

    if [ "$rc_inst" -ne 0 -a -s $LOGF_INST_DIFF ]; then
      cat $LOGF_INST_DIFF $LOGF_INST_OLD $LOGF_INST | $WMMAIL -s "$MPREFIX INSTANCE status has been changed (host: ${HOST} / db: ${DB})" $ADMINS
    fi
    if [ "$rc_db" -ne 0 -a -s $LOGF_DB_DIFF ]; then
      cat $LOGF_DB_DIFF $LOGF_DB_OLD $LOGF_DB | $WMMAIL -s "$MPREFIX DATABASE status has been changed: (host: ${HOST} / db: ${DB})" $ADMINS
    fi
    cp $LOGF_INST $LOGF_INST_OLD
#    cp $LOGF_DB_OLD $LOGF_DB_OLD"_old.log"
    cp $LOGF_DB $LOGF_DB_OLD
#    rm $LOGF_INST_DIFF $LOGF_INST  $LOGF_DB_DIFF $LOGF_DB
  done
done

