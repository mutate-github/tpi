#!/bin/sh
set -f
#exec 5> debug_output.txt
#BASH_XTRACEFD="5"
#PS4='$LINENO: '
#set -x

export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251

WRTPI=`which rtpi`
BASEDIR=`dirname $0`
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL=`which $MAILS`
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
LINES=`$BASEDIR/iniget.sh mon.ini alert lines`
EXCLUDE=`$BASEDIR/iniget.sh mon.ini alert exclude`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in `echo "$DBS" | xargs -n1 echo`; do
    LOGF=$BASEDIR/log/mon_alert_${HOST}_${DB}.log
    LOGF_HEAD=$BASEDIR/log/mon_alert_${HOST}_${DB}_head.log
    LASTALERTTIME=$BASEDIR/log/mon_alert_${HOST}_${DB}_lastalerttime.tmp
    EXCLFILE=$BASEDIR/log/mon_alert_${HOST}_${DB}_exclude.tmp
    echo $EXCLUDE > $EXCLFILE
    AWKFILE=$BASEDIR/log/mon_alert_${HOST}_${DB}_awkfile.awk

    echo "START HOST="$HOST "DB="$DB "at: "`date`
    $WRTPI $HOST $DB alert $LINES > $LOGF
    sed -i '1d' $LOGF
    head -1 $LOGF > $LOGF_HEAD
    sed -i '1d' $LOGF

cat > $AWKFILE <<!EOF
BEGIN {
  # first get excluded error list
  excldata="";
  while (getline < "$EXCLFILE" > 0) { excldata=excldata " " \$0; }
  # print excldata
  # get time of last error
  if (getline < "$LASTALERTTIME" < 1)  
     { olddate = "00000000 00:00:00" }
  else  { olddate=\$0 }
  errct = 0; errfound = 0;
}

{ if ( \$0 ~ /Sun/ || /Mon/ || /Tue/ || /Wed/ || /Thu/ || /Fri/ || /Sat/ )
  { if (dtconv(\$3, \$2, \$5, \$4) <= olddate)
    { next; }  # get next record from file
    # here we are now processing errors
    OLDLINE=\$0; # store date, possibly of error, or else to be discarded
    # SAVE to olddate: current values:  dtconv(\$3, \$2, \$5, \$4);
    olddate = dtconv(\$3, \$2, \$5, \$4);

    while (getline > 0)
      { if (\$0 ~ /Sun/ || /Mon/ || /Tue/ || /Wed/ || /Thu/ || /Fri/ || /Sat/ )
        { if (errfound > 0)
          { printf ("%s<BR>",OLDLINE); }
          OLDLINE = \$0; # no error, clear and start again
          errfound = 0;
          # save the date for next run
          olddate = dtconv(\$3, \$2, \$5, \$4);
          continue;
        }
        OLDLINE = sprintf("%s<BR>%s",OLDLINE,\$0);
        if ( \$0 ~ /ORA-/ || /[Ff]uzzy/ )
          { # extract the error
            errloc=index(\$0,"ORA-")
            if (errloc > 0)
              { oraerr=substr(\$0,errloc);
                if (index(oraerr,":") < 1)
                   { oraloc2=index(oraerr," ") }
                else
                   { oraloc2=index(oraerr,":") }
                oraloc2=oraloc2-1;
                oraerr=substr(oraerr,1,oraloc2);
                if (index(excldata,oraerr) < 1)
                   { errfound = errfound +1; }
              }
            else # treat fuzzy as errors
              { errfound = errfound +1; }
          }      
      }
   }
}

END {
      if (errfound > 0)
         { printf ("%s<BR>",OLDLINE); }
      print olddate > "$LASTALERTTIME";
}

function dtconv (dd, mon, yyyy, tim, sortdate) {
  mth=index("JanFebMarAprMayJunJulAugSepOctNovDec",mon);
  if (mth < 1)
    { return "00000000 00:00:00" };
  # now get month number - make to complete multiple of three and divide
  mth=(mth+2)/3;
  sortdate=sprintf("%04d%02d%02d %s",yyyy,mth,dd,tim);
  return sortdate;
}
!EOF

ERRMESS=$(awk -f $AWKFILE $LOGF)
ERRCT=$(echo $ERRMESS | awk 'BEGIN {RS="<BR>"} END {print NR}')
# rm $LASTALERTTIME
if [ "$ERRCT" -gt 1 ]; then
 echo "$ERRCT Errors Found \n"
 echo "$ERRMESS" | awk 'BEGIN {FS="<BR>"}{for (i=1;NF>=i;i++) {print $i}}'
 echo " "\\n"$ERRMESS" | awk 'BEGIN {FS="<BR>"}{for (i=1;NF>=i;i++) {print $i}}' >> $LOGF_HEAD
 cat $LOGF_HEAD | $WMMAIL -s "$MPREFIX ALERT_LOG warning: $HOST / $DB" $ADMINS
fi

rm $LOGF $LOGF_HEAD $EXCLFILE $AWKFILE
# rm $LASTALERTTIME

  done    # DB
done   # HOST

