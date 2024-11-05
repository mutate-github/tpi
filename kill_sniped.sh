#!/bin/bash

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
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=$(<$SET_ENV_F)
PERCENT=90

for HOST in $(xargs -n1 echo <<< "$HOSTS"); do
  echo "HOST="$HOST
  $BASEDIR/test_ssh.sh $CLIENT $HOST
  if [ "$?" -ne 0 ]; then echo "test_ssh.sh not return 0, continue"; continue; fi
  DBS=$($BASEDIR/iniget.sh $CONFIG $HOST db)
  for DB in $(xargs -n1 echo <<< "$DBS"); do
    echo "DB="$DB

echo -e "#!/bin/bash
sid=\$1
echo 'sid='\$sid
$SET_ENV
export ORACLE_SID=\$sid
tmpfile=/tmp/kill_sniped_tmp.\$\$
echo 'tempfile: ' \$tmpfile
sqlplus -s '/ as sysdba' <<'END' > \$tmpfile
set pagesize 0 lines 255 feedback off verify off heading off echo off timing off
rem spool \$tmpfile
select 'date > '||to_char(sysdate,'dd/mm/yyyy hh24:mi:ss') from dual;
column username format a15
column osuser format a12
column machine format a20
column terminal format a15
column module format a30
column action format a6
column logon_time format a19
column spid format a10
select s.username,s.osuser,s.machine,s.terminal,s.module,s.action,to_char(s.logon_time,'dd/mm/yyyy hh24:mi:ss') logon_time,p.spid from v\$process p,v\$session s where s.paddr=p.addr and s.status in ('SNIPED','KILLED') and s.server = 'DEDICATED';
select p.spid from v\$process p,v\$session s
where s.paddr=p.addr
and s.status in ('SNIPED','KILLED') and s.server = 'DEDICATED';
END
for x in $(grep '^[0123456789]' <<< $tmpfile)
 do
  kill -9 \$x
#  echo  \$x
 done
rm \$tmpfile
" | ssh $HOST "/bin/bash -s $DB"

  done # DB
done # HOST

