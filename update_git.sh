#!/bin/sh

#mkdir -p ~/tal/scripts/
#cp tpi scripts/
#cd scripts
for f in `ls`; do
  echo "> " $f
  git add $f
done

DT=`date`
git commit -m "$DT"
#git push
git push -f origin main

