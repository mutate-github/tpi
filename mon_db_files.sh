#!/bin/bash

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
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
PERCENT=90


for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh $CONFIG $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB

VALUE=`cat <<EOF | ssh $HOST "/bin/bash -s $DB"
#!/bin/bash
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
      echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "db_files usage warning: (current: ${VALUE} %, threshold: ${PERCENT} %)"
    fi
  done # DB
done # HOST

