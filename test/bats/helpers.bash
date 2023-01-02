#!/usr/bin/env bats

export CONTAINER="ispconfig-test"
export TIMEOUT=10

function grepInvert() {
  ! grep "$@"
}

function waitForPort() {
  timeout $TIMEOUT sh -c "until nc -vz $CONTAINER $1; do sleep 0.1; done"
}

function closedPort() {
  ! nc -vz "$CONTAINER" "$1"
}

function setupDependencies() {
  bats_require_minimum_version 1.5.0
  apk update
  apk add docker openssl netcat-openbsd &> /dev/null
}

function waitForUp() {
  waitForPort 443
}

function testPortsApache() {
  waitForPort 80
  waitForPort 443
  waitForPort 8080
}

function testPortsMail() {
  waitForPort 25
  waitForPort 110
  waitForPort 143
  waitForPort 465
  waitForPort 587
  waitForPort 993
  waitForPort 995
}

function testPortsSSH() {
  waitForPort 22
}

function testPortsFTP() {
  waitForPort 21
  closedPort 20
}

function testAllPorts() {
  testPortsApache
  testPortsMail
  testPortsSSH
  testPortsFTP
}