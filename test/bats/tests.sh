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
  for SERVICE in apache2 clamav-daemon cron dovecot fail2ban mysql php-fpm postfix postgrey pure-ftpd-mysql redis rspamd rsyslog spamassassin ssh; do
    echo "$output" | grep "RUNNING" | grep "$SERVICE"
  done
}

@test "expected supervisor services are disabled" {
  run docker exec $CONTAINER supervisorctl status
  for SERVICE in unbound; do
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

@test "default rspamd web interface is accessible" {
  skip
  docker exec "$CONTAINER" apt-get -y install curl
  docker exec "$CONTAINER" curl -s "http://localhost:11334"
}

@test "stored roundcube password is correctly changed" {
  run docker exec "$CONTAINER" grep "\$config\['db_dsnw'\] = 'mysql://roundcube:reconfigured@localhost/roundcube';" /opt/roundcube/config/config.inc.php
}

@test "cron jobs are running" {
  run docker exec $CONTAINER grep "(*system*) NUMBER OF HARD LINKS > 1" /var/log/syslog
  [ "$status" -eq 1 ]
}

@test "cron log should contain no errors, only timestamped info" {
  run docker exec $CONTAINER cat /var/log/ispconfig/cron.log
  [ ! $(echo "$output" | grep -Ev "^\w+ \w+ \d+ \d+:\d+:\d+ \w+ \d{4}") ]
}

@test "root crontab is as expected" {
  run docker exec $CONTAINER cat /var/spool/cron/crontabs/root
  echo "$output"
  [ $(echo "$output" | grep -E "@daily.*/usr/bin/freshclam") ]
  [ $(echo "$output" | grep "* * * * * /usr/local/ispconfig/server/server.sh") ]
  [ $(echo "$output" | grep "* * * * * /usr/local/ispconfig/server/cron.sh") ]
  [ $(echo "$output" | grep "MAILTO=to@mail.com") ]
  [ $(echo "$output" | grep "MAILFROM=from@mail.com") ]
}

@test "locale is correctly configured" {
  run docker exec "$CONTAINER" locale
  echo "$output"
  [ "$(echo "$output" | grep "en" | wc -l)" -eq 15 ]
  [ "$(echo "$output" | grep "en_US.UTF-8" | wc -l)" -eq 14 ]
  [ "$(echo "$output" | grep -v "en" | wc -l)" -eq 0 ]
}
