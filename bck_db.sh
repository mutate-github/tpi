#!/bin/bash
set -f

WMMAIL=`which mmail`
BASEDIR=`dirname $0`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
TARGET=`$BASEDIR/iniget.sh mon.ini backup target`
CATALOG=`$BASEDIR/iniget.sh mon.ini backup catalog`
TNS_CATALOG=`$BASEDIR/iniget.sh mon.ini backup tns_catalog`
HOST_DB_SET=`$BASEDIR/iniget.sh mon.ini backup host:db:set`
shopt -s extglob
LEVEL0="+("`$BASEDIR/iniget.sh mon.ini backup level0 | sed 's/,/|/g'`")"
LEVEL1="+("`$BASEDIR/iniget.sh mon.ini backup level1 | sed 's/,/|/g'`")"
LEVEL2="+("`$BASEDIR/iniget.sh mon.ini backup level2 | sed 's/,/|/g'`")"
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
me=$$
ONE_EXEC_F=$BASEDIR/one_exec_bck_db_${me}.sh

for HDS in `echo "$HOST_DB_SET" | xargs -n1 echo`; do
  HOST=`echo $HDS | awk -F: '{print $1}'`
  DB=`echo $HDS | awk -F: '{print $2}'`
  NAS=`echo $HDS | awk -F: '{print $3}'`
  echo "DEBUG HOST DB NAS="$HOST" "$DB" "$NAS

  logf="$BASEDIR/log/bck_db_${HOST}_${DB}_`date '+%m%di_%H-%M'`.log"
  exec > $logf 2>&1
  #exec &> >(tee -a "$logf")

  echo "Checking if previous script did finish..."
  not_me=`date +%H:%M`
  echo $not_me
  ps -ef | egrep "[b]ck_db.sh" | grep -v "$not_me"
  if [ $? -eq 0 ]; then
    echo "Previous script did not finish."
    echo "Cancelling today's backup and exiting ..."
    exit 0
  fi

  WD=`date +"%a"`
  echo "WD="$WD
  case $WD in
    ${LEVEL0}) LVL=0 ;;
    ${LEVEL1}) LVL=1 ;;
    ${LEVEL2}) LVL=2 ;;
    *)         LVL=0 ;  not_backed="not backed up since time 'sysdate-1'" ;;
  esac
  echo "DEBUG LEVEL0="$LEVEL0
  echo "DEBUG LEVEL1="$LEVEL1
  echo "DEBUG LEVEL2="$LEVEL2
  echo "DEBUG LVL="$LVL

  RP=`echo $HDS | awk -F: '{print $4}' | sed 's/_/ /g'`
  shopt -s nocasematch
  if [[ "$RP" =~ "WINDOW" ]]; then DAYS="DAYS"; else DAYS=""; fi
  shopt -u nocasematch
  RP2=`echo $HDS | awk -F: '{print $5}'`
  RETENTION="CONFIGURE RETENTION POLICY TO "$RP" "$RP2" ${DAYS};"
  echo "DEBUG RETENTION="$RETENTION

cat << EOF_CREATE_F1 > $ONE_EXEC_F
#!/bin/sh
sid=\$1
# echo "sid="\$sid
$SET_ENV
export ORACLE_SID=\$sid

echo "START BACKUP > HOST: $HOST, DB: $DB,  LEVEL-$LVL at `date`"
echo "======================================================================"
echo "alter system set control_file_record_keep_time=60;" | sqlplus '/as sysdba'

\$ORACLE_HOME/bin/rman target $TARGET $CATALOG $TNS_CATALOG << EOF
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/$NAS/$DB/ctl_%d_%F';
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
run {
  allocate channel cpu1 type disk;
  allocate channel cpu2 type disk;
  backup AS COMPRESSED BACKUPSET incremental level = $LVL database filesperset 1 $not_backed
  format '/$NAS/$DB/level_${LVL}_%d_%t_%U';
  sql 'alter system archive log current';
  backup archivelog all format '/$NAS/$DB/logs_%d_%t_%U' delete input;
  backup spfile format '/$NAS/$DB/spfile_%d_%U.bck';
}
EOF

echo "FINISH BACKUP > HOST: $HOST, DB: $DB  LEVEL-$LVL at `date`"
echo "======================================================================"

echo "START DELETE REDUNDANT BACKUPSET > HOST: $HOST, DB: $DB at `date`"
echo "--------------------------------------------------------------------"

