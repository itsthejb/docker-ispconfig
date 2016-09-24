#!/bin/bash

run()
{
  cmd="$*"
  echo "RUN: <$cmd>"
  $cmd
}

if [ "$1" = "" ] ; then
  echo " usage: `basename $0` reset" 
  exit 0
fi
if [ "$1" = "reset" ] ; then

./do ispc mig export
./do stop
docker-compose rm -f
sudo rm -Rvf volume/mysql volume/ispconfig/ volume/etc/
./do up
./do track init
sleep 3
./do log
./do ispc mig import
./do restart
./do log
./do track show
#  run "docker-compose build"
#  run "docker-compose stop ; docker-compose rm -f"
#  run "docker-compose up -d"
#  run "sleep 5"
#  run "./do track init >/dev/null"
#  run "docker-compose logs -f"
  exit 0
fi

