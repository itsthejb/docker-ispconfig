#!/usr/bin/env bats

export CONTAINER="ispconfig"
export TIMEOUT=1
if [ -n "CI" ]; then TIMEOUT=30; fi

function testPort() {
  nc -vz -w $TIMEOUT $CONTAINER $1
}

setup() {
  function installDependencies() {
    apk update && apk add openssl netcat-openbsd mariadb-client
  }
  function waitForUp() {
    testPort 80
  }
  installDependencies &> /dev/null
  waitForUp
}

@test "Verify Container startup" {
  ! docker logs $CONTAINER | egrep '(FATAL)|(exited)'
}

@test "Verify Web server" {
  testPort 80
  testPort 443
  ! testport 8080
}

@test "Verify Mail server" {
  testPort 110
  testPort 995
  testPort 143
  testPort 993
  testPort 25
  testPort 465
  testPort 587
}

@test "Verify Database" {
  run bash -c "docker exec $CONTAINER mysql -uroot -p$MYSQL_PW"
}

@test "Verify SSH server" {
  ! testPort 2222
}

@test "Verify FTP server" {
  testPort 21
  ! testPort 20
}
