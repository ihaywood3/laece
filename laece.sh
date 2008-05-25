#!/bin/bash
SWIPL=/usr/local/bin/pl
PORT=8080
LOGFILE=$HOME/laece.log
PIDFILE=$HOME/laece.pid
SCRIPT=$HOME/laece/web.pl
TMPDIR=/tmp
RESOURCES=$HOME/laece/www
DB=$HOME/laece/db
SRC=$HOME/laece

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


