#!/bin/bash
# version 07/07/2023 Talgat Mukhametshin  email: mutate@mail.ru

set -f

shopt -s nocasematch
if [[ "$1" =~ "=" ]]; then 
  eval "$1"
  if [ -n "$d" ]; then db="-d $d"; fi
  shift
fi
shopt -u nocasematch
ID=$1

psql_="psql -q $db "


init_msg()
{
  sess__="sess [ idle | active | trx [min] | cancel PID1 ... | kill PID1 ... ]  - sessions, trx - long transactions > 60 min (def), cancel - cancel query with pg_cancel_backend,  kill - kill process with pg_terminate_backend(pid)"
  p__="p [parameter] - parameter from pg_file_settings and pg_settings"
  exec__="exec - execute any command, sample: '\0134\0134\0164'  '\\\\\! OScmd'  '\\\\\dt+ *.table_name'  '\\\\\dt+ \*.\*'  '\\\\\d+ \*.\*' "
  activity__="activity  - activity sessions in DB"
  lock__="lock [all|dead|tree] - locks"
  vacuum__="vacuum - vacuum activity"
  topsql__="topsql - top 20 sql"
  bloat__="bloat - bloat tables"
  dead__="dead - tables with dead rows"
  table__="table [table_name] - table information"
  mastrep__="mastrep - master replication   pg_stat_replication  \  pg_replication_slots (watch on primary)"
  stblag__="stblag - standby lag (watch on standby)"
  log__="log [NUM] - show NUM (def 100) lines of logfile"
}

init_msg

inf()
{
$psql_ <<EOF
\pset format wrapped
\pset columns 230
\pset linestyle unicode
SELECT version();
\l+
\db+
--\du
--\dn
--\dt
EOF
}

if [ -z "$ID" ]; then
#  ps -fu postgres
  echo "Usage: $0 server [d=database]"
  echo -e $sess__"\n"$p__"\n"$exec__"\n"$activity__"\n"$lock__"\n"$vacuum__"\n"$topsql__"\n"$bloat__"\n"$dead__"\n"$mastrep__"\n"$stblag__"\n"$log__"\n"
  inf
  exit
fi

shift
ALL=$*
echo "ALL :" $ALL

db_version()
{
VALUE=$($psql_ -x -c "SHOW server_version;" | awk '/server_version/{print $3}' | awk -F. '{print $1}')
echo $VALUE | tr -d '\r'
}


execute()
{
echo -e "exec: "$ALL
$psql_ <<EOF
$ALL
EOF
}


