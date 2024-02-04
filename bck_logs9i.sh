#!/bin/bash
set -f

etime=`ps -eo 'pid,etime,args' | grep $0 | awk '!/grep|00:0[0123]/{print $2}'`
echo "etime: "$etime
if [[ -n "$etime" ]] && [[ ! "$etime" =~ "00:0[0123]" ]]; then
   echo "Previous script did not finish. "`date`
   ps -eo 'pid,ppid,lstart,etime,args' | grep $0 | awk '!/grep|00:0[0123]/'
   echo "Cancelling today's backup and exiting ..."
   exit 127
fi

# $1 is optional parameter, sample usage:
# $0 vhost0:jet:nas:REDUNDANCY:1:nocatalog:0   - start single backup archivelogs with partucular parameters
# $0 vhost0                                    - start multiple backups archivelogs with partucular parameters from mon.ini
HDSALL=$1
echo `date`"   HDSALL: "$HDSALL

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
TARGET=`$BASEDIR/iniget.sh mon.ini backup target`
TNS_CATALOG=`$BASEDIR/iniget.sh mon.ini backup tns_catalog`
HOST_DB_SET=`$BASEDIR/iniget.sh mon.ini backup host:db:set`
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
me=$$
ONE_EXEC_F=$BASEDIR/one_exec_bck_logs_${me}.sh

if [ -z "$HDSALL" ]; then
  HDSLST=$HOST_DB_SET
else
  if [[ "$HDSALL" =~ ":" ]]; then
    HDSLST=$HDSALL
  else
    HDSLST=`$BASEDIR/iniget.sh mon.ini backup host:db:set | grep "$HDSALL"`
  fi
fi

for HDS in `echo "$HDSLST" | xargs -n1 echo`; do
  HOST=`echo $HDS | awk -F: '{print $1}'`
  DB=`echo $HDS | awk -F: '{print $2}'`
  NAS=`echo $HDS | awk -F: '{print $3}'`
  echo "DEBUG HOST="$HOST"   DB="$DB"   NAS="$NAS

  logf="$LOGDIR/bck_logs_${HOST}_${DB}.log"
  exec >> $logf 2>&1

  CATALOG=`echo $HDS | awk -F: '{print $6}'`
  shopt -s nocasematch
  if [[ "$CATALOG" = nocatalog ]]; then
     TNS_CATALOG=""
  fi
  shopt -u nocasematch

cat << EOF_CREATE_F1 > $ONE_EXEC_F
#!/bin/sh
sid=\$1
# echo "sid="\$sid
$SET_ENV
export ORACLE_SID=\$sid

INF_STR="HOST: $HOST, DB: $DB, NAS: $NAS, CATALOG: $CATALOG $TNS_CATALOG"

echo "START ARCHIVELOGS BACKUP > \$INF_STR  at `date`"
echo "==========================================================================================================================="

\$ORACLE_HOME/bin/rman target $TARGET $CATALOG $TNS_CATALOG << EOF
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/$NAS/$DB/ctl_%d_%F';
run{
  allocate channel cpu1 type disk;
  allocate channel cpu2 type disk;
  backup archivelog until time 'sysdate' not backed up 1 times format '/$NAS/$DB/logs_%d_%t_%U' delete input tag 'ARCHIVELOGS';
}
EOF
echo "FINISH ARCHIVELOGS BACKUP > \$INF_STR at `date`"
echo "==========================================================================================================================="
EOF_CREATE_F1

  cat ${ONE_EXEC_F} | ssh oracle@$HOST "/bin/sh -s $DB" >> $logf
  rm $ONE_EXEC_F
done

