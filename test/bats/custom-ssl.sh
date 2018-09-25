#!/usr/bin/env bats

load helpers

setup() {
  installDependencies
  waitForUp
}

@test "custom ssl certificate" {
  run openssl s_client -connect $CONTAINER:8080 \
    -cert "$SSL_CERT" \
    -key "$SSL_KEY" \
    -state -debug  
  [ $(echo "$output" | grep subject | grep "CN=$HOSTNAME") ]
  [ $(echo "$output" | grep issuer | grep "CN=certauthority.com") ]
}