sess()
{
P1_=$1
case $P1_ in
trx)
P2_=$( if [ -z "$2" ]; then echo "60"; else echo "$2"; fi  )
$psql_ <<EOF
\pset format wrapped
\pset columns 230
\pset linestyle unicode
\pset title "Transaction in 'active' state is too long > $P2_ minutes"
SELECT  pid, now() - pg_stat_activity.query_start AS duration, query, state FROM pg_stat_activity WHERE state = 'active' and (now() - pg_stat_activity.query_start) > interval '$P2_ minutes';
\pset title "Transaction in 'idle in transaction' state is too long > $P2_ minutes"
SELECT  pid, now() - pg_stat_activity.xact_start AS duration, query, state FROM pg_stat_activity WHERE state = 'idle in transaction' and (now() - pg_stat_activity.xact_start) > interval '$P2_ minutes';
EOF
;;
cancel)
shift $(( $# > 1 ? 1 : 0 ))
ALL=$*
for PID in $ALL; do
echo "cancel pid process: " $PID
$psql_ <<EOF
 select pg_cancel_backend($PID);
EOF
done
;;
kill)
shift $(( $# > 1 ? 1 : 0 ))
ALL=$*
for PID in $ALL; do
echo "kill pid process: " $PID
$psql_ <<EOF
 select pg_terminate_backend($PID);
EOF
done
;;
*)
$psql_ <<EOF
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
SELECT  datname, client_addr, COUNT(*) AS session_count
FROM pg_stat_activity
GROUP BY  datname, client_addr
ORDER BY session_count desc;
\pset title "pg_stat_activity where state like '$P1_%'"
SELECT datname, pid, application_name, client_addr, query_start, /*state_change, */ state,  wait_event_type, wait_event,  query
FROM pg_stat_activity WHERE state like '$P1_%' 
ORDER BY query_start ASC;
--LIMIT 50;
EOF
;;
esac
}



p()
{
P1_=$ALL
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
select * from pg_file_settings where name like '%$P1_%';
select name, setting, unit, category, short_desc, min_val, max_val, enumvals, boot_val, reset_val, pending_restart from pg_settings where name like '%$P1_%';
EOF
}



activity()
{
P1_=$ALL
$psql_ <<EOF
\timing
\pset format wrapped
\pset columns 230
SELECT (clock_timestamp() - pg_stat_activity.xact_start) AS ts_age, pg_stat_activity.state, (clock_timestamp() - pg_stat_activity.query_start) as query_age, (clock_timestamp() - state_change) as change_age, pg_stat_activity.datname, pg_stat_activity.pid, pg_stat_activity.usename, coalesce(wait_event_type = 'Lock', 'f') waiting, pg_stat_activity.client_addr, pg_stat_activity.client_port, pg_stat_activity.query
FROM pg_stat_activity
WHERE
((clock_timestamp() - pg_stat_activity.xact_start > '00:00:00.1'::interval) OR (clock_timestamp() - pg_stat_activity.query_start > '00:00:00.1'::interval and state = 'idle in transaction (aborted)'))
and pg_stat_activity.pid<>pg_backend_pid()
ORDER BY coalesce(pg_stat_activity.xact_start, pg_stat_activity.query_start);
EOF
}


lock()
{
P1_=`echo $ALL | awk '{print $1}'`
case "$P1" in
all)
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
SELECT
  COALESCE(bgl.relation::regclass::text, bgl.locktype) AS locked_item,
  now() - bda.query_start AS waiting_duration,
  bda.pid AS blocked_pid, bda.query AS blocked_query, bdl.mode AS blocked_mode, bga.pid AS blocking_pid,
  bga.query AS blocking_query, bgl.mode AS blocking_mode
FROM pg_catalog.pg_locks bdl JOIN pg_stat_activity bda ON bda.pid = bdl.pid
  JOIN pg_catalog.pg_locks bgl ON bgl.pid != bdl.pid
    AND (bgl.transactionid = bdl.transactionid OR bgl.relation = bdl.relation AND bgl.locktype = bdl.locktype)
  JOIN pg_stat_activity bga ON bga.pid = bgl.pid AND bga.datid = bda.datid
WHERE NOT bdl.granted AND bga.datname = current_database();
EOF
;;
dead)
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
WITH RECURSIVE l AS (
  SELECT pid, locktype, mode, GRANTED,
ROW(locktype,DATABASE,relation,page,tuple,virtualxid,transactionid,classid,objid,objsubid) obj
  FROM pg_locks
), pairs AS (
  SELECT w.pid waiter, l.pid locker, l.obj, l.mode
  FROM l w
  JOIN l ON l.obj IS NOT DISTINCT FROM w.obj AND l.locktype=w.locktype AND NOT l.pid=w.pid AND l.granted
  WHERE NOT w.granted
), tree AS (
  SELECT l.locker pid, l.locker root, NULL::record obj, NULL AS mode, 0 lvl, locker::text path, array_agg(l.locker) OVER () all_pids
  FROM ( SELECT DISTINCT locker FROM pairs l WHERE NOT EXISTS (SELECT 1 FROM pairs WHERE waiter=l.locker) ) l
  UNION ALL
  SELECT w.waiter pid, tree.root, w.obj, w.mode, tree.lvl+1, tree.path||'.'||w.waiter, all_pids || array_agg(w.waiter) OVER ()
  FROM tree JOIN pairs w ON tree.pid=w.locker AND NOT w.waiter = ANY ( all_pids )
)
SELECT (clock_timestamp() - a.xact_start)::INTERVAL(3) AS ts_age,
       REPLACE(a.state, 'idle in transaction', 'idletx') state,
       (clock_timestamp() - state_change)::INTERVAL(3) AS change_age,
       a.datname,tree.pid,a.usename,a.client_addr,lvl,
       (SELECT COUNT(*) FROM tree p WHERE p.path ~ ('^'||tree.path) AND NOT p.path=tree.path) blocked,
       repeat(' .', lvl)||' '||LEFT(regexp_replace(query, 's+', ' ', 'g'),100) query
