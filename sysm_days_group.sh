#!/bin/bash

# average sysmetric statistics by Hours
# Usage: ./sysm_days_group.sh file_name | diagram.sh

# FF='/home/t.mukhametshin/start/log/dcb-retail-db_GOLD506_sysmetric_h.log'
FF="$1"
HH="00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23"
#DD="01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31"
DD="30 31"

echo "BEGIN_TIME HCPUB CPUUPS LOAD"
while read D; do 
  while read H; do 
    #30/09/24-10:20:38
    #BEGIN_TIME        NCPU HCPUB CPUUPS LOAD 
    tail -30000 $FF |  egrep "^$D/[0-9][0-9]/[0-9][0-9]-$H:" |  awk '{s1=substr($1,1,11);s3+=$3;s4+=$4;s5+=$5} END { if (NR>0) print s1":00:00", s3/NR, s4/NR, s5/NR }'
  done <<< $(echo $HH | xargs -n1 echo)
done <<< $(echo $DD | xargs -n1 echo)

exit

# for days 30-31/10/24
# cat  ~/start/log/aisprod_aisutf_sysmetric_h.log  | sed -n -e "/BEGIN_TIME/ { h; }; /^3[01]\/10\/24-/  { x; p; x; p; }" | sort | uniq | diagram.sh 3 11 15 17 19 20 22 23 24

