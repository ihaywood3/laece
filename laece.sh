#!/bin/bash
SWIPL=/usr/local/bin/pl
PORT=8080
LOGFILE=/home/ian/laece.log
PIDFILE=/home/ian/laece.pid
SCRIPT=/home/ian/laece/web.pl
TMPDIR=/tmp
RESOURCES=/home/ian/laece/www
DB=/home/ian/laece/db
SRC=/home/ian/laece

case "$1" in
  start)
        cd $TMPDIR
        $SWIPL -q -s $SCRIPT -p resources=$RESOURCES -p db=$DB -g server_thread\($PORT\). -t halt >> $LOGFILE 2>&1 &
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
  debug)
        cd $TMPDIR
        xpce -s $SCRIPT -p resources=$RESOURCES -p db=$DB -p src=$SRC -g server_xpce.
  ;;
  *)
        echo "Usage: laece.sh {start|stop|restart|force-reload|debug}"
        exit 1
  ;;
esac

exit 0