FROM tree
JOIN pg_stat_activity a USING (pid)
ORDER BY path;
EOF
;;
tree)
$psql_ <<EOF
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
WITH RECURSIVE l AS (
  SELECT pid, locktype, granted,
    array_position(ARRAY['AccessShare','RowShare','RowExclusive','ShareUpdateExclusive','Share','ShareRowExclusive','Exclusive','AccessExclusive'], left(mode,-4)) m,
    ROW(locktype,database,relation,page,tuple,virtualxid,transactionid,classid,objid,objsubid) obj FROM pg_locks
), pairs AS (
  SELECT w.pid waiter, l.pid locker, l.obj, l.m
    FROM l w JOIN l ON l.obj IS NOT DISTINCT FROM w.obj AND l.locktype=w.locktype AND NOT l.pid=w.pid AND l.granted
   WHERE NOT w.granted
     AND NOT EXISTS ( SELECT FROM l i WHERE i.pid=l.pid AND i.locktype=l.locktype AND i.obj IS NOT DISTINCT FROM l.obj AND i.m > l.m )
), leads AS (
  SELECT o.locker, 1::int lvl, count(*) q, ARRAY[locker] track, false AS cycle FROM pairs o GROUP BY o.locker
  UNION ALL
  SELECT i.locker, leads.lvl+1, (SELECT count(*) FROM pairs q WHERE q.locker=i.locker), leads.track||i.locker, i.locker=ANY(leads.track)
    FROM pairs i, leads WHERE i.waiter=leads.locker AND NOT cycle
), tree AS (
  SELECT locker pid,locker dad,locker root,CASE WHEN cycle THEN track END dl, NULL::record obj,0 lvl,locker::text path,array_agg(locker) OVER () all_pids FROM leads o
   WHERE (cycle AND NOT EXISTS (SELECT FROM leads i WHERE i.locker=ANY(o.track) AND (i.lvl>o.lvl OR i.q<o.q)))
      OR (NOT cycle AND NOT EXISTS (SELECT FROM pairs WHERE waiter=o.locker) AND NOT EXISTS (SELECT FROM leads i WHERE i.locker=o.locker AND i.lvl<o.lvl))
  UNION ALL
  SELECT w.waiter pid,tree.pid,tree.root,CASE WHEN w.waiter=ANY(tree.dl) THEN tree.dl END,w.obj,tree.lvl+1,tree.path||'.'||w.waiter,all_pids || array_agg(w.waiter) OVER ()
    FROM tree JOIN pairs w ON tree.pid=w.locker AND NOT w.waiter = ANY ( all_pids )
)
SELECT (clock_timestamp() - a.xact_start)::interval(0) AS ts_age,
       (clock_timestamp() - a.state_change)::interval(0) AS change_age,
       a.datname,a.usename,a.client_addr,
       --w.obj wait_on_object,
       tree.pid,replace(a.state, 'idle in transaction', 'idletx') state,
       lvl,(SELECT count(*) FROM tree p WHERE p.path ~ ('^'||tree.path) AND NOT p.path=tree.path) blocked,
       CASE WHEN tree.pid=ANY(tree.dl) THEN '!>' ELSE repeat(' .', lvl) END||' '||trim(left(regexp_replace(a.query, E'\\s+', ' ', 'g'),100)) query
  FROM tree
  LEFT JOIN pairs w ON w.waiter=tree.pid AND w.locker=tree.dad
  JOIN pg_stat_activity a USING (pid)
  JOIN pg_stat_activity r ON r.pid=tree.root
 ORDER BY (now() - r.xact_start), path;
EOF
;;
*)
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
SELECT pid, state, datname, usename,
(clock_timestamp() - xact_start) AS xact_age,
    (clock_timestamp() - query_start) AS query_age,
    (clock_timestamp() - state_change) AS change_age,
    COALESCE(wait_event_type = 'Lock', 'f') AS waiting,
    wait_event_type ||'.'|| wait_event AS wait_details,
    client_addr ||'.'|| client_port AS client,
    query
FROM pg_stat_activity
WHERE clock_timestamp() - COALESCE(xact_start, query_start) > '00:00:00.1'::INTERVAL
AND pid <> pg_backend_pid() AND state <> 'idle'
ORDER BY COALESCE(xact_start, query_start);
EOF
;;
esac
}


