#!/bin/bash

#scp tpi 172.16.249.1:~/tal/
#scp rtpi 172.16.249.1:~/tal/
tpi | sed -n '/Usage:/,$p' > README.md

if [ "$1" = "tpi" ]; then
#askona
echo "askona"
scp tpi 192.168.1.53:tal/
scp tpi 192.168.1.178:tal/

#dixy
echo "dixy"
scp tpi 10.0.7.21:tal/
scp tpi 10.0.17.21:tal/

#as
# echo "as p260unc2"
# scp tpi p260unc2:tal/
fi

git add README.md
git add $*
DT=`date`
git commit -m "$DT"
git push
#git push -f origin main

