#!/bin/bash

if [ ! -e ./.do.cfg ] ; then
  echo "DO_CNAME=ispc" > ./.do.cfg
fi
SERVICEVOL=./volumes/service
. ./.do.cfg

DCN=$DO_CNAME


if [ "$1" = "" ] ; then
  echo "usage: `basename $0` <command>"
  echo "          build ............... build image"
  echo "          up .................  create container from image"
  echo "          rm .................  create container from image"
  echo "          start|stop|restart... start/stop the container"
  echo "          console ............. attach to the container output  (detach with CRTL-C)"
  echo "          supervisor .......... connect to supervisord (help|quit|start|stop|restart)"
  echo "          run [command] ....... run a command within the conatainer."
  echo "          log ................. show last lines from console"
  echo "          syslog .............. show last lines from syslog"
  echo "          maillog ............. show last lines from mail.log"
  echo "          ispc config ......... configure ispconfig (set server_name, passwords ...)"
  echo "          ispc mig ............ migration tool (import and export data)"
  echo "          ovw push ............ push the content of <${SERVICEVOL}/ovw/> to the containers </>."
  echo "          ovw fetch ........... copy a file or directory from the containers </> in to <${SERVICEVOL}/ovw/>"
  echo "          ovw diff <file> ..... compare a overwrite file"
  echo "          ovw backup .......... backup the local overwrites in <./backup/"
  echo "          ovw restore .....,... restore the local overwrites in <${SERVICEVOL}/ovw>"
  echo "          track init .......... initialize tracking for  /etc and /usr/local/ispconfig."
  echo "          track show .......... show tracking results"
  echo "          track git <...> ..... git commands"
  exit 0
fi

if [ "$1" = "up" ] ; then
  docker-compose up -d
fi

if [ "$1" = "rm" ] ; then
  docker-compose rm -f
fi

if [ "$1" = "start" -o "$1" = "stop" -o "$1" = "restart" -o "$1" = "build" ] ; then
  docker-compose  $1
  exit 0
fi

if [ "$1" = "console" ] ; then
  docker-compose logs -f
fi


if [ "$1" = "supervisor" ] ; then
  docker exec -it $DCN supervisorctl
  exit 0
fi

if [ "$1" = "log" ] ; then
  docker-compose logs
  exit 0
fi

if [ "$1" = "syslog" ] ; then
  docker exec -it $DCN tail -n 200 /var/log/syslog
  exit 0
fi

if [ "$1" = "maillog" ] ; then
  docker exec -it $DCN tail -n 200 /var/log/mail.log
  exit 0
fi
if [ "$1" = "run" ] ; then
  shift
  if [ "$1" = "" ] ; then
    CMD="bash"
  else
    CMD=$*
  fi
  docker exec -it $DCN $CMD
fi

if [ "$1" = "ispc" ] ; then
  FI=$1
  shift
  docker exec -it $DCN /usr/local/bin/$FI $*
fi



if [ "$1" = "ovw" ] ; then

  if [ "$2" = "push" ] ; then
    docker exec  -it $DCN rsync -av /service/ovw/ /
    exit 0
  fi
  if [ "$2" = "fetch" ] ; then
    if [ "$3" = "" ] ; then
      echo "parameter error: no dir/file given (see usage)"
      exit 0
    fi
    echo "rsync -avR ${3} /service/ovw/"
    docker exec  -it $DCN rsync -avR ${3} /service/ovw/
    exit 0
  fi

  if [ "$2" = "fetch" ] ; then
    docker exec -it $DCN diff /service/ovw/${3} ${3}
    exit 0
  fi

  if [ "$2" = "backup" ] ; then
    mkdir -p backup
    sudo tar -cjvf ./backup/$DCN-ovw.tar.bz2 -C ${SERVICEVOL}/ovw .
    exit 0
  fi
  if [ "$2" = "restore" ] ; then
    rm -Rvf ./service/ovw/*
    sudo tar -C ${SERVICEVOL}/ovw -xjvf ./backup/$DCN-ovw.tar.bz2
    exit 0
  fi
  exit 0
fi

if [ "$1" = "track" ] ; then
    shift 
    docker exec -it $DCN /usr/local/bin/track.sh $* 
fi
