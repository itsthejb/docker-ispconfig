#!/usr/bin/env bats

load helpers

setup() {
  installDependencies
  waitForUp
}

@test "ispconfig uses custom ssl certificate" {
  run openssl s_client -connect $CONTAINER:8080 \
    -cert "$SSL_CERT" \
    -key "$SSL_KEY" \
    -state -debug  
  [ $(echo "$output" | grep subject | grep "CN=$HOSTNAME") ]
  [ $(echo "$output" | grep issuer | grep "CN=certauthority.com") ]
}

@test "postfix uses custom ssl certificate" {
  run openssl s_client -connect $CONTAINER:587 \
    -starttls smtp \
    -cert "$SSL_CHAIN" \
    -key "$SSL_KEY" \
    -state -debug
  [ $(echo "$output" | grep subject | grep "CN=$HOSTNAME") ]
  [ $(echo "$output" | grep issuer | grep "CN=certauthority.com") ]
}

@test "dovecot uses custom ssl certificate" {
  run openssl s_client -connect $CONTAINER:993 \
    -cert "$SSL_CHAIN" \
    -key "$SSL_KEY" \
    -state -debug
  [ $(echo "$output" | grep subject | grep "CN=myhost.$HOSTNAME") ]
  [ $(echo "$output" | grep issuer | grep "CN=myhost.$HOSTNAME") ]
}
