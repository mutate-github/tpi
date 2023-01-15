#!/bin/sh

HOST="k2"
DB="cft bd kika prov EPS creditc KIKOPDR"
#DB="creditc"
DB="cft bd kika prov EPS creditc KIKOPDR"

BASEDIR=`dirname $0`
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
me=$$
ONE_EXEC_F="one_exec_${me}.sh"
#echo "ONE_EXEC_F="$ONE_EXEC_F


for HST in `echo $HOST | xargs -n1 echo`; do

for D in `echo $DB | xargs -n1 echo`; do

echo "HST: "$HST"  DB: "$D
cat << EOF_CREATE_F1 > $ONE_EXEC_F
#!/bin/sh
sid=\$1
echo "sid="\$sid
$SET_ENV
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<EOF
set serveroutput on
column value for a80
set lines 250 pages 0 echo off termout off feedback off
spool exec_DBMS_BACKUP_RESTORE_DELETECONFIG.sql
SELECT 'EXEC DBMS_BACKUP_RESTORE.DELETECONFIG('||conf#||');' FROM v\\\$rman_configuration where name='RETENTION POLICY';
spool off
@exec_DBMS_BACKUP_RESTORE_DELETECONFIG.sql
VARIABLE RECNO NUMBER;
EXECUTE :RECNO := SYS.DBMS_BACKUP_RESTORE.SETCONFIG('RETENTION POLICY','TO REDUNDANCY 1');
set lines 200
column value for a80
SELECT * FROM v\\\$rman_configuration;
EOF
rm exec_DBMS_BACKUP_RESTORE_DELETECONFIG.sql

#rman  target / nocatalog <<EOR
#delete noprompt obsolete;
#EOR

#rman  target / nocatalog <<EOR2
#backup backupset completed before 'SYSDATE-1/2' format '/u15/\\\$ORACLE_SID/_move_from_nas20_%U' delete input;
#EOR2
EOF_CREATE_F1

cat ${ONE_EXEC_F} | ssh oracle@$HOST "/bin/sh -s $D"

rm $ONE_EXEC_F

done

done

