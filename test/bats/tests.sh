#!/usr/bin/env bats

load helpers

setup() {
  installDependencies &> /dev/null
  apk add mariadb-client
  waitForUp
}

@test "no errors on container startup" {
  ! docker logs $CONTAINER | egrep '(FATAL)|(exited)'
}

@test "web server ports are responding" {
  waitForPort 80
  waitForPort 443
  waitForPort 8080
}

@test "supplementary vhost is enabled" {
  run docker exec $CONTAINER apache2ctl -S
  [ $(echo "$output" | grep "webmail.test.com") ]
}

@test "all selected apache mods should be loaded" {
  run docker exec $CONTAINER apache2ctl -M 2> /dev/null || true
  [ $(echo "$output" | grep -E "macro|proxy_balancer|proxy_http" | wc -l) -eq 3 ]
}

@test "mail server ports are responding" {
  waitForPort 110
  waitForPort 995
  waitForPort 143
  waitForPort 993
  waitForPort 25
  waitForPort 465
  waitForPort 587
}

@test "database can be accessed using expected password" {
  run docker exec $CONTAINER mysql -uroot -p$MYSQL_PW
}

@test "ssh server port is responding" {
  waitForPort 22
}

@test "FTP ports are responding" {
  waitForPort 21
  closedPort 20
}

@test "stored roundcube password is correctly changed" {
  run docker exec ispconfig grep "\$config\['db_dsnw'\] = 'mysql://roundcube:reconfigured@localhost/roundcube';" /opt/roundcube/config/config.inc.php
}