vacuum()
{
$psql_ <<EOF
--\x ON
\timing
-- vacuum activity
SELECT * FROM pg_stat_progress_vacuum;

SELECT
        p.pid,
        now() - a.xact_start AS duration,
        COALESCE(wait_event_type ||'.'|| wait_event, 'f') AS waiting,
        CASE
                WHEN a.query ~ '^autovacuum.*to prevent wraparound' THEN 'wraparound'
                WHEN a.query ~ '^vacuum' THEN 'user'
                ELSE 'regular'
        END AS mode,
        p.datname AS DATABASE,
        p.relid::regclass AS TABLE,
        p.phase,
        pg_size_pretty(p.heap_blks_total * current_setting('block_size')::INT) AS table_size,
        pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
        pg_size_pretty(p.heap_blks_scanned * current_setting('block_size')::INT) AS scanned,
        pg_size_pretty(p.heap_blks_vacuumed * current_setting('block_size')::INT) AS vacuumed,
        round(100.0 * p.heap_blks_scanned / p.heap_blks_total, 1) AS scanned_pct,
        round(100.0 * p.heap_blks_vacuumed / p.heap_blks_total, 1) AS vacuumed_pct,
        p.index_vacuum_count,
        round(100.0 * p.num_dead_tuples / p.max_dead_tuples,1) AS dead_pct
FROM pg_stat_progress_vacuum p
RIGHT JOIN pg_stat_activity a ON a.pid = p.pid
WHERE (a.query ~* '^autovacuum:' OR a.query ~* '^vacuum') AND a.pid <> pg_backend_pid()
ORDER BY now() - a.xact_start DESC;

--table_autovacuum-stats
--SELECT relname, n_dead_tup, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_all_tables WHERE n_dead_tup>0 ORDER BY n_dead_tup DESC;
--SELECT schemaname ||'.'|| relname AS relname, n_dead_tup, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables WHERE n_dead_tup>0 ORDER BY n_dead_tup DESC;
--SELECT schemaname ||'.'|| relname, n_dead_tup, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables WHERE last_autovacuum IS NOT NULL ORDER BY n_dead_tup DESC;
--SELECT schemaname ||'.'|| relname, n_dead_tup, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables;
--SELECT SUM(heap_blks_read) AS heap_read, SUM(heap_blks_hit)  AS heap_hit, (SUM(heap_blks_hit) - SUM(heap_blks_read)) / SUM(heap_blks_hit) AS ratio FROM pg_statio_user_tables;
--SELECT SUM(idx_blks_read) AS idx_read, SUM(idx_blks_hit)  AS idx_hit, (SUM(idx_blks_hit) - SUM(idx_blks_read)) / SUM(idx_blks_hit) AS ratio FROM pg_statio_user_indexes;
--SELECT datname, age(datfrozenxid) FROM pg_database;

-- table autovacuum stat
WITH rel_set AS
(
    SELECT
        oid,
        CASE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_threshold=', 2), ',', 1)
            WHEN '' THEN NULL
        ELSE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_threshold=', 2), ',', 1)::BIGINT
        END AS rel_av_vac_threshold,
        CASE split_part(split_part(array_to_string(reloptions, ','),  'autovacuum_vacuum_scale_factor=', 2), ',', 1)
            WHEN '' THEN NULL
        ELSE split_part(split_part(array_to_string(reloptions, ','), 'autovacuum_vacuum_scale_factor=', 2), ',', 1)::NUMERIC
        END AS rel_av_vac_scale_factor
    FROM pg_class
)
SELECT
    PSUT.relname,
    to_char(PSUT.last_vacuum, 'YYYY-MM-DD HH24:MI')     AS last_vacuum,
    to_char(PSUT.last_autovacuum, 'YYYY-MM-DD HH24:MI') AS last_autovacuum,
    to_char(C.reltuples, '9G999G999G999')               AS n_tup,
    to_char(PSUT.n_dead_tup, '9G999G999G999')           AS dead_tup,
    to_char(COALESCE(RS.rel_av_vac_threshold, current_setting('autovacuum_vacuum_threshold')::BIGINT) + COALESCE(RS.rel_av_vac_scale_factor, current_setting('autovacuum_vacuum_scale_factor')::NUMERIC) * C.reltuples, '9G999G999G999') AS av_threshold,
    CASE
        WHEN (COALESCE(RS.rel_av_vac_threshold, current_setting('autovacuum_vacuum_threshold')::BIGINT) + COALESCE(RS.rel_av_vac_scale_factor, current_setting('autovacuum_vacuum_scale_factor')::NUMERIC) * C.reltuples)  < PSUT.n_dead_tup
        THEN '*'
    ELSE ''
    END AS expect_av
FROM
    pg_stat_user_tables PSUT
    JOIN pg_class C
        ON PSUT.relid = C.oid
    JOIN rel_set RS
        ON PSUT.relid = RS.oid
ORDER BY C.reltuples DESC;
EOF
}

topsql()
{
echo "VERSION: " $(db_version)

case "$(db_version)" in
15|14|13)         S1_="total_exec_time" ; S2_="mean_exec_time" ;;
12|11|10|9|8)     S1_="total_time"      ; S2_="mean_time"      ;; 
*)                S1_="total_time"      ; S2_="mean_time"      ;; 
esac

$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
SELECT substring(query, 1, 150) AS short_query,
              round($S1_::numeric, 2) AS $S1_,
              calls,
              round($S2_::numeric, 2) AS mean,
              round((100 * $S1_ / sum($S1_::numeric) OVER ())::numeric, 2) AS percentage_cpu
FROM  pg_stat_statements
ORDER BY $S1_ DESC
LIMIT 20;

