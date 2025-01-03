[servers]
host=aisprod
host=aisstb
host=unit
host=alpha
host=beta
host=gw
host=crm
host=msfo

[exclude]
#host:db:scripts=crm:%:mon_swap.sh:mon_tbs.sh:mon_ping_ssh.sh
host:db:scripts=aisprod:%:mon_swap.sh

[aisprod]
db=aisutf

[aisstb]
db=aisutf

[unit]
db=unit

[alpha]
db=aisutf

[beta]
db=aisutf

[crm]
db=crm

[msfo]
db=msfo

[mail]
# script=mmail.nomad
script=tgmail_html
# script=tyandex
# script=tyandex_html
prefix=NOMAD->
# % - mask send mail for all host or db or scripts
# host:db:set=%:%:%
host:db:set=aisprod:aisutf:%
host:db:set=aisstb:aisutf:%
host:db:set=unit:unit:%
host:db:set=alpha:aisutf:%
host:db:set=beta:aisutf:mon_disksp.sh:mon_swap.sh:mon_tbs.sh:mon_ping_ssh.sh:%
host:db:set=gw:%:mon_disksp.sh:mon_swap.sh:mon_ping_ssh.sh
host:db:set=crm:crm:%
host:db:set=msfo:msfo:%

[admins]
email=dba.almaty@gmail.com

[telegram]
cmd=/home/oracle/telegram-bot-bash/bin/send_message.sh
chat_id=376048411
# % - mask send mail for all host or db or scripts
# host:db:set=%:%:%
host:db:set=aisprod:aisutf:mon_db.sh:mon_disksp.sh:mon_ping_ssh.sh:mon_limsess.sh:mon_tbs.sh
#host:db:set=%:aisutf:%

[resource_limit]
processes=80
sessions=80
enqueue_locks=80
max_rollback_segments=80

[others]
# in counts
resumable=0
SSHConnectTimeout=5

[locks]
threshold=30

[diskspace]
# free space limit in %
limitPER=93
# free space limin in Gb
limitGB=15

[swap]
limitPER=100

[load]
limitPER=70

[tbs]
# free space limit in % 92
limitPER=92
# free space limin in Gb 32
limitGB=7

[standby]
# limit in minutes unapplied archivelogs
lag_minutes=120
# limit count unapplied archivelogs
seq_gap=50
# repeat TRIGGER mail if trg_file is older than "repeat_minutes"
repeat_minutes=600
# repeat TRIGGER mail at "repeat_at" hour
repeat_at=08
# standby for database primary_host=db:standby_host
aisprod=aisutf:aisstb

[fra]
# FRA limit in %
limitPER=80

[alert]
part_of_day=24
lines=60000
exclude=ORA-01005
exclude=ORA-01422
exclude=ORA-06512
exclude=ORA-12012

# nomad aisprod
[alert:aisprod:aisutf]
exclude=ORA-12012
exclude=ORA-20001

# nomad beta
[alert:beta:aisutf]
exclude=ORA-0
exclude=ORA-28
exclude=ORA-2396
exclude=ORA-00060
exclude=ORA-12012
exclude=ORA-20200
exclude=ORA-06512
exclude=ORA-00030
exclude=ORA-20001
exclude=ORA-20008
exclude=ORA-29283
exclude=ORA-29266
exclude=ORA-27366

# nomad aisstb
[alert:aisstb:aisutf]
exclude=ORA-279
exclude=ORA-308
exclude=ORA-00308
exclude=ORA-27037

# backup param where host:db:set=HOST:DB:NAS:RETENTION_POLICY:RETENTION_POLICY_NUM:CATALOG\NOCATALOG:LEVEL - 0 1 2 OR ANY OTHER for statement: "not backed up since time 'sysdate-1'"
[backup]
hours_since_lvl0=170
hours_since_lvl1=170
hours_since_arch=6
hours_since_ctrl=12
level0=Sun
level1=Tue,Thu,Sat
level2=Mon,Wed,Fri
target=/
tns_catalog=rman/rman@TNS_CATALOG
# #backup param where host:db:set=HOST:DB:NAS:RETENTION_POLICY:RETENTION_POLICY_NUM:CATALOG\NOCATALOG:LEVEL - 0 1 2 OR ANY OTHER for statement: "not backed up since time 'sysdate-1'"
host:db:set=aisprod:aisutf:nas:RECOVERY_WINDOW_OF:7:nocatalog
host:db:set=unit:unit:nas:RECOVERY_WINDOW_OF:7:nocatalog
host:db:set=crm:crm:nas:RECOVERY_WINDOW_OF:7:nocatalog
host:db:set=msfo:msfo:nas:RECOVERY_WINDOW_OF:7:nocatalog

