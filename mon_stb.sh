#!/bin/sh

WRTPI=`which rtpi`
BASEDIR=`dirname $0`
MAILS=`$BASEDIR/iniget.sh mon.ini mail script`
WMMAIL=`which $MAILS`
MPREFIX=`$BASEDIR/iniget.sh mon.ini mail prefix`
HOSTS=`$BASEDIR/iniget.sh mon.ini servers host`
ADMINS=`$BASEDIR/iniget.sh mon.ini admins email`
SEQ_GAP=`$BASEDIR/iniget.sh mon.ini standby seq_gap`
LAG_MINUTES=`$BASEDIR/iniget.sh mon.ini standby lag_minutes`
REPEAT_MINUTES=`$BASEDIR/iniget.sh mon.ini standby repeat_minutes`
REPEAT_AT=`$BASEDIR/iniget.sh mon.ini standby repeat_at`

for HOST in `echo "$HOSTS" | xargs -n1 echo`; do
  echo "HOST="$HOST
  DBS=`$BASEDIR/iniget.sh mon.ini $HOST db`
  for DB in  `echo "$DBS" | xargs -n1 echo`; do
    echo "DB="$DB
    LOG_FILE=$BASEDIR/log/mon_stb_${HOST}_${DB}_${DEST_ID}_$$.log
    $WRTPI $HOST $DB arch | awk '/LAG_MINUTES/,/Elapsed/' | egrep -v "Elapsed" > $LOG_FILE
    awk '!/LAG_MINUTES|--------/{print $2" "$(NF-1)" "$NF}' $LOG_FILE | while read DEST_ID SEQ_GAP_NOW LAG_MINUTES_NOW; do
      TRG_FILE_SEQ_GAP=$BASEDIR/log/mon_stb_${HOST}_${DB}_${DEST_ID}_trgfile_seq_gap.log
      TRG_FILE_LAG_MINUTES=$BASEDIR/log/mon_stb_${HOST}_${DB}_${DEST_ID}_trgfile_lag_minutes.log

      echo "GAP: " $SEQ_GAP_NOW"  LAG: " $LAG_MINUTES_NOW
      LAG_MINUTES_NOW=`echo "$LAG_MINUTES_NOW/1" | bc`
      if [ -s $TRG_FILE_SEQ_GAP ]; then
        if [ "$SEQ_GAP_NOW" -lt "$SEQ_GAP" ]; then
          SEQ_GAP_WAS=`cat $TRG_FILE_SEQ_GAP`
          rm $TRG_FILE_SEQ_GAP
          cat $LOG_FILE | $WMMAIL -s "$MPREFIX ${HOST} / ${DB} - RECOVER: `date +%H:%M:%S-%d/%m/%y` was ${SEQ_GAP_WAS}, now ${SEQ_GAP_NOW} archivelogs not applyed to standby dest_id: ${DEST_ID} (SEQ_GAP limit = $SEQ_GAP logs)" $ADMINS
          echo "SEQ_GAP recover host: "${HOST} " database: "${DB}
        fi
      else
        if [ "$SEQ_GAP_NOW" -ge "$SEQ_GAP" ]; then
          echo "$SEQ_GAP_NOW" > "$TRG_FILE_SEQ_GAP"
          cat $LOG_FILE | $WMMAIL -s "$MPREFIX ${HOST} / ${DB} - TRIGGER: `date +%H:%M:%S-%d/%m/%y` now ${SEQ_GAP_NOW} archivelogs not applyed to standby dest_id: ${DEST_ID} (SEQ_GAP limit = $SEQ_GAP logs)" $ADMINS
          echo "SEQ_GAP trigger host: "${HOST} " database: "${DB}
        fi
      fi

      if [ -s $TRG_FILE_LAG_MINUTES ]; then
        if [ "$LAG_MINUTES_NOW" -lt "$LAG_MINUTES" ]; then
          LAG_MINUTES_WAS=`cat $TRG_FILE_LAG_MINUTES`
          rm $TRG_FILE_LAG_MINUTES
          cat $LOG_FILE | $WMMAIL -s "$MPREFIX ${HOST} / ${DB} - RECOVER: `date +%H:%M:%S-%d/%m/%y` standby dest_id: ${DEST_ID} was ${LAG_MINUTES_WAS}, now ${LAG_MINUTES_NOW} minuted behind (LAG_MINUTES limit = $LAG_MINUTES min)" $ADMINS
          echo "LAG_MINUTES recover host: "${HOST} " database: "${DB}
        fi
      else
        if [ "$LAG_MINUTES_NOW" -ge "$LAG_MINUTES" ]; then
          echo "$LAG_MINUTES_NOW" > "$TRG_FILE_LAG_MINUTES"
          cat $LOG_FILE | $WMMAIL -s "$MPREFIX ${HOST} / ${DB} - TRIGGER: `date +%H:%M:%S-%d/%m/%y` standby dest_id: ${DEST_ID} is ${LAG_MINUTES_NOW} minutes behind (LAG_MINUTES limit = $LAG_MINUTES min)" $ADMINS
          echo "LAG_MINUTES trigger host: "${HOST} " database: "${DB}
        fi
      fi

      # find old trg_files more then at $REPEAT_AT minutes
      HH=`date +%H`
      case "$HH" in
      "${REPEAT_AT}")
         FF=`find "$TRG_FILE_SEQ_GAP" -mmin $REPEAT_MINUTES 2>/dev/null | wc -l`
         if [ "$FF" -eq 1 ]; then
           CNT=`head -1 $TRG_FILE_SEQ_GAP`
           cat $LOG_FILE | $WMMAIL -s "$MPREFIX ${HOST} / ${DB} - TRIGGER REPEAT: `date +%H:%M:%S-%d/%m/%y` more ${SEQ_GAP_NOW} archivelogs not applyed to standby dest_id: ${DEST_ID} (SEQ_GAP limit = $SEQ_GAP logs)" $ADMINS
           echo "SEQ_GAP repeat trigger host: "${HOST} " database: "${DB}
         fi

         FF=`find "$TRG_FILE_LAG_MINUTES" -mmin $REPEAT_MINUTES 2>/dev/null | wc -l`
         if [ "$FF" -eq 1 ]; then
           CNT=`head -1 $TRG_FILE_LAG_MINUTES`
           cat $LOG_FILE | $WMMAIL -s "$MPREFIX ${HOST} / ${DB} - TRIGGER REPEAT: `date +%H:%M:%S-%d/%m/%y` standby dest_id: ${DEST_ID} more ${LAG_MINUTES_NOW} minutes behind (LAG_MINUTES limit = $LAG_MINUTES min)" $ADMINS
           echo "LAG_MINUTES repeat trigger host: "${HOST} " database: "${DB}
         fi
      ;;
     esac
    done # read DEST_ID SEQ_GAP_NOW LAG_MINUTES_NOW
    rm $LOG_FILE 
  done # DB
done # HOST
