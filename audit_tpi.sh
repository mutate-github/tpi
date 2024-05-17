#!/bin/bash

DT=$(date '+%d-%m-%Y-%H:%M:%S')

logf="logfile_$ORACLE_SID_$DT.txt"
exec &> >(tee -a "$logf")


case "$#" in
 2) echo "usage: ./audit_tpi.sh ORACLE_SID DAYS"; cmd='./tpi' ;;
 3) echo "usage: ./audit_tpi.sh SERVERNAME ORACLE_SID DAYS"; cmd='$cmd' ;;
 *) echo -n "usage: 2 or 3 parameters, last parameter is days in past: 
    For local oracle DB:   ./audit_tpi.sh ORACLE_SID NUM_DAYS
    For remote oracle DB:  ./audit_tpi.sh my_server01 ORACLE_SID NUM_DAYS"; 
    exit 128 ;;
esac


SRV=$1
SID=$2
DT=$3

[ -z "$DT" ] && DT=$(date -d '1 days ago' +%d/%m/%y-00:00-240)
DT3=$(date -d '3 days ago' +%d/%m/%y-00:00-240)

echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db nls
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db acl
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db option
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db properties
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID db fusage
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID u % role DBA
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID size tbs
$cmd $SRV $SID size tbs free
$cmd $SRV $SID size df
$cmd $SRV $SID size sysaux
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID size
$cmd $SRV $SID arch
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID scheduler autotask
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID pipe
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p memory_target sga_target db_cache_size shared_pool_size pga_aggregate_target workarea_size_policy sort_area_size
$cmd $SRV $SID sga
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p FALSE %
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p audit
$cmd $SRV $SID s 'AUD$'
$cmd $SRV $SID audit
$cmd $SRV $SID audit login
$cmd $SRV $SID audit maxcon
$cmd $SRV $SID audit 1017
$cmd $SRV $SID job | egrep 'dba_jobs information|AUD|--------|FAILURES'
$cmd $SRV $SID scheduler | egrep "AUD|--------|JOB_NAME" | grep AUD -B 2
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID p contorl_file
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID redo logs
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID fra
$cmd $SRV $SID p db_recovery_file_dest  db_flashback_retention_target
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID rman cfg
$cmd $SRV $SID rman 7
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
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
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo "$cmd $SRV $SID o invalid | sed  -e '/Elapsed/q'"
$cmd $SRV $SID o invalid | sed  -e '/Elapsed/q'
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID scheduler
$cmd $SRV $SID scheduler run % 48 | awk '/FAILED/{ f[$7"-"$1"."$2]++ } END { for (i in f)  printf "%-60s %-10s %-10s\n", i, " - FAILED: ",f[i]}' | sort
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID job
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo $cmd $SRV $SID health
$cmd $SRV $SID health
echo $cmd $SRV $SID health cr
$cmd $SRV $SID health cr
echo $cmd $SRV $SID health hot
$cmd $SRV $SID health hot
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID sysstat user call
$cmd $SRV $SID sysstat user commit
$cmd $SRV $SID sysstat user rollbacks
$cmd $SRV $SID sysstat redo size
$cmd $SRV $SID sysstat redo write
$cmd $SRV $SID sysstat physical reads
$cmd $SRV $SID sysstat physical writes
$cmd $SRV $SID sysstat consistent gets
$cmd $SRV $SID sysstat db block gets
$cmd $SRV $SID sysstat rollback
echo "--Number of undo records applied to transaction tables that have been rolled back for consistent read purposes"
$cmd $SRV $SID sesstat transaction tables consistent reads - undo records applied
echo "--Number of undo records applied to user-requested rollback changes (not consistent-read rollbacks)"
$cmd $SRV $SID sesstat rollback changes - undo records applied
$cmd $SRV $SID sesstat number of auto extends on undo tablespace
$cmd $SRV $SID topseg
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo "$cmd $SRV $SID oratop h | diagram.sh  3 6 7  11 13 14 15 17 18 19 20 22 23 24"
$cmd $SRV $SID oratop h | diagram.sh  3 6 7  11 13 14 15 17 18 19 20 22 23 24
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID ash 
$cmd $SRV $SID ash event
$cmd $SRV $SID ash mchart
echo "$cmd $SRV $SID ash uchart | diagram.sh  2 3 6 7 8 9 10 13 16"
$cmd $SRV $SID ash uchart | diagram.sh  2 3 6 7 8 9 10 13 16
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID dhash 
$cmd $SRV $SID dhash event
$cmd $SRV $SID dhash $DT mchart
echo "$cmd $SRV $SID dhash $DT uchart | diagram.sh  2 3 6 7 8 9 10 13 16"
$cmd $SRV $SID dhash $DT uchart | diagram.sh  2 3 6 7 8 9 10 13 16
echo "$cmd $SRV $SID dhash $DT3 awrinfo"
$cmd $SRV $SID dhash $DT3 awrinfo | diagram.sh 
echo "$cmd $SRV $SID dhash $DT3 iostat"
$cmd $SRV $SID dhash $DT3 iostat | diagram.sh
echo "$cmd $SRV $SID dhash $DT segstat"
$cmd $SRV $SID dhash $DT segstat 
echo "$cmd $SRV $SID oratop dhsh | diagram.sh 2 5 6 9 10 11 13 14 15 17 18 21 23 24"
$cmd $SRV $SID oratop dhsh | diagram.sh 2 5 6 9 10 11 13 14 15 17 18 21 23 24
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
$cmd $SRV $SID dhash $DT sql
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'
echo '--------------------------------------------------------------------------------------------------------------------------------------------------------------------'

