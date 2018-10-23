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
  testPortsApache
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
  testPortsMail
}

@test "database can be accessed using expected password" {
  run docker exec $CONTAINER mysql -uroot -p$MYSQL_PW
}

@test "ssh server port is responding" {
  testPortsSSH
}

@test "FTP ports are responding" {
  testPortsFTP
}

@test "stored roundcube password is correctly changed" {
  run docker exec $CONTAINER grep "\$config\['db_dsnw'\] = 'mysql://roundcube:reconfigured@localhost/roundcube';" /opt/roundcube/config/config.inc.php
}

@test "dkim key is configured" {
  run docker exec $CONTAINER grep "dkim_key('${BUILD_HOSTNAME}', '${BUILD_HOSTNAME}', '/var/dkim/${BUILD_HOSTNAME}.key.pem');" /etc/amavis/conf.d/50-user
}

@test "volume dkim key is used" {
  run docker exec $CONTAINER amavisd-new showkeys
  diff -s "/app/dkim/showkeys.out" <(echo "$output")
}

@test "cron jobs are running" {
  run docker exec $CONTAINER grep "(*system*) NUMBER OF HARD LINKS > 1" /var/log/syslog
  [ $status -eq 1 ]
  run docker exec $CONTAINER cat /var/log/ispconfig/cron.log
  [ -z $(echo "$output" | grep -v "$(date '+%a %b %d')") ]
}
