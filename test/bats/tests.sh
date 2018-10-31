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

@test "expected supervisor services running" {
  run docker exec $CONTAINER supervisorctl status
  for SERVICE in amavis apache2 clamav-daemon cron dovecot fail2ban mysql php-fpm postfix postgrey pure-ftpd-mysql rsyslog spamassassin ssh; do
    echo "$output" | grep "RUNNING" | grep "$SERVICE"
  done
}

@test "expected supervisor services are disabled" {
  run docker exec $CONTAINER supervisorctl status
  for SERVICE in bind9 mailman; do
    echo "$output" | grep "STOPPED" | grep "$SERVICE"
  done
}

@test "web server ports are responding" {
  testPortsApache
}

@test "mysql port is responding" {
  waitForPort 3306
}

@test "ispconfig uses build hostname" {
  docker exec $CONTAINER mysql -uroot -p$MYSQL_PW -e "SELECT * from dbispconfig.server" | grep "hostname=myhost.test.com"
}

@test "supplementary vhost is enabled" {
  run docker exec $CONTAINER apache2ctl -S
  [ $(echo "$output" | grep "webmail.test.com") ]
}

@test "default config should be disabled" {
  run docker exec $CONTAINER apache2ctl -S
  [ ! $(echo "$output" | grep "\/etc\/apache2\/sites-enabled\/000-default.conf") ]
}

@test "all selected apache mods should be loaded" {
  run docker exec $CONTAINER apache2ctl -M 2> /dev/null || true
  [ $(echo "$output" | grep -E "macro|proxy_balancer|proxy_http" | wc -l) -eq 3 ]
}

@test "mail server ports are responding" {
  testPortsMail
}

@test "database can be accessed using expected password" {
  docker exec $CONTAINER mysql -uroot -p$MYSQL_PW
}

@test "ssh server port is responding" {
  testPortsSSH
}

@test "FTP ports are responding" {
  testPortsFTP
}

@test "stored roundcube password is correctly changed" {
  run docker exec ispconfig grep "\$config\['db_dsnw'\] = 'mysql://roundcube:reconfigured@localhost/roundcube';" /opt/roundcube/config/config.inc.php
}

@test "cron jobs are running" {
  run docker exec $CONTAINER grep "(*system*) NUMBER OF HARD LINKS > 1" /var/log/syslog
  [ "$status" -eq 1 ]
  run docker exec $CONTAINER cat /var/log/ispconfig/cron.log
  [ -z $(echo "$output" | grep -v "$(date '+%a %b %d')") ]
}
