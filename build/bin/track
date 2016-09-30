#!/bin/bash

if [ "$1" = "init" ] ; then
echo "dfasf"
  cd /
  rm -rf .git
  git init
  git add --all
  git commit -m "docker-compose track : initial checkin" >/dev/null 
  exit 0
fi

if [ "$1" = "show" ] ; then
  cd /
  git status
  exit 0
fi

if [ "$1" = "git" ] ; then
  cd /
  shift
  git $*
  exit 0
fi
