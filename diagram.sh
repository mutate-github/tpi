#!/bin/bash
set -f

echo "usage: ./diagramm.sh sysmetric_h.log 25/11/23-0[89]  3 11 15 17 19 20 22 23 24"
echo "usage: tpi ... oratop h | diagramm.sh  3 11 15 17 19 20 22 23 24"
echo "          1           2     3      4    5    6    7      8      9    10    11    12    13    14    15    16     17       18       19     20      21     22         23      24      25     26     27"
echo " BEGIN_TIME        NCPU HCPUB CPUUPS LOAD DCTR DWTR   SPFR   TPGA   SCT   AAS   AST ASCPU  ASIO  ASWA  ASPQ   UTPS     UCPS     SSRT   MBPS    IOPS   IORL       LOGR    PHYR    PHYW   TEMP   DBTM"
echo ""

case "$#" in
0|2) all_par="3 11 15 17 19 20 22 23 24" 
   ;;
*) all_par="$@"
   ;;
esac

if [ -p /dev/stdin ]; then
  file="/tmp/$$_tmp.tmp"
  stdin=$(cat)
  echo "$stdin" > $file
  date="^[0-9][0-9]\/.*"
else
  file="$1"
  date="$2"
  shift
  shift
  if [[ "$#" -ne 0 ]]; then  all_par="$@"; fi
  # col1="$3"
  # col2="$4"
fi

col1="1"
limit=30
histo="|======================================================================+"
scale=$(awk "BEGIN{print $limit/100}")

tail -100 "${file}" | grep "BEGIN_TIME" | uniq > ${file}.tmp
egrep "${date}" "${file}" | sort -n | uniq >> ${file}.tmp
rm /tmp/$$_tmp.tmp 2>/dev/null
file=${file}.tmp

get_cols()
{
col2="$1"
max=`awk '/^[0-9].*/{if ($'${col2}'>x) x=$'${col2}'};END{print x}' $file`
if [[ -z "$max" || "$max" -eq 0 ]]; then max=1; fi

cat $file | awk '!/---/{print $'$col1'" "$'$col2'}' | xargs -n2 echo | while read datewd value ; do
   printf "%-20s" $datewd
   printf "%-10s" $value
   if [[ "$datewd" = "BEGIN_TIME" ]]; then
      printf "%-${limit}s" LEVELS
   fi
   value=`awk "BEGIN{printf \"%3d\", ($value / ($max / 100)) * $scale}"`
   if [[ "$value" -lt 1 && "$datewd" != "BEGIN_TIME" ]]; then value=1; fi
#   echo $value " " $result
   printf ${histo:0:$value}"\n"
done
}

awk '{print $1}' ${file} > /tmp/0.tmp

for i in $(echo "$all_par" | xargs -n1 echo); do
  get_cols $i | awk '{printf $2" "$3"\n"}' > /tmp/${i}.tmp
  j=$j" "/tmp/${i}.tmp
done

paste /tmp/0.tmp $j | column -t

rm $file /tmp/0.tmp $j

