#!/usr/bin/env bats

load helpers

setup() {
  installDependencies
  waitForUp
}

@test "all ports responding" {
  testAllPorts
}

@test "ISPConfig at expected HTTP URL" {
  curl -sL "http://ispconfig:8080" | grep "<title>ISPConfig</title>"
}

@test "phpMyAdmin at expected HTTP URL" {
  curl -sL "http://ispconfig:8080/phpmyadmin" | grep "<title>phpMyAdmin</title>"
}

@test "ISPConfig at expected HTTP URL" {
  curl -sL "http://ispconfig:8080/webmail" | grep "<title>Roundcube Webmail :: Welcome to Roundcube Webmail</title>"
}
