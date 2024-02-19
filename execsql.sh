#!/bin/bash

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 server database script.sql param1 param2 param3 ..."
  echo "Usage: $0 server database dhashtop.sql dhashtop.sql username,sql_id session_type=\'FOREGROUND\' to_date\(\'27/12/23-09:40\',\'dd/mm/yy-hh24:mi\'\) to_date\(\'27/12/23-10:02\',\'dd/mm/yy-hh24:mi\'\)"
  exit
fi 

SRV="$1"
SID="$2"
SCRIPT="$3"
shift
shift
shift
PARAM="$@"
PARAM=$(echo $PARAM | sed -e "s/'/\\\'/g" -e 's|(|\\(|g' -e 's|)|\\)|g' )

BASEDIR=$(dirname $0)
SET_ENV_F="$BASEDIR/set_env"
SET_ENV=$(<$SET_ENV_F)

echo "SRV: $SRV     SID: $SID    SCRIPT: $SCRIPT     PARAM: $PARAM"

cat <<EOFF > execsql_one_$$.sh
#!/bin/bash
sid=\$1
$SET_ENV
export ORACLE_SID=\$sid
rm execsql_one_[0-9]*sql
cat <<'EOS' > execsql_one_$$.sql
EOFF

cat $SCRIPT >> execsql_one_$$.sh

cat <<EOFF2 >> execsql_one_$$.sh
EOS

sqlplus -s '/ as sysdba' @execsql_one_$$.sql $PARAM <<EOS
exit
EOS
rm execsql_one_[0-9]*.sql
EOFF2

cat execsql_one_$$.sh  | ssh $SRV "/bin/bash -s $SID"

# rm execsql_one_$$.sh

