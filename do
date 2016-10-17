#!/bin/bash

CFG=./.do.cfg
DMC=./.do-machine.cfg

if [ ! -e $CFG ] ; then
  echo "DO_CNAME=ispc" >  $CFG
  echo "DO_MNAME="     >> $CFG
fi

SERVICEVOL=./service
. $CFG

DCN=$DO_CNAME

if [ -f $DMC ] ; then
 . $DMC
fi


if [ "$1" = "" ] ; then
  echo "usage: `basename $0` <command>"
  echo "          setup <container-name> [<machine-name>]"
  echo "          build ............... build image"
  echo "          up .................  create <$DCN> from image"
  echo "          rm .................  remove <$DCN>"
  echo "          start|stop|restart... start/stop <$DCN>"
  echo "          console ............. attach to <$DCN> output  (detach with CRTL-C)"
  echo "          supervisor .......... connect to supervisord (help|quit|start|stop|restart)"
  echo "          login [command] ..... login or run a command within <$DCN>."
  echo "          log ................. show last lines from console"
  echo "          syslog .............. show last lines from syslog"
  echo "          maillog ............. show last lines from mail.log"
  echo "          config .............. configure ispconfig (set server_name, passwords ...)"
  echo "          migrate ............. migration tool (import and export data)"
  echo "          ovw push ............ push the content of </service/ovw> to </> within the container."
  echo "          ovw fetch ........... copy a file or directory from </> to </service/ovw/> within the container."
  echo "          ovw diff <file> ..... compare a overwrite file"
  echo "          service pull [real] . pull content of remote service folder and store it local <./service>."
  echo "          service push [real] . push content from local <./service> to the remote service folder."
  echo "          service backup ...... backup service volume to <./backup/>"
  echo "          service restore ..... restore service volume from <./backup/>"
  echo "          track init .......... initialize file tracking for /etc and /usr/local/ispconfig."
  echo "          track show .......... show file tracking results"
  echo "          track git <...> ..... git commands"
  echo "          cp <src> <target> ... copy between host and container"
  exit 0
fi

if [ ! -d ./build ] ; then
  mkdir -p ./build
fi


if [ "$1" = "setup" ] ; then
  if [ "$2" = "" ] ; then
     echo "settings:"
     cat $CFG
     if [ -e $DMC ] ; then
       cat $DMC
     fi
     exit 0
  else
    sed -i -e "s/^DO_CNAME=.*/DO_CNAME=$2/"       $CFG
  fi
  . $CFG
  if [ "$3" != "" ] ; then
    sed -i -e "s/^DO_MNAME=.*/DO_MNAME=$3/"       $CFG
    docker-machine env $3
    docker-machine env $3 > $DMC
    . $DMC
  fi
fi

if [ "$1" = "ps" ] ; then
  docker-compose ps
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
if [ "$1" = "login" ] ; then
  shift
  if [ "$1" = "" ] ; then
    CMD="bash"
  else
    CMD=$*
  fi
  docker exec -it $DCN $CMD
fi

if [ "$1" = "config" -o "$1" = "migrate" -o "$1" = "track" ] ; then
  FI=$1
  shift
  docker exec -it $DCN /usr/local/bin/${FI} $*
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
fi
if [ "$1" = "service" ] ; then
  DRY=" --dry-run "
  if [ "$3" = "real" ] ; then
    DRY=""
  fi
  if [ "$2" = "push" ] ; then
     ssh root@$(docker-machine ip $DO_MNAME) mkdir -p /Docker/service 
     sudo rsync  ${DRY} -avzS --numeric-ids --delete -e ssh ${SERVICEVOL}/ root@$(docker-machine ip $DO_MNAME):/Docker/$DO_CNAME/service 
     echo "push $DRY folder from <${SERVICEVOL}> to <$(docker-machine ip $DO_MNAME):/Docker/$DO_CNAME>"
  fi
  if [ "$2" = "pull" ] ; then
    sudo rsync   ${DRY} -avzS --numeric-ids --delete -e ssh root@$(docker-machine ip $DO_MNAME):/Docker/$DO_CNAME/service/ ${SERVICEVOL} 
    echo "pull $DRY folder from <$(docker-machine ip $DO_MNAME):/Docker/$DO_CNAME> to <${SERVICEVOL}> done." 
  fi

  if [ "$2" = "backup" ] ; then
    mkdir -p backup
    sudo tar -cjvf ./backup/$DCN.tar.bz2 -C ${SERVICEVOL} .
    echo "backup stored as <./backup/$DCN.tar.bz2>"
    exit 0
  fi
  if [ "$2" = "restore" ] ; then
    rm -Rvf ./service/ovw/*
    sudo tar -C ${SERVICEVOL} -xjvf ./backup/$DCN.tar.bz2
    exit 0
  fi
fi

if [ "$1" = "cp" ] ; then
    docker cp $2 $3
    exit 0
fi
if [ "$1" = "encrypt" ] ; then
    mkdir -p ./utils
    tar cjv ./private | openssl aes-256-cbc -salt -out ./utils/.private.enc
    rm -Rvf ./private
    exit 0
fi
if [ "$1" = "decrypt" ] ; then
    openssl aes-256-cbc -d -salt -in ./utils/.private.enc | tar xjv
    exit 0
fi

