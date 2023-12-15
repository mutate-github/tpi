#!/bin/sh

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 server database script.sql param1 param2 param3 ..."
  exit
fi 

SRV="$1"
SID="$2"
SCRIPT="$3"
shift
shift
shift
PARAM="$@"
PARAM=$(echo $PARAM | sed -e "s/'/\\\'/g")

BASEDIR=`dirname $0`
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=`cat $SET_ENV_F`

echo "SRV: $SRV     SID: $SID    SCRIPT: $SCRIPT     PARAM: $PARAM"

cat <<EOFF > execsql_one_$$.sh
#!/bin/sh
sid=\$1
$SET_ENV
export ORACLE_SID=\$sid
rm execsql_one_[0-9]*sql
cat <<'EOS' > execsql_one_$$.sql
EOFF

cat $SCRIPT >> execsql_one_$$.sh

cat <<EOFF2 >> execsql_one_$$.sh
EOS

sqlplus '/as sysdba' @execsql_one_$$.sql $PARAM <<EOS
exit
EOS
rm execsql_one_[0-9]*.sql
EOFF2

cat execsql_one_$$.sh  | ssh $SRV "/bin/sh -s $SID"

# rm execsql_one_$$.sh

