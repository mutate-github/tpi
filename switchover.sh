#!/bin/sh
set -f

echo "Usage: $0 primary_host standby_host ORACLE_SID"
if [ $# != 3 ]; then
  exit 1
fi

primary_host=$1
standby_host=$2
ORACLE_SID=$3

BASEDIR=`dirname $0`
SET_ENV_F="$BASEDIR/set_env"
set_env=`cat $SET_ENV_F`

export DEBUG=1
me=$$
one_exec_f="one_exec_switchover_${me}.sh"

#sid=$3
#set_env="case \"\$sid\" in
#kik*|bd*|cft*|prov)       . ~/db12kik.env ;;
#EPS*|creditc)             . ~/db12.env ;;
#KIKOPDR)                  . ~/db11.env ;;
#jet|ja)                   . /etc/profile.ora ;;
#aisutf*|unit*)            . ~/.ora_env ;;
#askona|aixtdb|sbaskona)   . ~/.profile ;;
#GOLD506*|egais*)          . ~/.bashrc ;;
#goldwhs)                  . ~/.bash_profile ;;
#*) #        if [ -f ~/.bashrc ]; then . ~/.bashrc ; fi
#   #        if [ -f ~/.bash_profile ]; then . ~/.bash_profile ; fi
##           if [ -f ~/.profile ]; then . ~/.profile ; fi
#   case `uname | awk -F_ '{print $1}'` in
#      Linux)  if [ -f ~/.bash_profile ]; then . ~/.bash_profile ; fi ;;
#      AIX)    if [ -f ~/.profile ]; then . ~/.profile ; fi
#              if [ -f ~/.bashrc ]; then . ~/.bashrc ; fi
#              ;;
#      *) ;;
#   esac
#;;
#esac"

next_step()
{
step=$*
while [ 1 ]; do
  echo -n "Proceed with the step: $step (y/n/q)?"
  if [ "$DEBUG" = "1" ]; then
    read ans
  else
    echo y
    ans="y"
  fi
  case "$ans" in
   y) return 0 ;;
   n) return 1 ;;
   q) rm one_exec_switchover_*.sh ; exit ;;
   *) : ;;
  esac
done
}

echo "\nSTEP 0: Switch logfile DB: $ORACLE_SID  on host: $primary_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
env | grep ORA
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
alter system switch logfile;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$primary_host "/bin/sh -s $ORACLE_SID"
)


echo "\nSTEP 1: Show arch lag for DB: $ORACLE_SID on $primary_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set linesize 230 pages 70
col THREAD format 999
col PRIMARY_SEQ format 9999999999
col STANDBY_THREAD format 999
col STANDBY_SEQ format 9999999999
col PRIMARY_TIME format a20
col STANDBY_COMPLETION_TIME format a23
col SEQ_GAP format 9999999
col LAG_MINUTES format 9999999.99
SELECT   prim.thread# thread, prim.seq primary_seq, TO_CHAR (prim.tm, 'DD/MM/YYYY HH24:MI:SS') primary_time, tgt.thread# standby_thread, tgt.seq standby_seq,
         TO_CHAR (tgt.tm, 'DD/MM/YYYY HH24:MI:SS') standby_completion_time, prim.seq - tgt.seq seq_gap, (prim.tm - tgt.tm) * 24 * 60 lag_minutes
  FROM   (SELECT thread#, MAX(sequence#) seq, MAX(completion_time) tm FROM v\$archived_log where RESETLOGS_CHANGE#=(select RESETLOGS_CHANGE# from v\$database) GROUP BY thread#) prim,
         (SELECT thread#, MAX(sequence#) seq, MAX(completion_time) tm FROM v\$archived_log where RESETLOGS_CHANGE#=(select RESETLOGS_CHANGE# from v\$database)
                                                             and dest_id IN (SELECT dest_id FROM v\$archive_dest WHERE target = 'STANDBY') AND applied = 'YES' GROUP BY thread#) tgt
 WHERE   prim.thread# = tgt.thread#;
--ttitle left "GV\$MANAGED_STANDBY :"
--select thread#,sequence#,process,status from gv\$managed_standby order by THREAD#, SEQUENCE#, PROCESS;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$primary_host "/bin/sh -s $ORACLE_SID"
)


echo "\nSTEP 2: Show standby redo log for DB: $ORACLE_SID on host: $standby_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set linesize 230 pages 70
set lines 230
set echo off feed off veri off tab off pages 50
column member for a80
select group#, member, type, status from v\$logfile where type='STANDBY' order by group#,member;
--select group#, member, type, status from v\$logfile  order by group#,member;
--column bytes for 99,999,999,999
--select group#, bytes, status, archived, SEQUENCE# from v\$log;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$standby_host "/bin/sh -s $ORACLE_SID"
)



echo "\nSTEP 3: Restart DB: $ORACLE_SID in restrict mode on host: $primary_host"
next_step && ( 
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
startup restrict force
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$primary_host "/bin/sh -s $ORACLE_SID" 
) 


echo "\nSTEP 4: Show switchover_status DB: $ORACLE_SID  on host: $primary_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
select name, open_mode, database_role,switchover_status from v\$database;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$primary_host "/bin/sh -s $ORACLE_SID"
)



echo "\nSTEP 5: Switchover DB: $ORACLE_SID to standby on host: $primary_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
alter database commit to switchover to standby;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$primary_host "/bin/sh -s $ORACLE_SID"
)



echo "\nSTEP 6: Show alert_log on standby host: $standby_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
VALUE=\`sqlplus -S '/as sysdba' <<'EOS'
set lines 220
set echo off feed off veri off tab off termout off pages 0
col value new_value value
col db_name new_value db_name noprint
select INSTANCE_NAME db_name from v\$instance;
select value||'/alert_&&db_name..log' from V\$DIAG_INFO where name='Diag Trace';
EOS\`
tail -20 \$VALUE
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$standby_host "/bin/sh -s $ORACLE_SID"
)


echo "\nSTEP 7: Show switchover_status for DB: $ORACLE_SID  on standby host: $standby_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
select name, open_mode, database_role,switchover_status from v\$database;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$standby_host "/bin/sh -s $ORACLE_SID"
)



echo "\nSTEP 8: Switchover $ORACLE_SID to primary on standby host: $standby_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
alter database commit to switchover to primary with session shutdown;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$standby_host "/bin/sh -s $ORACLE_SID"
)


echo "\nSTEP 9: Show alert_log on standby host: $standby_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
VALUE=\`sqlplus -S '/as sysdba' <<'EOS'
set lines 220
set echo off feed off veri off tab off termout off pages 0
col value new_value value
col db_name new_value db_name noprint
select INSTANCE_NAME db_name from v\$instance;
select value||'/alert_&&db_name..log' from V\$DIAG_INFO where name='Diag Trace';
EOS\`
tail -20 \$VALUE
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$standby_host "/bin/sh -s $ORACLE_SID"
)


echo "\nSTEP 10: Open database: $ORACLE_SID on old standby host: $standby_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
alter database open;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$standby_host "/bin/sh -s $ORACLE_SID"
)


echo "\nSTEP 11: Startup and enable manage recovery new standby database: $ORACLE_SID on host: $primary_host"
next_step && (
cat << EOF_CREATE_SCP > ${one_exec_f}
#!/bin/sh
sid=\$1
$set_env
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<'EOS'
set lines 250 pages 50
startup
recover managed standby database disconnect using current logfile;
EOS
EOF_CREATE_SCP
cat ${one_exec_f} | ssh oracle@$primary_host "/bin/sh -s $ORACLE_SID"
)

rm one_exec_switchover_*.sh
