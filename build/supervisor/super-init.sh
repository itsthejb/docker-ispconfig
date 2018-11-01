#!/bin/bash

SVC=`basename $0`

if [ "$1" = "reload" ] ; then
  /usr/bin/supervisorctl stop  ${SVC}
  test -x /etc/supervisor/init.d/${SVC} && /etc/supervisor/init.d/${SVC} 
  /usr/bin/supervisorctl start ${SVC}
elif [ "$1" = "start" ] ; then
  test -x /etc/supervisor/init.d/${SVC} && /etc/supervisor/init.d/${SVC} 
  /usr/bin/supervisorctl $1 ${SVC}
else
  /usr/bin/supervisorctl $1 ${SVC}
fi
