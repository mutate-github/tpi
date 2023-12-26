#!/bin/sh
set -f

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
#MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
#WMMAIL="$BASEDIR/$MAILS"
WRTPI="$BASEDIR/rtpi"
#MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
#ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB
    LOGF=$LOGDIR/mon_db_${HOST}_${DB}.log
#    $WRTPI $HOST $DB db | sed -n '/v$instance:/,/DBA_REGISTRY/p'| grep -v DBA_REGISTRY | grep -v '\----' | sed '/^$/d' > $LOGF
    $WRTPI $HOST $DB db | sed -n '/v$instance:/,/v$database:/p' | egrep -v '\----|v\$database:' | sed '/^$/d' > $LOGF

    LOGF_DB_DIFF=$LOGDIR/mon_db_${HOST}_${DB}_db_diff.log
    LOGF_DB_OLD=$LOGDIR/mon_db_${HOST}_${DB}_db_old.log
    touch $LOGF_DB_OLD
    LOGF_DB=$LOGDIR/mon_db_${HOST}_${DB}_db.log
    cat $LOGF | sed -n '1,3p' > $LOGF_DB
    cat $LOGF | sed -n '4,6p' | cut -c 1-108 >> $LOGF_DB
    diff $LOGF_DB_OLD $LOGF_DB > $LOGF_DB_DIFF

    if [ -s $LOGF_DB_DIFF ]; then
#        ( cat $LOGF_DB_DIFF ; echo "Old_status:" ; cat $LOGF_DB_OLD ; echo "" ; echo  "Current_status:" ; cat $LOGF_DB ) | $WMMAIL -s "$MPREFIX DATABASE status has been changed: (host: ${HOST} / db: ${DB})" $ADMINS
        cat $LOGF_DB_DIFF | $BASEDIR/send_msg.sh $HOST $DB "DB status has been changed:"
    fi
    cp $LOGF_DB $LOGF_DB_OLD
#    rm  $LOGF_DB_DIFF $LOGF_DB
  done
done

