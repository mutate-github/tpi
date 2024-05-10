#!/bin/bash

lst="$*"

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
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=$(cat $SET_ENV_F)
SCRIPT_NAME="$BASEDIR/exec_one_all_db_$$.sh"


for srv in $lst; do
#  echo $svr
  $WRTPI $srv | awk -F" ora_pmon_" '/ ora_pmon_/{print $2}' |  while read sid; do
      echo "SERVER: "$srv ", DB: "$sid
#       $WRTPI $srv $sid db nls | grep NLS_CHARACTERSET
#       $WRTPI $srv $sid exec 'alter system set "_enable_space_preallocation"=0'

SQL_NAME="exec_resize_df_${srv}_${sid}_$$.sql"
#$WRTPI $srv $sid size df lastseg | grep '^alter database datafile' > $SQL_NAME

cat << 'EOL' > $SQL_NAME
set lines 230
--column name for a30
--column value for a90
--select name, value from v\$diag_info;
set lines 230 echo on
column global_tran_id format a35
column tran_comment   format a20
col database for a20
col host for a20
col OS_TERMINAL for a20
col OS_user for a15
col db_user for a15
col top_db_user for a15
col branch for a15
col HOST for a30
col FAIL_TIME for a18
SELECT LOCAL_TRAN_ID,GLOBAL_TRAN_ID,STATE,cast(FAIL_TIME as date) FAIL_TIME,HOST,db_user,COMMIT# FROM dba_2pc_pending ;
EOL


cat <<EOFF >  $SCRIPT_NAME
#!/bin/bash
set -f
sid=\$1
$SET_ENV
export ORACLE_SID=$sid
sqlplus -s '/ as sysdba' <<EOS
EOFF
cat $SQL_NAME >> $SCRIPT_NAME
cat <<EOFF2 >>  $SCRIPT_NAME
EOS
EOFF2
rm $SQL_NAME

#      echo "ps -ef | grep [o]ra_pmon" | ssh $srv "/bin/bash -s "
       cat $SCRIPT_NAME | ssh $srv "/bin/bash -s $sid"
#        $WRTPI $srv $sid scheduler PURGE_ORPHAN_AWR_SNAPS
#       $WRTPI $srv $sid ash tchart
#       cat $BASEDIR/purge_traces.sh | ssh oracle@$srv "/bin/bash -s $sid"
      echo "================================================================================="
  done
done

rm $SCRIPT_NAME

