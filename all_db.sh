#!/bin/bash

lst="$*"
script=exec_all_db_$$.sh

if [ "$#" -eq 0 ]; then
  echo "This script execute some commands or sql\script on remote server for all databases" 
  echo "Usage: $0 [server]"
fi

if [ -z $lst ]; then
  :
 lst='z14-0473-novre z14-0511-ol z14-0515-ol z14-0518-rman z14-0533-ol z14-0633-qat z14-0681-phnxdb z14-0682-raksdb z14-0815-ora z14-0816-rasmdb z14-0974-todb z14-0977-tfdb z14-1014-tora z14-1847 z14-1901 z14-2043-phnxdb brnsk-oracle-phenix kem-ora01 abkh-oracle-phenix z14-1014-tora-test'
# lst='p260unc2 p260unc4'
# lst='askona01 askona04 askona05 db-gold-dca dcb-retail-db db-gold-dev dca-label-db dcb-label-db dca-stock-db dcb-stock-db dcb-t-alcdsk-db degcdb1 degcdb2 degcdbt gold2 ikb-db1-stby ikb-db2-stby mdstock1 mdstock2 mdstockt mrct-dev-db mrct-prd-db mrct-uat-db srv-axdb1-mrg srv-axdb2-mrg srv-deosdb-dca srv-deosdb-dcb srv-gold-db-dcc srv-olapwhs01-dca srv-olapwhs01-dcb srv-vetdb-dca srv-vetdb-dcb t-retail-db t-stock-db'
fi

BASEDIR=`dirname $0`
LOGDIR="$BASEDIR/../log"
if [ ! -d "$LOGDIR" ]; then mkdir -p "$LOGDIR"; fi
WRTPI="$BASEDIR/rtpi"

cat > $script<<'EOF'
#!/bin/bash
sid=$1
# echo "in script:" $sid
# env | grep ORA
case "$sid" in
cft*|kik*|bd*|prov*)        . ~/db12kik.env ;;
EPS*|creditc)               . ~/db12.env ;;
KIKOPDR)                    . ~/db11.env ;;
jet|ja)                     . /etc/profile.ora ;;
aisutf*|unit*)              . ~/.ora_env ;;
askona*|aixtdb*|sbaskona)   . ~/.profile ;;
egais*|GOLD506*)            . ~/.bashrc ;;
unc*)                       . ~/${sid}_setenv.sh ;;
goldwhs)                    . ~/.bash_profile ;;
# opndb)                      . ~/BRSKDB_setenv.sh ; login_str="tal/tal@'(DESCRIPTION=(ADDRESS=(COMMUNITY=TCP.WORLD)(PROTOCOL=TCP)(HOST=172.16.104.36)(PORT=1525))(CONNECT_DATA=(SERVICE_NAME=opndb)))'" ;;
opndb|obk)                  : ;;
*) #        if [ -f ~/.bashrc ]; then . ~/.bashrc ; fi
   #        if [ -f ~/.bash_profile ]; then . ~/.bash_profile ; fi
   #        if [ -f ~/.profile ]; then . ~/.profile ; fi
   case `uname | awk -F_ '{print $1}'` in
      Linux)  if [ -f ~/.bash_profile ]; then . ~/.bash_profile ; fi
              rc=`find . -maxdepth 1 -name "${sid}_setenv.sh" -print -quit`
              if [ -n "$rc" ]; then . ~/${sid}_setenv.sh ; fi
	      ;;
      AIX)    if [ -f ~/.profile ]; then . ~/.profile ; fi
              if [ -f ~/.bashrc ]; then . ~/.bashrc ; fi
              ;;
      *) : ;;
   esac
;;
esac  > /dev/null 2>&1
export ORACLE_SID=$sid

sqlplus -s '/as sysdba' <<EOS0
set echo on termout on heading on feedback off trimspool on verify off
set lines 230 pages 90
--select distinct owner,table_name,STATTYPE_LOCKED from dba_tab_statistics where stattype_locked is not null and owner not in ('SYSTEM','SYS','SYSMAN','WMSYS');
--select owner,table_name from dba_tables where table_name='V_MP' and owner='MEX';
--select sql_id from v\$active_session_history where sql_id='63rfwrgd178v5';
EXEC DBMS_SCHEDULER.drop_job('PURGE_ORPHAN_AWR_SNAPS');
/*
BEGIN
  DBMS_SCHEDULER.create_job (
    job_name        => 'PURGE_ORPHAN_AWR_SNAPS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'begin
execute immediate ''alter session set "_swrf_test_action" = 72'';
 for c in (select dhash.minsnap, snap_det.maxsnap, snap_det.dbid from ( select dbid, min(snap_id) minsnap from dba_hist_active_sess_history group by dbid)  dhash,( select dbid, min(snap_id) maxsnap from sys.WRM\$_SNAPSHOT_DETAILS group by dbid)  snap_det where dhash.dbid=snap_det.dbid) loop
  DBMS_WORKLOAD_REPOSITORY.DROP_SNAPSHOT_RANGE(low_snap_id => c.minsnap, high_snap_id => c.maxsnap, dbid => c.dbid);
 end loop;
end;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'freq=daily; byhour=3; byminute=30; bysecond=0;',
    end_date        => NULL,
    enabled         => TRUE,
    comments        => 'DBS/Tal: Purge Orphan Rows in AWR DocID 2536631.1');
END;
/
*/
exit
EOS0
EOF


for srv in $lst; do
#  echo $svr
  $WRTPI $srv | awk -F" ora_pmon_" '/ ora_pmon_/{print $2}' |  while read sid; do
      echo "SERVER: "$srv ", DB: "$sid
       $WRTPI $srv $sid db nls | grep NLS_CHARACTERSET
       $WRTPI $srv $sid exec 'select \* FROM V$TIMEZONE_FILE'
#      echo "ps -ef | grep [o]ra_pmon" | ssh $srv "/bin/bash -s "
#       cat $script | ssh $srv "/bin/bash -s $sid"
#        $WRTPI $srv $sid scheduler PURGE_ORPHAN_AWR_SNAPS
#       $WRTPI $srv $sid ash tchart
#       cat $BASEDIR/purge_traces.sh | ssh oracle@$srv "/bin/bash -s $sid"
      echo "================================================================================="
  done
done

rm $script