with pg_stat_statements_normalized as (
--    select *, translate( regexp_replace( regexp_replace( regexp_replace( regexp_replace(query, E'\\?(::[a-zA-Z_]+)?( *, *\\?(::[a-zA-Z_]+)?)+', '?', 'g'), E'\\$[0-9]+(::[a-zA-Z_]+)?( *, *\\$[0-9]+(::[a-zA-Z_]+)?)*', '$N', 'g'), E'--.*$', '', 'ng'), E'/\\*.*?\\*/', '', 'g'), E'\r', '') as query_normalized
    select *,  query as query_normalized
    --if current database is postgres then generate report for all databases otherwise generate for current database only
    from pg_stat_statements where current_database() = 'postgres' or dbid in (SELECT oid from pg_database where datname=current_database())
),
totals as (
    select sum($S1_) AS $S1_, sum(blk_read_time+blk_write_time) as io_time,
    sum($S1_-blk_read_time-blk_write_time) as cpu_time, sum(calls) AS ncalls,
    sum(rows) as total_rows FROM pg_stat_statements
    WHERE current_database() = 'postgres' or dbid in (SELECT oid from pg_database where datname=current_database())
),
_pg_stat_statements as (
    select
    coalesce((select datname from pg_database where oid = p.dbid), 'unknown') as database,
    coalesce((select rolname from pg_roles where oid = p.userid), 'unknown') as username,
    --select shortest query, replace \n\n-- strings to avoid email clients format text as footer
    substring(
    translate(
    replace(
    (array_agg(query order by length(query)))[1],
    E'-- \n',
    E'--\n'),
    E'\r', ''),
    1, 8192) as query,
    sum($S1_) as $S1_,
    sum(blk_read_time) as blk_read_time, sum(blk_write_time) as blk_write_time,
    sum(calls) as calls, sum(rows) as rows
    from pg_stat_statements_normalized p
    where calls > 0
    group by dbid, userid, md5(query_normalized)
),
totals_readable as (
    select to_char(interval '1 millisecond' * $S1_, 'HH24:MI:SS') as $S1_,
    (100*io_time/$S1_)::numeric(20,2) AS io_time_percent,
    to_char(ncalls, 'FM999,999,999,990') AS total_queries,
    (select to_char(count(distinct md5(query)), 'FM999,999,990') from _pg_stat_statements) as unique_queries
    from totals
),
statements as (
    select
    (100*$S1_/(select $S1_ from totals)) AS time_percent,
    (100*(blk_read_time+blk_write_time)/(select greatest(io_time, 1) from totals)) AS io_time_percent,
    (100*($S1_-blk_read_time-blk_write_time)/(select cpu_time from totals)) AS cpu_time_percent,
    to_char(interval '1 millisecond' * $S1_, 'HH24:MI:SS') AS $S1_,
    ($S1_::numeric/calls)::numeric(20,2) AS avg_time,
    (($S1_-blk_read_time-blk_write_time)::numeric/calls)::numeric(20, 2) AS avg_cpu_time,
    ((blk_read_time+blk_write_time)::numeric/calls)::numeric(20, 2) AS avg_io_time,
    to_char(calls, 'FM999,999,999,990') AS calls,
    (100*calls/(select ncalls from totals))::numeric(20, 2) AS calls_percent,
    to_char(rows, 'FM999,999,999,990') AS rows,
    (100*rows/(select total_rows from totals))::numeric(20, 2) AS row_percent,
    database,
    username,
    query
    from _pg_stat_statements
    where (($S1_-blk_read_time-blk_write_time)/(select cpu_time from totals)>=0.01 or (blk_read_time+blk_write_time)/(select greatest(io_time, 1) from totals)>=0.01 or calls/(select ncalls from totals)>=0.02 or rows/(select total_rows from totals)>=0.02)
union all
    select
    (100*sum($S1_)::numeric/(select $S1_ from totals)) AS time_percent,
    (100*sum(blk_read_time+blk_write_time)::numeric/(select greatest(io_time, 1) from totals)) AS io_time_percent,
    (100*sum($S1_-blk_read_time-blk_write_time)::numeric/(select cpu_time from totals)) AS cpu_time_percent,
    to_char(interval '1 millisecond' * sum($S1_), 'HH24:MI:SS') AS $S1_,
    (sum($S1_)::numeric/sum(calls))::numeric(20,2) AS avg_time,
    (sum($S1_-blk_read_time-blk_write_time)::numeric/sum(calls))::numeric(20, 2) AS avg_cpu_time,
    (sum(blk_read_time+blk_write_time)::numeric/sum(calls))::numeric(20, 2) AS avg_io_time,
    to_char(sum(calls), 'FM999,999,999,990') AS calls,
    (100*sum(calls)/(select ncalls from totals))::numeric(20, 2) AS calls_percent,
    to_char(sum(rows), 'FM999,999,999,990') AS rows,
    (100*sum(rows)/(select total_rows from totals))::numeric(20, 2) AS row_percent,
    'all' as database,
    'all' as username,
    'other' as query
    from _pg_stat_statements
    where not (($S1_-blk_read_time-blk_write_time)/(select cpu_time from totals)>=0.01 or (blk_read_time+blk_write_time)/(select greatest(io_time, 1) from totals)>=0.01 or calls/(select ncalls from totals)>=0.02 or rows/(select total_rows from totals)>=0.02)
),
statements_readable as (
    select row_number() over (order by s.time_percent desc) as pos,
    to_char(time_percent, 'FM990.0') || '%' AS time_percent,
    to_char(io_time_percent, 'FM990.0') || '%' AS io_time_percent,
    to_char(cpu_time_percent, 'FM990.0') || '%' AS cpu_time_percent,
    to_char(avg_io_time*100/(coalesce(nullif(avg_time, 0), 1)), 'FM990.0') || '%' AS avg_io_time_percent,
    $S1_, avg_time, avg_cpu_time, avg_io_time, calls, calls_percent, rows, row_percent,
    database, username, query
    from statements s where calls is not null
)

