#!/bin/sh
set -f
BASEDIR=`dirname $0`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
WMMAIL=`which mmail`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
PART_OF_DAY=`$BASEDIR/iniget.sh mon.ini alert part_of_day`
EXCLUDE=`$BASEDIR/iniget.sh mon.ini alert exclude`

SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
me=$$
ONE_EXEC_F=$BASEDIR/one_exec_mon_adrci_alert_${me}.sh

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
#  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in `echo "$DBS" | xargs -n1 echo`; do
#    echo "DB="$DB
    LOGFILE=$BASEDIR/log/mon_alert_adrci_${HOST}_${DB}_log.txt
    LOGHEAD=$BASEDIR/log/mon_alert_adrci_${HOST}_${DB}_head.txt

cat << EOF_CREATE_F1 > $ONE_EXEC_F
#!/bin/sh
sid=\$1
# echo "sid="\$sid
$SET_ENV
export ORACLE_SID=\$sid
EOF_CREATE_F1

cat << 'EOF_CREATE_F2' >> $ONE_EXEC_F
VALUEP=`sqlplus -S '/ as sysdba' <<'END'
set lines 230 pagesize 0 feedback off verify off heading off echo off timing off
select substr(platform_name,1,instr(platform_name,' ',1,1)) from v$database;
END`
VALUEP=`echo $VALUEP | tr -d '\r'`
case $VALUEP in
  Microsoft*) SLASH='\' ;;
           *) SLASH='/' ;;
esac
PATH_TO_ALERT=`sqlplus -S '/ as sysdba' <<EOS
set lines 250 pagesize 0 feedback off verify off heading off echo off
column value for a200
select value || '$SLASH' || 'alert_$ORACLE_SID.log' from V\\$DIAG_INFO where name='Diag Trace';
EOS`
echo $PATH_TO_ALERT
adrci_homes=( $(adrci exec="show homes" | egrep -e "rdbms.*${ORACLE_SID}" ))
for adrci_home in ${adrci_homes[@]} ; do
#  adrci exec="set home ${adrci_home}; show alert -p \\\"message_text like '%ORA-%' and originating_timestamp > systimestamp-1/24\\\"" -term
#done
EOF_CREATE_F2

EXCLUDE_STR=`echo $EXCLUDE | xargs -n1 echo | while read i; do echo "message_text not like \'%$i%\' and " ; done | xargs`

cat << EOF_CREATE_F3 >> $ONE_EXEC_F
  adrci exec="set home \${adrci_home}; show alert -p \\\\\"message_text like '%ORA-%' and  $EXCLUDE_STR originating_timestamp > systimestamp-1/${PART_OF_DAY}\\\\\"" -term
done
EOF_CREATE_F3

cat ${ONE_EXEC_F} | ssh oracle@$HOST "/bin/sh -s $DB" | egrep -va "ADR|[*].*" > $LOGFILE

head -2 $LOGFILE > $LOGHEAD
cat $LOGFILE | tail -n +2 | sed '/^ *$/d' > $LOGFILE.new.txt
mv $LOGFILE.new.txt $LOGFILE

if [ -s $LOGFILE ];then
  cat $LOGHEAD  $LOGFILE | $WMMAIL -s "ALERT_LOG warning: $HOST / $DB" $ADMINS
fi

rm $LOGHEAD $LOGFILE $ONE_EXEC_F

  done  # for DB
done   # for HOST

