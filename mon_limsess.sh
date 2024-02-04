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
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
PERCENT=80


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
select resource_name,current_utilization, limit_value, trunc(current_utilization/limit_value*100) percent  from v\\$resource_limit where resource_name  in ('processes','sessions');
END
EOF`

    VALUE=`echo $VALUE | sed -e 's/^ //'`
    echo $VALUE
#    processes 431 1000 43 sessions 139 1600 8

    echo $VALUE | xargs -n4 echo | while read NAME_ CURRENT_ LIMIT_ PERCENT_ ; do
      if [ "$PERCENT_" -gt "$PERCENT" ]; then
        echo "" | $BASEDIR/send_msg.sh $CONFIG $HOST $DB "$NAME_ limit warning: (current: $CURRENT_, limit: $LIMIT_, threshold: ${PERCENT} % , now: $PERCENT_ )"
      fi
    done

  done # DB
done # HOST