select E'total time:\t' || $S1_ || ' (IO: ' || io_time_percent || E'%)\n' ||
E'total queries:\t' || total_queries || ' (unique: ' || unique_queries || E')\n' ||
'report for ' || (select case when current_database() = 'postgres' then 'all databases' else current_database() || ' database' end) || E', version 0.9.5' ||
' @ PostgreSQL ' || (select setting from pg_settings where name='server_version') || E'\ntracking ' || (select setting from pg_settings where name='pg_stat_statements.track') || ' ' ||
(select setting from pg_settings where name='pg_stat_statements.max') || ' queries, utilities ' || (select setting from pg_settings where name='pg_stat_statements.track_utility') ||
', logging ' || (select (case when setting = '0' then 'all' when setting = '-1' then 'none' when setting::int > 1000 then (setting::numeric/1000)::numeric(20, 1) || 's+' else setting || 'ms+' end) from pg_settings where name='log_min_duration_statement') || E' queries\n' ||
(select coalesce(string_agg('WARNING: database ' || datname || ' must be vacuumed within ' || to_char(2147483647 - age(datfrozenxid), 'FM999,999,999,990') || ' transactions', E'\n' order by age(datfrozenxid) desc) || E'\n', '')
 from pg_database where (2147483647 - age(datfrozenxid)) < 200000000) || E'\n'
from totals_readable
union all
(select E'=============================================================================================================\n' ||
'pos:' || pos || E'\t total time: ' || $S1_ || ' (' || time_percent || ', CPU: ' || cpu_time_percent || ', IO: ' || io_time_percent || E')\t calls: ' || calls ||
' (' || calls_percent || E'%)\t avg_time: ' || avg_time || 'ms (IO: ' || avg_io_time_percent || E')\n' ||
'user: ' || username || E'\t db: ' || database || E'\t rows: ' || rows || ' (' || row_percent || '%)' || E'\t query:\n' || coalesce(query, 'unknown') || E'\n'
from statements_readable order by pos);
EOF
}



dead()
{
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
SELECT *,
  n_dead_tup > av_thresh AS "av_need",
  n_mod_tup > anl_thresh AS "anl_need",
  CASE WHEN reltuples > 0
    THEN round(100.0 * n_dead_tup / (reltuples))
    ELSE 0
  END AS pct_dead
FROM
  (SELECT
     N.nspname ||'.'|| C.relname AS relation,
     pg_stat_get_tuples_inserted(C.oid) AS n_tup_ins,
     pg_stat_get_tuples_updated(C.oid) AS n_tup_upd,
     pg_stat_get_tuples_deleted(C.oid) AS n_tup_del,
     pg_stat_get_live_tuples(C.oid) AS n_live_tup,
     pg_stat_get_dead_tuples(C.oid) AS n_dead_tup,
     pg_stat_get_mod_since_analyze(C.oid) AS n_mod_tup,
     C.reltuples AS reltuples,
     round(current_setting('autovacuum_vacuum_threshold')::INTEGER + current_setting('autovacuum_vacuum_scale_factor')::NUMERIC * C.reltuples) AS av_thresh,
     round(current_setting('autovacuum_analyze_threshold')::INTEGER + current_setting('autovacuum_analyze_scale_factor')::NUMERIC * C.reltuples) AS anl_thresh,
     date_trunc('days',now() - greatest(pg_stat_get_last_vacuum_time(C.oid),
     pg_stat_get_last_autovacuum_time(C.oid))) AS last_vacuum,
     date_trunc('days',now() - greatest(pg_stat_get_last_analyze_time(C.oid),
     pg_stat_get_last_analyze_time(C.oid))) AS last_analyze
   FROM pg_class C
   LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
   WHERE C.relkind IN ('r', 'm', 't')
   AND N.nspname NOT IN ('pg_catalog', 'information_schema')
   AND N.nspname !~ '^pg_toast'
  ) AS av
ORDER BY av_need, anl_need, n_dead_tup DESC;
EOF
}

