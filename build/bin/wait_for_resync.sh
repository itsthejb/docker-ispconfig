#!/bin/bash

MYSQL_ROOT_PW=$(grep "clientdb_password" /usr/local/ispconfig/server/lib/mysql_clientdb.conf | awk -F\' '{ print $2 }')



/etc/init.d/cron stop > /dev/null 2>&1
/usr/local/ispconfig/server/server.sh >/dev/null 2>&1
echo ""
echo "Login to the IPSConfig panel, go to Settings->Resync, enable all servieses and confirm it."
echo ""
echo -n "Waiting for resync .."
while true ; do
  sleep 5
  echo -n "."
  xxx=$(mysql -s -uroot -p"${MYSQL_ROOT_PW}" -e "select updated from dbispconfig.server ; ")
  anz=$(mysql -s -uroot -p"${MYSQL_ROOT_PW}" -e "select count(status) from dbispconfig.sys_datalog where  datalog_id > $xxx ; ")
  if [ "$anz" != 0 ] ; then
     echo ""
     echo "Changes detected. Wait 10s before starting server.sh."
     echo ""
     sleep 10
     /usr/local/ispconfig/server/server.sh
     break ;
  fi
done
/etc/init.d/cron start
echo ""
echo "Resync changes applied."
echo ""
