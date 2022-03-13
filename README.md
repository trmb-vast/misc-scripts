# misc-scripts
```
ioblast          --  a small and simple benchmark which has minimal filer impact, but will demonstrate levels of saturation
ioblast_canary   --  a wrapper to be called by cron which runs ioblast and sends the result to graphite to be trended with grafana
ll               --  a wrapper to replace the "ll" alias which usually is "ls -l" to make ls faster by stating a read-only mount
auto.scratch.sh  --  an executeable automount script which will pick a VIP by the clients IP address
dirsync_nfs.c    --  a wrapper script which will create/lock/unlock/remove a file in a directory, in order to flush attribute-cache for that directory
```
