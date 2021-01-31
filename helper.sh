#!/bin/bash

check()
{
  list="110 995 143 993 25 465 587 20 21 80 443 8080 2222"
  for i in $list ; do
    netcat -vz 127.0.0.1 "$i" >/dev/null 2>&1
    ret=$?
    echo "checking port: <$i> $ret"
  done
}




if [ "$1" = "" ] ; then
  echo " usage: $(basename "$0") check|build|config|rerun|permissions" 
  exit 0
fi

if [ "$1" = "check" ] ; then
  check
  exit 0
fi



if [ "$1" = "build" ] ; then
  sudo /etc/init.d/vmware-workstation-server stop
  sudo rm -Rvf ./volumes
  cp -v ./docker-compose.yml-template ./docker-compose.yml
  ./do stop
  ./do rm
  ./do build
  ./do up
  sleep 3
  ./do log
  check
fi

if [ "$1" = "config" ] ; then
  ./do track init                                     # initialize tracking for  /etc and /usr/local/ispconfig
  ./do config mysql_root_pw  test                     # change mysql root password to test
  ./do config server_name  myhost.test.com            # set server name in ispconfig database
  ./do restart ; sleep 3 ; ./do log                   # restart ispconfig
  ./do track show                                     # show ispconfig file modifications
  ./helper.sh check
fi

if [ "$1" = "rerun" ] ; then
  ./do migrate export
  ./do stop
  ./do rm
  ./do up
  sleep 3
  ./do log
  ./do migrate import
  ./do restart
  sleep 3
  ./do log
  ./helper.sh check
  exit 0
fi

if [ "$1" = "rebuild" ] ; then
  ./do migrate export
  ./do stop ; ./do rm
  ./do build
  ./do up ; sleep 3 ; ./do log
  ./do migrate import
  ./do restart ; sleep 3 ; ./do log
    ./helper.sh check
  exit 0
fi

if [ "$1" = "permissions" ] ; then
  echo " - postfix"

  function postfixSetPermissions() {
    /usr/sbin/postfix set-permissions 2>&1 | grep "No such file or directory" | cut -d"'" -f2
  }

  OUT=$(postfixSetPermissions)
  while [ $? -eq 1 ]; do 
    touch "$OUT"
    OUT=$(postfixSetPermissions)
  done

  service postfix stop
  postfixSetPermissions
  postfix check
  service postfix start
fi
