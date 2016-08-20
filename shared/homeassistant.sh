#!/bin/sh
CONF=/etc/config/qpkg.conf
QPKG_NAME="qnap-homeassistant"
QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${CONF}`
APACHE_ROOT=/share/`/sbin/getcfg SHARE_DEF defWeb -d Qweb -f /etc/config/def_share.info`

# Others
PYTHON_DIR=`/sbin/getcfg Python3 Install_Path -f ${CONF}`
PYTHON="$PYTHON_DIR/python3/bin/python3"
PIP3="$PYTHON_DIR/python3/bin/pip3"
HASS="$PYTHON_DIR/python3/bin/hass"
PID_FILE="/tmp/home-assistant.pid"
FLAGS="-v --config $QPKG_ROOT/conf --pid-file $PID_FILE --daemon"
LOG_FILE="$QPKG_ROOT/conf/home-assistant.log"
REDIRECT="> $LOG_FILE 2>&1"

start_daemon () {
    /bin/sh -c "$PYTHON $HASS $FLAGS $REDIRECT;"
}

update_hass () {
    /bin/sh -c "$PIP3 install --upgrade homeassistant"
}

install_mysql () {
    export PATH=$PATH:/usr/local/mysql/bin
    /bin/sh -c "$PIP3 install mysqlclient"
}

stop_daemon () {
    kill `cat ${PID_FILE}`
    wait_for_status 1 20 || kill -9 `cat ${PID_FILE}`
    rm -f ${PID_FILE}
}

daemon_status () {
    if [ -f ${PID_FILE} ] && kill -0 `cat ${PID_FILE}` > /dev/null 2>&1; then
        return
    fi
    rm -f ${PID_FILE}
    return 1
}

wait_for_status () {
    counter=$2
    while [ ${counter} -gt 0 ]; do
        daemon_status
        [ $? -eq $1 ] && return
        let counter=counter-1
        sleep 1
    done
    return 1
}

case $1 in
    start)
        if daemon_status; then
            echo ${QPKG_NAME} is already running
            exit 0
        else
            echo Starting ${QPKG_NAME} ...
            start_daemon
            exit $?
        fi
        ;;
    stop)
        if daemon_status; then
            echo Stopping ${QPKG_NAME} ...
            stop_daemon
            exit $?
        else
            echo ${QPKG_NAME} is not running
            exit 0
        fi
        ;;
    restart)
        if daemon_status; then
            echo Stopping ${QPKG_NAME} ...
            stop_daemon
            echo Starting ${QPKG_NAME} ...
            start_daemon
            exit $?
        else
            echo ${QPKG_NAME} is not running
            echo Starting ${QPKG_NAME} ...
            start_daemon
            exit $?
        fi
        ;;
    update)
	if daemon_status; then
	    echo Stopping ${QPKG_NAME} ...
        stop_daemon
	    echo Updating ${QPKG_NAME} ...
	    update_hass
	    echo Starting ${QPKG_NAME} ...
        start_daemon
        exit $?
	fi
	;;
	install-mysql)
	if daemon_status; then
	    echo Installing mysql connector ...
	    install_mysql
	    exit $?
	fi
	;;
    status)
        if daemon_status; then
            echo ${QPKG_NAME} is running
            exit 0
        else
            echo ${QPKG_NAME} is not running
            exit 1
        fi
        ;;
    log)
        tail -f ${LOG_FILE}
        exit 0
        ;;
    *)
        echo "Usage: $N {start|stop|restart|update|install-mysql|log|status}" >&2
        exit 1
    ;;
esac
