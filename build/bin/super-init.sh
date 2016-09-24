#!/bin/bash

SVC=`basename $0`

if [ "$1" = "reload" ] ; then
  /usr/bin/supervisorctl stop  ${SVC}
  /usr/bin/supervisorctl start ${SVC}
else
  /usr/bin/supervisorctl $1 ${SVC}
fi
