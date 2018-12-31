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

@test "dovecot requires secure login" {
  run nc -q1 $CONTAINER 25 <<< "EHLO $HOSTNAME"
  [ ! $(echo "$output" | grep "250-AUTH PLAIN LOGIN") ]
  [ ! $(echo "$output" | grep "250-AUTH=PLAIN LOGIN") ]
  run openSSL -connect $CONTAINER:143 -starttls imap
  [ ! $(echo "$output" | grep "AUTH=login") ]
  [ ! $(echo "$output" | grep "AUTH=plain") ]
  run openSSL -connect $CONTAINER:993
  [ ! $(echo "$output" | grep "AUTH=login") ]
  [ ! $(echo "$output" | grep "AUTH=plain") ]
}

@test "roundcube uses secure connection" {
  run docker exec $CONTAINER cat /opt/roundcube/config/config.inc.php
  [ $(echo "$output" | grep "\$config\['default_host'\] = 'ssl://$HOSTNAME_EMAIL:993';") ]
  [ $(echo "$output" | grep "\$config\['smtp_server'\] = 'tls://$HOSTNAME_EMAIL';") ]
  [ $(echo "$output" | grep "\$config\['smtp_port'\] = 587;") ]
  docker exec $CONTAINER egrep -R "^disable_plaintext_auth = yes" "/etc/dovecot"
  docker exec $CONTAINER egrep -R "^disable_plaintext_auth = yes" "/etc/dovecot/conf.d/10-auth.conf"
  run docker exec $CONTAINER tail -n 3 "/etc/dovecot/dovecot.conf"
  [ $(echo "$output" | grep "local 172.0.0.0/8") ]
  [ $(echo "$output" | egrep "^  disable_plaintext_auth = no") ]
}
