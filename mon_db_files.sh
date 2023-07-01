#!/bin/sh

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
#MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
#WMMAIL="$BASEDIR/$MAILS"
WRTPI="$BASEDIR/rtpi"
#MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
#ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
PERCENT=90


for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB

VALUE=`cat <<EOF | ssh $HOST "/bin/sh -s $DB"
#!/bin/sh
sid=\\$1
#echo "sid="\\$sid
$SET_ENV
export ORACLE_SID=\\$sid
sqlplus -s '/as sysdba' <<'END'
set pagesize 0 feedback off verify off heading off echo off
select trunc((select count(*) from v\\$datafile)/value*100) from v\\$parameter where NAME='db_files';
END
EOF`

    VALUE=`echo $VALUE | sed -e 's/^ //'`
    echo $VALUE

    if [ "$VALUE" -gt "$PERCENT" ]; then
#      echo "" | $WMMAIL -s "$MPREFIX ${HOST} / ${DB} - db_files usage warning: (current: ${VALUE} %, threshold: ${PERCENT} %)" $ADMINS
      echo "" | $BASEDIR/send_msg.sh $HOST $DB "db_files usage warning: (current: ${VALUE} %, threshold: ${PERCENT} %)"
    fi
  done # DB
done # HOST

