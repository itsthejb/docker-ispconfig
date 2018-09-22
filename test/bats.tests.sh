#!/usr/bin/env bats

export CONTAINER="ispconfig"
export TIMEOUT=30

function waitForPort() {
  timeout -t $TIMEOUT sh -c "until nc -vz $CONTAINER $1; do sleep 0.1; done"
}

function closedPort() {
  ! nc -vz $CONTAINER $1
}

setup() {
  function installDependencies() {
    apk update && apk add openssl netcat-openbsd mariadb-client
  }
  function waitForUp() {
    waitForPort 443
  }
  installDependencies &> /dev/null
  waitForUp
}

@test "Verify Container startup" {
  ! docker logs $CONTAINER | egrep '(FATAL)|(exited)'
}

@test "Verify Web server" {
  waitForPort 80
  waitForPort 443
  waitForPort 8080
}

@test "Verify Mail server" {
  waitForPort 110
  waitForPort 995
  waitForPort 143
  waitForPort 993
  waitForPort 25
  waitForPort 465
  waitForPort 587
}

@test "Verify Database" {
  run bash -c "docker exec $CONTAINER mysql -uroot -p$MYSQL_PW"
}

@test "Verify SSH server" {
  closedPort 2222
}

@test "Verify FTP server" {
  waitForPort 21
  closedPort 20
}
