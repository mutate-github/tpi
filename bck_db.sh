#!/bin/bash
set -f

etime=`ps -eo 'pid,etime,args' | grep $0 | sort -nk2 | head -1 | awk '!/grep|00:00/{print $2}'`
echo "etime: "$etime

#if [ -n "$etime" -a "$etime" != "00:00" ]; then
#   echo "Previous script did not finish. "`date`
#   ps -eo 'pid,ppid,lstart,etime,args' | grep $0 | awk '!/grep|00:00/'
#   echo "Cancelling today's backup and exiting ..."
#   exit 0
#fi

# $1 is optional parameter, sample usage:
# $0 kikdb02:cft:u15:REDUNDANCY:1:nocatalog:0   - start single backup with partucular parameters
# $0 kikdb02                                    - start multiple backups with partucular parameters from mon.ini
HDSALL=$1
DS_=`date '+%m%d_%H-%M'`
echo $DS_"   HDSALL: "$HDSALL

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL="$BASEDIR/$MAILS"
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
TARGET=`$BASEDIR/iniget.sh mon.ini backup target`
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

if [ -z "$HDSALL" ]; then
  HDSLST=$HOST_DB_SET
else
  if [[ "$HDSALL" =~ ":" ]]; then
    HDSLST=$HDSALL
  else
    HDSLST=`$BASEDIR/iniget.sh mon.ini backup host:db:set | grep "$HDSALL"`
  fi
fi

LOGF_TOTAL="$LOGDIR/bck_db_total_${DS_}.log"
echo "Start time: "$DS_  > $LOGF_TOTAL

for HDS in `echo $HDSLST | xargs -n1 echo`; do
  HOST=`echo $HDS | awk -F: '{print $1}'`
  DB=`echo $HDS | awk -F: '{print $2}'`
  NAS=`echo $HDS | awk -F: '{print $3}'`
  RP=`echo $HDS | awk -F: '{print $4}' | sed 's/_/ /g'`
  RP2=`echo $HDS | awk -F: '{print $5}'`
  CATALOG=`echo $HDS | awk -F: '{print $6}'`
  LVL=`echo $HDS | awk -F: '{print $7}'`

  logf="$LOGDIR/bck_db_${HOST}_${DB}_`date '+%m%d_%H-%M'`.log"
  exec > $logf 2>&1
  #exec &> >(tee -a "$logf")

  shopt -s nocasematch
  if [[ "$RP" =~ "WINDOW" ]]; then DAYS="DAYS"; else DAYS=""; fi
  RETENTION="CONFIGURE RETENTION POLICY TO "$RP" "$RP2" ${DAYS};"
  if [[ "$CATALOG" = nocatalog ]]; then
     TNS_CATALOG=""
  fi
  shopt -u nocasematch

  if [ -z "$LVL" ]; then
    WD=`date +"%a"`
    case $WD in
      ${LEVEL0}) LVL=0 ;;
      ${LEVEL1}) LVL=1 ;;
      ${LEVEL2}) LVL=2 ;;
      *)         LVL=0 ;  not_backed="not backed up since time 'sysdate-1'" ;;
    esac
  fi
#   echo "DEBUG LVL="$LVL

cat << EOF_CREATE_F1 > $ONE_EXEC_F
#!/bin/sh
sid=\$1
# echo "sid="\$sid
$SET_ENV
export ORACLE_SID=\$sid

INF_STR="HOST: $HOST, DB: $DB, NAS: $NAS, RET_POL: $RP $RP2, CATALOG: $CATALOG, LEVEL: $LVL"

echo "START BACKUP > \$INF_STR at `date`"
echo "=============================================================================================================="

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
  format '/$NAS/$DB/level_${LVL}_%d_%t_%U' TAG 'LEVEL_${LVL}';
  backup archivelog all format '/$NAS/$DB/logs_%d_%t_%U' delete input TAG 'ARCHIVELOGS';
  backup spfile format '/$NAS/$DB/spfile_%d_%U.bck' TAG 'SPFILE';
}
EOF

echo "FINISH BACKUP > \$INF_STR at `date`"
echo "=============================================================================================================="

echo "START DELETE REDUNDANT BACKUPSET > \$INF_STR at `date`"
echo "--------------------------------------------------------------------------------------------------------------"

VALUE=\`sqlplus -s '/as sysdba' <<'END'
set pagesize 0 feedback off verify off heading off echo off
select database_role from v\$database;
END\`
echo "VALUE of database_role: "\$VALUE
if [[ "\$VALUE" =~ "PRIMARY" ]]; then
  RETENTION_="$RETENTION"
fi

\$ORACLE_HOME/bin/rman target $TARGET $CATALOG $TNS_CATALOG <<EOF
allocate channel for maintenance type disk;
\$RETENTION_
delete noprompt obsolete;
EOF

echo "FINISH DELETE REDUNDANT BACKUPSET > \$INF_STR at `date`"
echo "--------------------------------------------------------------------------------------------------------------"

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
order by j.start_time;
EOS
EOF_CREATE_F1

  cat $ONE_EXEC_F | ssh oracle@$HOST "/bin/sh -s $DB" >> $logf
  rm $ONE_EXEC_F
  exec >> $logf 2>&1

  rc=`sed '/^$/d' $logf | tail -1`
#  echo "rc="$rc >> $logf
  if [[ "$rc" =~ "COMPLETED" ]]; then
    BCK_STATUS=" completed with SUCCESS"
    SUCCESS_LIST=$DB" "$SUCCESS_LIST
  else
    BCK_STATUS=" completed with FAILURE"
    FAILURE_LIST=$DB" "$FAILURE_LIST
  fi
  HOST_DB_NAS_LVL=$HOST"/"$DB"/"$NAS"/"$LVL"  "$HOST_DB_NAS_LVL

  echo "" > $logf.mail.log
  sed -n '/Backups last/,$p' $logf  >> $logf.mail.log
  echo "" >> $logf.mail.log
  echo "Details:" >> $logf.mail.log
  echo "----------------------------------------------------------------------" >> $logf.mail.log
  egrep -i "input |oradata|LEVEL-|/oracle|error|REDUNDANT|RMAN-" $logf          >> $logf.mail.log
  echo "----------------------------------------------------------------------" >> $logf.mail.log

  echo "Backup Report for:" >> $LOGF_TOTAL
  echo "HOST: $HOST, DB: $DB, NAS: $NAS, LVL: $LVL" >> $LOGF_TOTAL
  cat $logf.mail.log  >> $LOGF_TOTAL

#  cat $logf.mail.log | $WMMAIL -s "$MPREFIX BACKUP on (HOST: $HOST, DB: $DB, NAS: $NAS, LVL: $LVL) $BCK_STATUS" $ADMINS  # 2>/dev/null
  rm ${logf}.mail.log

done  # for $HDS


exec >> $logf 2>&1
cat $LOGF_TOTAL | $WMMAIL -s "$MPREFIX BACKUP Report (HOST/DB/NAS/LVL: $HOST_DB_NAS_LVL) Success list (${SUCCESS_LIST}) / Failure list (${FAILURE_LIST})" $ADMINS  # 2>/dev/null

find $LOGDIR -name "bck_db_*.log" -mtime +31 -exec rm -f {} \;

