#!/usr/bin/env bats

export CONTAINER="ispconfig"
export TIMEOUT=30

function waitForPort() {
  timeout -t $TIMEOUT sh -c "until nc -vz $CONTAINER $1; do sleep 0.1; done"
}

function closedPort() {
  ! nc -vz $CONTAINER $1
}

function installDependencies() {
  apk update && apk add openssl netcat-openbsd &> /dev/null
}

function waitForUp() {
  waitForPort 443
}
