#!/bin/bash
SWIPL=/usr/local/bin/pl
PORT=8085
LOGFILE=/home/ian/perm.log
PIDFILE=/home/ian/perm.pid
SCRIPT=/home/ian/preserve/perm/web.pl
TMPDIR=/tmp
RESOURCES=/home/ian/preserve/perm
DB=/home/ian/preserve/perm/db

case "$1" in
  start)
        cd $TMPDIR
        $SWIPL -q -s $SCRIPT -p resources=$RESOURCES -p dbfiles=$DB -g server_thread\($PORT\). -t halt >> $LOGFILE 2>&1 &
        echo $! > $PIDFILE
        disown
  ;;
  stop)
        kill `cat $PIDFILE`
  ;;
  restart|force-reload)
        $0 stop || true
        $0 start
  ;;
  *)
        echo "Usage: perm.sh {start|stop|restart|force-reload}"
        exit 1
  ;;
esac

exit 0


