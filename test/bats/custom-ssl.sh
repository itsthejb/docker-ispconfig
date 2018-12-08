#!/usr/bin/env bats

load helpers

setup() {
  installDependencies
  waitForUp
}

function openSSL() {
  echo QUIT | openssl s_client "$@" 2>&1
}

function testSSL() {
  waitForPort $1
  run openSSL -showcerts -connect $CONTAINER:$1 $2
  [ $(echo "$output" | grep subject | grep "CN=$HOSTNAME") ]
  [ $(echo "$output" | grep issuer | grep "CN=certauthority.com") ]
}

@test "apache uses custom ssl certificate" {
  run testSSL 443
}

@test "ispconfig uses custom ssl certificate" {
  run testSSL 8080
}

@test "postfix uses custom ssl certificate" {
  run testSSL 465
  run testSSL 587 "-starttls smtp"
}

@test "dovecot uses custom ssl certificate" {
  run testSSL 110 "-starttls pop3"
  run testSSL 995
  run testSSL 143 "-starttls imap"
  run testSSL 993
}

@test "dovecot has expected imap login" {
  run openSSL -connect $CONTAINER:143 -starttls imap
  [ ! $(echo "$output" | grep "AUTH=login") ]
  [ ! $(echo "$output" | grep "AUTH=plain") ]
  run openSSL -connect $CONTAINER:993
  [ ! $(echo "$output" | grep "AUTH=login") ]
  [ ! $(echo "$output" | grep "AUTH=plain") ]
}

@test "roundcube uses tls" {
  run docker exec ispconfig cat /opt/roundcube/config/config.inc.php
  [ $(echo "$output" | grep "\$config\['default_host'\] = 'tls://$HOSTNAME';") ]
  [ $(echo "$output" | grep "\$config\['smtp_server'\] = 'tls://$HOSTNAME';") ]
  [ $(echo "$output" | grep "\$config\['smtp_port'\] = 587;") ]
}
