#!/bin/sh
#
# usage: startall_purge_traces.sh 
# Talgat Mukhametshin dba.almaty@gmail.com t.mukhametshin@db-service.ru

BASEDIR=$(dirname $0)
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
HOSTS=$($BASEDIR/iniget.sh mon.ini servers host)
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=$(cat $SET_ENV_F)
SCRIPT_NAME="$BASEDIR/purge_traces.sh"

cat <<EOFF >  $SCRIPT_NAME
#!/bin/sh

# ps -ef | awk -F_ '/[p]mon/{print \$NF}' | while read i; do ./purge_traces.sh \$i; done
#
# usage purge_traces.sh \$ORACLE_SID
# Talgat Mukhametshin dba.almaty@gmail.com
if [ "\$1" = "" ]; then
    echo "Usage: \$0 sid"
    exit
fi

sid=\$1

# 3600  - 2.5 days
# 4320  - 3 days
# 5760  - 4 days
# 10080 - 7 days

age=1440         # min
audit=7          # days
size_lim=256M    # size limit for lsn.log

$SET_ENV

export ORACLE_SID=\$sid

trc=\$(echo "show homes;"  | adrci | grep 'diag/rdbms/.*/'\$sid'$')
tns3=\$(echo "show homes;"  | adrci | grep 'diag/tnslsnr/.*/')

echo "set home for diag/rdbms traces: "\$trc
echo "set home for listener tns3: "\$tns3
echo "age: "\$age

for trc_ in \$(echo \$trc | xargs); do
  echo "purge diag/rdbms/ ALERT TRACE INCIDENT: "\$trc_
  adrci exec="set home \$trc_ ; migrate schema"
  adrci exec="set home \$trc_ ; purge -age \$age -type ALERT"
  adrci exec="set home \$trc_ ; purge -age \$age -type TRACE"
  adrci exec="set home \$trc_ ; purge -age \$age -type INCIDENT"
done

VALUE=\$(sqlplus -s '/as sysdba' <<'EOS'
set lines 250  heading off feedback off pagesize 0 trimspool on timing off
select value from v\$system_parameter where name='diagnostic_dest';
EOS
)

echo "diagnostic_dest: "\$VALUE

for tns3_ in \$(echo \$tns3 | xargs); do
  echo "purge listener ALERT TRACE: "\$tns3_
  adrci exec="set home \$tns3_ ; migrate schema"
  adrci exec="set home \$tns3_ ; purge -age \$age -type ALERT"
  adrci exec="set home \$tns3_ ; purge -age \$age -type TRACE"
  find \$VALUE/\$tns3_/trace -type f -name "*lsn*.log" -size +\$size_lim
  find \$VALUE/\$tns3_/trace -type f -name "*lsn*.log" -size +\$size_lim -exec /bin/bash -c 'echo > {}' \;
done

VALUE=\$(sqlplus -S '/ as sysdba' <<'END'
  set pagesize 0 feedback off verify off heading off echo off timing off
  col value for a200
  select value from v\$parameter where name='audit_file_dest';
END
)

echo "purge audit logs for \$VALUE :"
find \$VALUE  -type f -mtime +\$audit -name "*.aud" | xargs -i -P20 rm {}
find \$VALUE  -type f -mtime +\$audit -name "*.aud" -exec rm {} \;
EOFF

chmod u+x $SCRIPT_NAME

for HOST in $(echo "$HOSTS" | xargs -n1 echo); do
  DBS=$($BASEDIR/iniget.sh mon.ini $HOST db)
  for DB in  $(echo "$DBS" | xargs -n1 echo); do
    echo "HOST=$HOST  DB=$DB  "$(date)
    cat $SCRIPT_NAME | ssh oracle@$HOST "/bin/sh -s $DB"
  done # DB
done # HOST

# rm $SCRIPT_NAME