bloat()
{
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
WITH constants AS (
    -- define some constants for sizes of things
    -- for reference down the query and easy maintenance
    SELECT current_setting('block_size')::NUMERIC AS bs, 23 AS hdr, 8 AS ma
),
no_stats AS (
    -- screen out table who have attributes
    -- which dont have stats, such as JSON
    SELECT table_schema, TABLE_NAME, 
        n_live_tup::NUMERIC AS est_rows,
        pg_table_size(relid)::NUMERIC AS table_size
    FROM information_schema.columns
        JOIN pg_stat_user_tables AS psut
           ON table_schema = psut.schemaname
           AND TABLE_NAME = psut.relname
        LEFT OUTER JOIN pg_stats
        ON table_schema = pg_stats.schemaname
            AND TABLE_NAME = pg_stats.tablename
            AND column_name = attname 
    WHERE attname IS NULL
        AND table_schema NOT IN ('pg_catalog', 'information_schema')
    GROUP BY table_schema, TABLE_NAME, relid, n_live_tup
),
null_headers AS (
    -- calculate null header sizes
    -- omitting tables which dont have complete stats
    -- and attributes which aren't visible
    SELECT
        hdr+1+(SUM(CASE WHEN null_frac <> 0 THEN 1 ELSE 0 END)/8) AS nullhdr,
        SUM((1-null_frac)*avg_width) AS datawidth,
        MAX(null_frac) AS maxfracsum,
        schemaname,
        tablename,
        hdr, ma, bs
    FROM pg_stats CROSS JOIN constants
        LEFT OUTER JOIN no_stats
            ON schemaname = no_stats.table_schema
            AND tablename = no_stats.table_name
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        AND no_stats.table_name IS NULL
        AND EXISTS ( SELECT 1
            FROM information_schema.columns
                WHERE schemaname = COLUMNS.table_schema
                    AND tablename = COLUMNS.table_name )
    GROUP BY schemaname, tablename, hdr, ma, bs
),
data_headers AS (
    -- estimate header and row size
    SELECT
        ma, bs, hdr, schemaname, tablename,
        (datawidth+(hdr+ma-(CASE WHEN hdr%ma=0 THEN ma ELSE hdr%ma END)))::NUMERIC AS datahdr,
        (maxfracsum*(nullhdr+ma-(CASE WHEN nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM null_headers
),
table_estimates AS (
    -- make estimates of how large the table should be
    -- based on row and page size
    SELECT schemaname, tablename, bs,
        reltuples::NUMERIC AS est_rows, relpages * bs AS table_bytes,
    CEIL((reltuples*
            (datahdr + nullhdr2 + 4 + ma -
                (CASE WHEN datahdr%ma=0
                    THEN ma ELSE datahdr%ma END)
                )/(bs-20))) * bs AS expected_bytes,
        reltoastrelid
    FROM data_headers
        JOIN pg_class ON tablename = relname
        JOIN pg_namespace ON relnamespace = pg_namespace.oid
            AND schemaname = nspname
    WHERE pg_class.relkind = 'r'
),
estimates_with_toast AS (
    -- add in estimated TOAST table sizes
    -- estimate based on 4 toast tuples per page because we dont have 
    -- anything better.  also append the no_data tables
    SELECT schemaname, tablename, 
        TRUE AS can_estimate,
        est_rows,
        table_bytes + ( COALESCE(toast.relpages, 0) * bs ) AS table_bytes,
        expected_bytes + ( CEIL( COALESCE(toast.reltuples, 0) / 4 ) * bs ) AS expected_bytes
    FROM table_estimates LEFT OUTER JOIN pg_class AS toast
        ON table_estimates.reltoastrelid = toast.oid
            AND toast.relkind = 't'
),
table_estimates_plus AS (
-- add some extra metadata to the table data
-- and calculations to be reused
-- including whether we cant estimate it
-- or whether we think it might be compressed
    SELECT current_database() AS databasename,
            schemaname, tablename, can_estimate, 
            est_rows,
            CASE WHEN table_bytes > 0
                THEN table_bytes::NUMERIC
                ELSE NULL::NUMERIC END
                AS table_bytes,
            CASE WHEN expected_bytes > 0 
                THEN expected_bytes::NUMERIC
                ELSE NULL::NUMERIC END
                    AS expected_bytes,
            CASE WHEN expected_bytes > 0 AND table_bytes > 0
                AND expected_bytes <= table_bytes
                THEN (table_bytes - expected_bytes)::NUMERIC
                ELSE 0::NUMERIC END AS bloat_bytes
    FROM estimates_with_toast
    UNION ALL
    SELECT current_database() AS databasename, 
        table_schema, TABLE_NAME, FALSE, 
        est_rows, table_size,
        NULL::NUMERIC, NULL::NUMERIC
    FROM no_stats
),
bloat_data AS (
    -- do final math calculations and formatting
    SELECT current_database() AS databasename,
        schemaname, tablename, can_estimate, 
        table_bytes, round(table_bytes/(1024^2)::NUMERIC,3) AS table_mb,
        expected_bytes, round(expected_bytes/(1024^2)::NUMERIC,3) AS expected_mb,
        round(bloat_bytes*100/table_bytes) AS pct_bloat,
        round(bloat_bytes/(1024::NUMERIC^2),2) AS mb_bloat,
        table_bytes, expected_bytes, est_rows
    FROM table_estimates_plus
)
-- filter output for bloated tables
SELECT databasename, schemaname, tablename,
    can_estimate,
    est_rows,
    pct_bloat, mb_bloat,
    table_mb
FROM bloat_data
-- this where clause defines which tables actually appear
-- in the bloat chart
-- example below filters for tables which are either 50%
-- bloated and more than 20mb in size, or more than 25%
-- bloated and more than 1GB in size
WHERE ( pct_bloat >= 15 AND mb_bloat >= 20 )
    OR ( pct_bloat >= 15 AND mb_bloat >= 1000 )
ORDER BY pct_bloat DESC;
EOF
}

table()
{
P1_=`echo $ALL | awk '{print $1}'`
echo "table: " $P1_
$psql_ <<EOF
--\x ON
\timing off
\pset format wrapped
\pset columns 230
\pset linestyle unicode
\pset title "pg_catalog.pg_namespace pg_catalog.pg_class WHERE c.relname like '${P1_}'"
SELECT c.oid,
  n.nspname,
  c.relname,
 pg_catalog.pg_table_is_visible(c.oid) pg_table_is_visible,
 pg_relation_size(n.nspname||'.'||c.relname,'main') size_main,
 pg_relation_size(n.nspname||'.'||c.relname,'fsm') size_fsm,
 pg_relation_size(n.nspname||'.'||c.relname,'vm') size_vm
FROM pg_catalog.pg_class c
     LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE 
  c.relname like '${P1_}' AND
  n.nspname NOT IN ('pg_catalog', 'information_schema') 
-- AND pg_catalog.pg_table_is_visible(c.oid)
ORDER BY 2, 3;

\pset title "information_schema.tables where table_name like '${P1_}'"
SELECT
    table_name,
    pg_size_pretty(table_size) AS table_size,
    pg_size_pretty(indexes_size) AS indexes_size,
    pg_size_pretty(total_size) AS total_size
FROM (
    SELECT
        table_name,
        pg_table_size(table_name) AS table_size,
        pg_indexes_size(table_name) AS indexes_size,
        pg_total_relation_size(table_name) AS total_size
    FROM (
        SELECT ('"' || table_schema || '"."' || table_name || '"') AS table_name
        FROM information_schema.tables where table_name like '${P1_}'
    ) AS all_tables
    ORDER BY total_size DESC
) AS pretty_sizes;

SELECT ('"' || table_schema || '"."' || table_name || '"') AS table_name FROM information_schema.tables where table_name like '${P1_}'
\gset
\d+ :table_name
EOF
}


mastrep()
{
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
select pg_current_wal_lsn();
\pset title pg_stat_replication
select * from pg_stat_replication;
\pset title pg_replication_slots
select * from pg_replication_slots;
EOF
}


stblag()
{
$psql_ <<EOF
--\x ON
\timing
\pset format wrapped
\pset columns 230
\pset linestyle unicode
SELECT pg_is_in_recovery();
select now()-pg_last_xact_replay_timestamp() as replication_lag;
select pg_last_wal_receive_lsn();
\x ON
\pset title pg_stat_wal_receiver
select * from  pg_stat_wal_receiver; 
EOF
}

log()
{
P1_=$1
if [ -z "$P1_" ]; then P1_=100; fi
LC=$($psql_  -t -c "select setting from pg_settings where name like 'logging_collector';")
LC=$(echo $LC | sed 's/^[ \t]*//')
if [ "$LC" = "on" ]; then
  PTLOGS=$($psql_ -t -c "select setting||'/'||(select setting from pg_settings where name like 'log_directory') from pg_settings where name like 'data_directory';")
  PTLOGS=$(echo $PTLOGS | sed 's/^[ \t]*//')
  CMD=$($psql_ -t -c "select 'select pg_ls_dir from pg_ls_dir('''||setting||''') where  (pg_stat_file('''||setting||'/'' || pg_ls_dir)).isdir = false ORDER BY   (pg_stat_file('''||setting||'/'' || pg_ls_dir)).modification   DESC LIMIT 1;' from pg_settings where name like 'log_directory';")
  LOGF=$($psql_ -t -c "$CMD")
  LOGF=$(echo $LOGF | sed 's/^[ \t]*//')
  LOG_=$PTLOGS'/'$LOGF
  echo "tail -$P1_ " $LOG_
  tail -${P1_} $LOG_
else
  LOG_=$(pg_lsclusters | tail -1 | awk '{print $NF}')
  echo "tail -$P1_ " $LOG_
  tail -${P1_} $LOG_
fi
}



case "$ID" in
sess)       echo $sess__ ; sess $ALL ;;
p)          echo $p__ ;     p $ALL ;;
exec)       echo -e $exec__ ;  execute $ALL ;;
activity)   echo $activity__; activity $ALL ;;
lock)        echo $lock__ ;  lock $ALL ;;
vacuum)     echo $vacuum__ ; vacuum $ALL ;;
topsql)     echo $topsql__  ; topsql $ALL ;;
bloat)      echo $bloat__  ; bloat $ALL ;;
dead)       echo $dead__  ; dead $ALL ;;
table)      echo $table__  ; table $ALL ;;
mastrep)    echo $mastrep__  ; mastrep $ALL ;;
stblag)     echo $stblag__  ; stblag $ALL ;;
log)        echo $log__  ; log $ALL ;;
*)          echo $ALL ; inf $ALL ;; 
esac


