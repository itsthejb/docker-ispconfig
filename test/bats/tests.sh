#!/usr/bin/env bats
# shellcheck disable=SC2317

load helpers

setup() {
  setupDependencies &> /dev/null
  apk add mariadb-client
  waitForUp
}

@test "no errors on container startup" {
  docker logs "$CONTAINER" | grepInvert -Ei '(error)|(fatal)'
}

@test "no service errors" {
  docker exec "$CONTAINER" supervisorctl status | grepInvert -vE "(RUNNING)|(STOPPED)"
}

@test "expected supervisor services running" {
  run docker exec "$CONTAINER" supervisorctl status
  for SERVICE in apache2 clamav-daemon cron dovecot fail2ban mysql php${BUILD_PHP_VERS}-fpm postfix postgrey pure-ftpd-mysql redis rsyslog spamassassin ssh; do
    echo "$output" | grep "RUNNING" | grep "$SERVICE"
  done
}

@test "expected supervisor services are disabled" {
  run docker exec "$CONTAINER" supervisorctl status
  SERVICES=(unbound)
  for SERVICE in "${SERVICES[@]}"; do
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
  docker exec "$CONTAINER" mysql -uroot -p"$MYSQL_PW" -e "SELECT * from dbispconfig.server" | grep "hostname=myhost.test.com"
}

@test "supplementary vhost is enabled" {
  run docker exec "$CONTAINER" apache2ctl -S
  echo "$output" | grep "webmail.test.com"
}

@test "default config should be disabled" {
  docker exec "$CONTAINER" apache2ctl -S | grepInvert "\/etc\/apache2\/sites-enabled\/000-default.conf"
}

@test "all selected apache mods should be loaded" {
  run docker exec "$CONTAINER" apache2ctl -M 2> /dev/null || true
  [ "$(echo "$output" | grep -cE "macro|proxy_balancer|proxy_http")" -eq 3 ]
}

@test "mail server ports are responding" {
  testPortsMail
}

@test "database can be accessed using expected password" {
  docker exec "$CONTAINER" mysql -uroot -p"$MYSQL_PW"
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
  run docker exec "$CONTAINER" grep "(*system*) NUMBER OF HARD LINKS > 1" /var/log/syslog
  [ "$status" -eq 1 ]
}

@test "cron log should contain no errors, only timestamped info" {
  run docker exec "$CONTAINER" grep -qEv "^\w+ \w+ \d+ \d+:\d+:\d+ \w+ \d{4}" /var/log/ispconfig/cron.log
}

@test "root crontab is as expected" {
  run docker exec "$CONTAINER" cat /var/spool/cron/crontabs/root
  echo "$output" | grep -qE "@daily.*/usr/bin/freshclam"
  # shellcheck disable=SC2063
  echo "$output" | grep -q "* * * * * /usr/local/ispconfig/server/server.sh"
  # shellcheck disable=SC2063
  echo "$output" | grep -q "* * * * * /usr/local/ispconfig/server/cron.sh"
  echo "$output" | grep -q "MAILTO=to@mail.com"
  echo "$output" | grep -q "MAILFROM=from@mail.com"
}

@test "locale is correctly configured" {
  run docker exec "$CONTAINER" locale
  echo "$output"
  [ "$(echo "$output" | grep -c "C")" -eq 15 ]
  [ "$(echo "$output" | grep -c "C.UTF-8")" -eq 14 ]
  [ "$(echo "$output" | grep -cv "C")" -eq 0 ]
}

@test "expected php versions" {
  FPM_INIT="/etc/supervisor/init.d/php$BUILD_PHP_VERS-fpm"
  FPM_SERVICE="/etc/supervisor/services.d/php$BUILD_PHP_VERS-fpm"
  docker exec "$CONTAINER" php -v | grep "PHP $BUILD_PHP_VERS"
  docker exec "$CONTAINER" test -f "$FPM_INIT"
  docker exec "$CONTAINER" test -f "$FPM_SERVICE"
  docker exec "$CONTAINER" grep "php$BUILD_PHP_VERS-fpm" "$FPM_SERVICE"
  docker exec "$CONTAINER" grep "php-fpm$BUILD_PHP_VERS" "$FPM_SERVICE"
  docker exec "$CONTAINER" test -d "/var/lib/php$BUILD_PHP_VERS-fpm"
  docker exec "$CONTAINER" grep "PHPRC=/etc/php/$BUILD_PHP_VERS/cgi/" /var/www/php-fcgi-scripts/apps/.php-fcgi-starter
}

@test "apache compiled with BIG_SECURITY_HOLE" {
  docker exec "$CONTAINER" apache2ctl -V | grep "\-D BIG_SECURITY_HOLE"
}
