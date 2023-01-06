#!/bin/bash
set -f

WMMAIL=`which mmail`
BASEDIR=`dirname $0`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
TARGET=`$BASEDIR/iniget.sh mon.ini backup target`
CATALOG=`$BASEDIR/iniget.sh mon.ini backup catalog`
TNS_CATALOG=`$BASEDIR/iniget.sh mon.ini backup tns_catalog`
HOST_DB_SET=`$BASEDIR/iniget.sh mon.ini backup host:db:set`
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
me=$$
ONE_EXEC_F=$BASEDIR/one_exec_bck_logs_${me}.sh

for HDS in `echo "$HOST_DB_SET" | xargs -n1 echo`; do
  HOST=`echo $HDS | awk -F: '{print $1}'`
  DB=`echo $HDS | awk -F: '{print $2}'`
  NAS=`echo $HDS | awk -F: '{print $3}'`
  echo "DEBUG HOST DB NAS="$HOST" "$DB" "$NAS

  logf="$BASEDIR/log/bck_logs_${HOST}_${DB}.log"
  exec >> $logf 2>&1

  a=`ps -eo 'pid,ppid,args' | egrep "$0" | egrep -v "$$" | egrep -v [e]grep`
  echo -e "a="$a
  a0=`ps -eo 'pid,ppid,args' | egrep "$0" | egrep -v "$$" | egrep -v [e]grep | wc -l`
  echo "a0="$a0
  if [ "$a0" -gt "1" ]; then
    echo "Script "$0" already running.. Exiting..."
    ps -eo 'pid,ppid,args' | egrep "$0" | egrep -v "$$" | egrep -v [e]grep
    echo "Others ps -ef:"
    ps -ef | grep "$0" | grep -v [g]rep
    exit 128
  fi

  ps -eo "pid,ppid,args" | egrep "[b]ck_db.sh" | egrep -v [e]grep
  if [ $? -eq 0 ]; then
    echo "Backup script: bck_db.sh is running. Exitting ..."
    exit 128
  fi

cat << EOF_CREATE_F1 > $ONE_EXEC_F
#!/bin/sh
sid=\$1
# echo "sid="\$sid
$SET_ENV
export ORACLE_SID=\$sid

echo "START ARCHIVELOGS BACKUP > HOST: $HOST, DB: $DB at `date`"
echo "======================================================================"

\$ORACLE_HOME/bin/rman target $TARGET $CATALOG $TNS_CATALOG << EOF
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/$NAS/$DB/ctl_%d_%F';
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
run{
  allocate channel cpu1 type disk;
  allocate channel cpu2 type disk;
  backup AS COMPRESSED BACKUPSET filesperset = 20 archivelog all
  not backed up 1 times
  format '/$NAS/$DB/logs_%d_%t_%U'
  delete input;
}
EOF
echo "FINISH ARCHIVELOGS BACKUP > HOST: $HOST, DB: $DB at `date`"
echo "======================================================================"
EOF_CREATE_F1

  cat ${ONE_EXEC_F} | ssh oracle@$HOST "/bin/sh -s $DB" >> $logf
  rm $ONE_EXEC_F
done

