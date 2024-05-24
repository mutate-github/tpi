#!/bin/bash
set -f
# version 2

DTL=$(date '+%d-%m-%y-%H:%M:-%S')


logf="logfile_$ORACLE_SID_$DTL.txt"
exec &> >(tee -a "$logf")

[[ "$#" -eq 2 ]] && ( SRV="";  SID=$1; DT=$2)
[[ "$#" -eq 3 ]] && ( SRV=$1;  SID=$2; DT=$3)

case "$#" in
 2)  SRV="";  SID="$1"; DT="$2"; SRV=""; cmd='./tpi' ;;
 3)  SRV="$1"; SID="$2"; DT="$3"; cmd='' ;;
 *) echo -e  "Usage: 2 or 3 parameters, last parameter is days in past:"
    echo -e  "For local oracle DB:   ./audit_tpi.sh ORACLE_SID NUM_DAYS"
#    echo -e  "For remote oracle DB:  ./audit_tpi.sh my_server01 ORACLE_SID NUM_DAYS"
    exit 127
    ;;
esac

[ -z "$DT" ] && DT=$(date -d '1 days ago' +%d/%m/%y-00:00-240)
DT3=$(date -d '3 days ago' +%d/%m/%y-00:00-240)
echo "DT3: $DT3"

echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db nls
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db acl
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db option
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db properties
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db fusage
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID u % role DBA
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID size tbs
$cmd $SRV $SID size tbs free
$cmd $SRV $SID size df
$cmd $SRV $SID size sysaux
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID size
$cmd $SRV $SID arch
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID scheduler autotask
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID pipe
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p memory_target sga_target db_cache_size shared_pool_size pga_aggregate_target workarea_size_policy sort_area_size
$cmd $SRV $SID sga
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p FALSE %
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p audit
$cmd $SRV $SID s 'AUD$'
$cmd $SRV $SID audit
$cmd $SRV $SID audit login
$cmd $SRV $SID audit maxcon
$cmd $SRV $SID audit 1017
$cmd $SRV $SID job | egrep 'dba_jobs information|AUD|--------|FAILURES'
$cmd $SRV $SID scheduler | egrep "AUD|--------|JOB_NAME" | grep AUD -B 2
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p contorl_file
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID redo logs
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID fra
$cmd $SRV $SID p db_recovery_file_dest  db_flashback_retention_target
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID rman cfg
$cmd $SRV $SID rman 7
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID u % sys ALTER SYSTEM
$cmd $SRV $SID u % sys ALTER DATABASE
$cmd $SRV $SID u % sys ALTER DATABASE
$cmd $SRV $SID u % sys DROP ANY TRIGGER
$cmd $SRV $SID u % sys DROP ANY PROCEDURE
$cmd $SRV $SID u % sys DROP ANY TABLE
$cmd $SRV $SID u % sys ALTER ANY PROCEDURE
$cmd $SRV $SID u % sys DELETE ANY TABLE
$cmd $SRV $SID u % sys UPDATE ANY TABLE
$cmd $SRV $SID u % sys INSERT ANY TABLE
$cmd $SRV $SID u % sys CREATE USER
$cmd $SRV $SID u % sys BECOME USER
$cmd $SRV $SID u % sys ALTER USER
$cmd $SRV $SID u % sys DROP USER
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo -e  "$cmd $SRV $SID o invalid | sed  -e '/Elapsed/q'"
$cmd $SRV $SID o invalid | sed  -e '/Elapsed/q'
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID scheduler
$cmd $SRV $SID scheduler run % 48 | awk '/FAILED/{ f[$7"-"$1"."$2]++ } END { for (i in f)  printf "%-60s %-10s %-10s\n", i, " - FAILED: ",f[i]}' | sort
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID job
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo -e  $cmd $SRV $SID health
$cmd $SRV $SID health
echo -e  $cmd $SRV $SID health cr
$cmd $SRV $SID health cr
echo -e  $cmd $SRV $SID health hot
$cmd $SRV $SID health hot
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo -e "$cmd $SRV $SID sysstat user call"
$cmd $SRV $SID sysstat user call

echo -e "$cmd $SRV $SID sysstat user commit"
$cmd $SRV $SID sysstat user commit

echo -e "$cmd $SRV $SID sysstat user rollbacks"
$cmd $SRV $SID sysstat user rollbacks

echo -e "$cmd $SRV $SID sysstat redo size"
$cmd $SRV $SID sysstat redo size

echo -e "$cmd $SRV $SID sysstat redo write"
$cmd $SRV $SID sysstat redo write

$cmd $SRV $SID sysstat physical reads
$cmd $SRV $SID sysstat physical writes
$cmd $SRV $SID sysstat consistent gets
$cmd $SRV $SID sysstat db block gets
$cmd $SRV $SID sysstat rollback
echo -e  'Number of undo records applied to transaction tables that have been rolled back for consistent read purposes'
$cmd $SRV $SID sesstat transaction tables consistent reads - undo records applied
echo -e  'Number of undo records applied to user-requested rollback changes (not consistent-read rollbacks)'

echo -e "$cmd $SRV $SID sesstat rollback changes - undo records applied"
$cmd $SRV $SID sesstat rollback changes - undo records applied

echo -e "$cmd $SRV $SID sesstat number of auto extends on undo tablespace"
$cmd $SRV $SID sesstat number of auto extends on undo tablespace
$cmd $SRV $SID topseg
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID oratop h | ./diagram.sh  3 6 7  11 13 14 15 17 18 19 20 22 23 24
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID ash
$cmd $SRV $SID ash event
$cmd $SRV $SID ash mchart
$cmd $SRV $SID ash uchart | ./diagram.sh  2 3 6 7 8 9 10 13 16
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID dhash
$cmd $SRV $SID dhash event
echo -e "$cmd $SRV $SID dhash $DT3 mchart"
$cmd $SRV $SID dhash $DT3 mchart

echo -e "$cmd $SRV $SID dhash $DT3 uchart | ./diagram.sh  2 3 6 7 8 9 10 13 16"
$cmd $SRV $SID dhash $DT3 uchart | ./diagram.sh  2 3 6 7 8 9 10 13 16

echo -e "$cmd $SRV $SID dhash $DT3 awrinfo | ./diagram.sh"
$cmd $SRV $SID dhash $DT3 awrinfo | ./diagram.sh

echo -e "$cmd $SRV $SID dhash $DT3 iostat | ./diagram.sh"
$cmd $SRV $SID dhash $DT3 iostat | ./diagram.sh

echo -e "$cmd $SRV $SID dhash $DT3 segstat"
$cmd $SRV $SID dhash $DT3 segstat

echo -e "$cmd $SRV $SID oratop dhsh | ./diagram.sh 2 5 6 9 10 11 13 14 15 17 18 21 23 24"
$cmd $SRV $SID oratop dhsh | ./diagram.sh 2 5 6 9 10 11 13 14 15 17 18 21 23 24
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID dhash $DT3 sql
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo -e  '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'


