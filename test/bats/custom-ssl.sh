#!/usr/bin/env bats

load helpers

setup() {
  installDependencies
  waitForUp
}

function testSSL() {
  run openssl s_client -showcerts -connect $CONTAINER:$1 $2 2> /dev/null
  [ $(echo "$output" | grep subject | grep "CN=$HOSTNAME") ]
  [ $(echo "$output" | grep issuer | grep "CN=certauthority.com") ]
}

@test "apache uses custom ssl certificate" {
  testSSL 443
}

@test "ispconfig uses custom ssl certificate" {
  testSSL 8080
}

@test "postfix uses custom ssl certificate" {
  testSSL 587 "-starttls smtp"
}

@test "dovecot uses custom ssl certificate" {
  run openssl s_client -showcerts -connect $CONTAINER:993 $2 2> /dev/null
  [ $(echo "$output" | grep subject | grep "CN=myhost.$HOSTNAME") ]
}
