#!/bin/bash
echo "#################################################"
echo "# starting container boot up script (start.sh)  #"
echo "#################################################"

list=$(ls -1 /etc/supervisor/boot.d/*)
for i in $list ; do
  echo "execute : <$i>"
  $i
done

if [ -n "$MYSQL_HOST" ]; then
  echo "#################################################"
  echo "# mysql host reconfigure"
  echo "#"
  /usr/local/bin/config mysql_host "${MYSQL_HOST}"
fi

if [ -n "$ROUNDCUBE_DB_PASSWORD" ]; then
  echo "#################################################"
  echo "# roundcube configuration stored database password reconfigure"
  echo "#"
  /usr/local/bin/config roundcube_password "${ROUNDCUBE_DB_PASSWORD}"
fi

echo "#################################################"
echo "# check for disabled services"
echo "#"

for task in $DISABLED_SERVICES ; do
  echo "disable : $task"
  sed -i "s/autostart=true/autostart=false/" /etc/supervisor/services.d/$task
  if [ -e /etc/logrotate.d/$task ] ; then
    rm -v /etc/logrotate.d/$task
  fi
done

echo "#################################################"
echo "# execute init scripts for enabled services"
echo "#"

list=$(ls -1 /etc/supervisor/init.d/*)
for i in $list ; do
  if [ -e $i ] ; then
    task=`basename $i`
     if [ "$(grep 'autostart=false' /etc/supervisor/services.d/${task})" = "" ] ; then
       echo "execute: <$task>"
       $i
     fi
  fi
done

echo "#################################################"
echo "# start supervisord"
echo "#"

trap 'kill -TERM $PID; wait $PID' TERM
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &
PID=$!
wait $PID

echo "#################################################"
echo "# shutdown container"
echo "#"
list=$(ls -1 /etc/supervisor/shutdown.d/*)
for i in $list ; do
  echo "execute: <$i>"
  $i
done