\$ORACLE_HOME/bin/rman target $TARGET $CATALOG $TNS_CATALOG <<EOF
allocate channel for maintenance type disk;
$RETENTION
delete noprompt obsolete;
EOF

echo "FINISH DELETE REDUNDANT BACKUPSET > HOST: $HOST, DB: $DB at `date`"
echo "--------------------------------------------------------------------"

echo "Backups last 30 days stats:"
sqlplus -s '/ as sysdba' <<'EOS'
set lines 230 pages 100 feedback off tab off
column OUTPUT_DEVICE_TYPE for a18
column start_time for a20
column end_time for a20
column input_mbytes for 999999999
column output_mbytes for 999999999
column compress_ratio for 99999
column status for a25
column input_type for a10
column dow for a10
column time_taken_display for a18
column d for 9999999
column i0 for 9999999
column i1 for 9999999
column i2 for 9999999
select   j.OUTPUT_DEVICE_TYPE,
         to_char(j.start_time, 'yyyy-mm-dd hh24:mi:ss') start_time,
         to_char(j.end_time, 'yyyy-mm-dd hh24:mi:ss') end_time,
         j.time_taken_display,
         trunc(j.input_bytes/1024/1024) input_mbytes, trunc(j.output_bytes/1024/1024) output_mbytes,
         CASE
             WHEN input_bytes / DECODE (output_bytes, 0, NULL, output_bytes) >  1
             THEN trunc(input_bytes / DECODE (output_bytes, 0, NULL, output_bytes))
             ELSE 1
         END  compress_ratio,
         j.status, j.input_type,
         decode(to_char(j.start_time, 'd'), 1, 'Sunday', 2, 'Monday', 3, 'Tuesday', 4, 'Wednesday', 5, 'Thursday', 6, 'Friday', 7, 'Saturday') dow,
         x.D, x.I0, x.I1, x.I2
from V\$RMAN_BACKUP_JOB_DETAILS j
  left outer join (select d.session_recid, d.session_stamp,
                       sum(case when d.backup_type = 'D' then d.pieces else 0 end) D,
                       sum(case when d.backup_type||d.incremental_level = 'I0' then d.pieces else 0 end) I0,
                       sum(case when d.backup_type||d.incremental_level = 'I1' then d.pieces else 0 end) I1,
                       sum(case when d.backup_type||d.incremental_level = 'I2' then d.pieces else 0 end) I2
                   from V\$BACKUP_SET_DETAILS d join V\$BACKUP_SET s
                     on s.set_stamp = d.set_stamp and s.set_count = d.set_count
                   where s.input_file_scan_only = 'NO' and d.backup_type in ('D','I')
                   group by d.session_recid, d.session_stamp) x
    on x.session_recid = j.session_recid and x.session_stamp = j.session_stamp
where j.start_time > trunc(sysdate)-30 and j.input_type='DB INCR'
--where j.start_time = (select max(start_time) from V\$RMAN_BACKUP_JOB_DETAILS where start_time>sysdate-30 and input_type='DB INCR')
order by j.start_time;
EOS
EOF_CREATE_F1

  cat ${ONE_EXEC_F} | ssh oracle@$HOST "/bin/sh -s $DB" >> $logf

  rc=`sed '/^$/d' $logf | tail -1 | awk '{print $10}'`
  echo "rc="$rc
  if [ "$rc" = "COMPLETED" ]; then
    BCK_STATUS=" completed with SUCCESS"
  else
    BCK_STATUS=" completed with FAILURE"
  fi

  echo "" > $logf.mail.log
  sed -n '/Backups last/,$p' $logf  >> $logf.mail.log
  echo "" >> $logf.mail.log
  echo "Details:" >> $logf.mail.log
  echo "----------------------------------------------------------------------" >> $logf.mail.log
  egrep -i "input |oradata|LEVEL-|/oracle|error|REDUNDANT|RMAN-" $logf          >> $logf.mail.log
  echo "----------------------------------------------------------------------" >> $logf.mail.log

  cat $logf.mail.log | $WMMAIL -s "BACKUP on HOST:$HOST, DB:$DB "$BCK_STATUS $ADMINS 2>/dev/null

#  rm ${logf}.mail.log
  find $BASEDIR/log -name "bck_db_*.log" -mtime +31 -exec rm -f {} \;

done  # for $HDS

