#!/bin/sh

HOST=$1
DB=$2

BASEDIR=`dirname $0`
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`
me=$$
ONE_EXEC_F="one_exec_${me}.sh"
#echo "ONE_EXEC_F="$ONE_EXEC_F

cat << EOF_CREATE_F1 > $ONE_EXEC_F
#!/bin/sh
sid=\$1
echo "sid="\$sid
$SET_ENV
export ORACLE_SID=\$sid
sqlplus -S '/as sysdba' <<EOF
select * from dual;
EOF
EOF_CREATE_F1

cat ${ONE_EXEC_F} | ssh oracle@$HOST "/bin/sh -s $DB"

rm $ONE_EXEC_F

