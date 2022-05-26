#
#                    ##        .
#              ## ## ##       ==
#           ## ## ## ##      ===
#       /""""""""""""""""\___/ ===
#  ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
#       \______ o          __/
#         \    \        __/
#          \____\______/
#
#          |          |
#       __ |  __   __ | _  __   _
#      /  \| /  \ /   |/  / _\ |
#      \__/| \__/ \__ |\_ \__  |
#
# Dockerfile for ISPConfig with MariaDB database
#
# Originally based on:
# https://www.howtoforge.com/perfect-server-debian-10-buster-apache-bind-dovecot-ispconfig-3-1/
# https://www.howtoforge.com/update-the-ispconfig-perfect-server-from-debian-10-to-debian-11/
#
FROM debian:bullseye-slim

LABEL maintainer="mail@jcrooke.net"
LABEL description="ISPConfig 3.2 on Debian Bullseye, with Roundcube mail, phpMyAdmin and more"

# Frequent: versioning
ARG BUILD_ISPCONFIG_VERSION="3.2.8p1"
ARG BUILD_ROUNDCUBE_VERSION="1.5.2"
ARG BUILD_PHPMYADMIN_VERSION="5.2.0"
ENV BUILD_PHP_VERS="7.4"
ARG BUILD_JAILKIT_VERSION="2.23"

# Other arguments
ARG BUILD_CERTBOT="yes"
ARG BUILD_HOSTNAME="myhost.test.com"
ARG BUILD_ISPCONFIG_DROP_EXISTING="no"
ARG BUILD_ISPCONFIG_MYSQL_DATABASE="dbispconfig"
ARG BUILD_ISPCONFIG_PORT="8080"
ARG BUILD_ISPCONFIG_USE_SSL="yes"
ARG BUILD_LOCALE="en_US"
ARG BUILD_MYSQL_HOST="localhost"
ARG BUILD_MYSQL_PW="pass"
ARG BUILD_MYSQL_REMOTE_ACCESS_HOST="172.%.%.%"
ARG BUILD_PHPMYADMIN="yes"
ARG BUILD_PHPMYADMIN_PW="phpmyadmin"
ARG BUILD_PHPMYADMIN_USER="phpmyadmin"
ARG BUILD_PRINTING="no"
ARG BUILD_REDIS="yes"
ARG BUILD_ROUNDCUBE_DB="roundcube"
ARG BUILD_ROUNDCUBE_DIR="/opt/roundcube"
ARG BUILD_ROUNDCUBE_PW="secretpassword"
ARG BUILD_ROUNDCUBE_USER="roundcube"
ARG BUILD_TZ="Europe/London"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# --- set timezone and locale
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get -qq -o Dpkg::Use-Pty=0 update && \
    apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install apt-utils locales && \
    sed -i -e "s/# ${BUILD_LOCALE}.UTF-8 UTF-8/${BUILD_LOCALE}.UTF-8 UTF-8/" /etc/locale.gen && \
    locale-gen; \
    apt-get clean && rm -rf /var/lib/apt/lists/*
ENV LANG "${BUILD_LOCALE}.UTF-8"
ENV LANGUAGE "${BUILD_LOCALE}:en"
ENV LC_ALL "${BUILD_LOCALE}.UTF-8"
RUN apt-get -qq -o Dpkg::Use-Pty=0 update && \
    ln -fs /usr/share/zoneinfo/${BUILD_TZ} /etc/localtime; \
    dpkg-reconfigure -f noninteractive tzdata; \
# --- 1 Preliminary
    apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install cron patch rsyslog rsyslog-relp logrotate supervisor git sendemail wget sudo; \
    ln -s /usr/bin/true /usr/bin/systemctl; \
# Create the log file to be able to run tail
    touch /var/log/cron.log; \
    touch /var/spool/cron/root; \
    crontab /var/spool/cron/root; \
# --- 2 Install the SSH server
    apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install ssh openssh-server; \
# --- 3 Install a shell text editor
    apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install nano vim-nox; \
# --- 6 Change The Default Shell
    printf "dash  dash/sh boolean no\n" | debconf-set-selections; \
    dpkg-reconfigure dash; \
# --- 7 Synchronize the System Clock
    apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install ntp ntpdate; \
# --- 8a Install MySQL (optional)
    apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install mariadb-client; \
    if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then \
        printf "mariadb-server mariadb-server/root_password password %s\n" "${BUILD_MYSQL_PW}"       | debconf-set-selections; \
        printf "mariadb-server mariadb-server/root_password_again password %s\n" "${BUILD_MYSQL_PW}" | debconf-set-selections; \
        apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install mariadb-server; \
    fi; \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY ./build/etc/mysql/debian.cnf /etc/mysql
COPY ./build/etc/mysql/50-server.cnf /etc/mysql/mariadb.conf.d/
RUN if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then \
        sed -i "s|password =|password = ${BUILD_MYSQL_PW}|" /etc/mysql/debian.cnf; \
        printf "mysql soft nofile 65535\nmysql hard nofile 65535\n" >> /etc/security/limits.conf; \
        mkdir -p /etc/systemd/system/mysql.service.d/; \
        printf "[Service]\nLimitNOFILE=infinity\n" >> /etc/systemd/system/mysql.service.d/limits.conf; \
        service mariadb restart; \
        printf "SET PASSWORD = PASSWORD('%s');\n" "${BUILD_MYSQL_PW}" | mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW}; \
    elif ! mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW}; then \
        printf "\e[31mConnection to mysql host \"%s\" with password \"%s\" failed!\e[0m\n" "${BUILD_MYSQL_HOST}" "${BUILD_MYSQL_PW}"; \
        exit 1; \
    fi; \
# --- 8b Install Postfix, Dovecot, and Binutils
    apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install postfix postfix-mysql postfix-doc getmail rkhunter binutils dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd libsasl2-modules; \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY ./build/etc/postfix/master.cf /etc/postfix/master.cf

RUN service postfix restart; \
    if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then service mariadb restart; fi; \
# --- 9 Install SpamAssassin, and ClamAV
    (crontab -l; printf "\n") | sort - | uniq - | crontab -; \
    apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install spamassassin clamav sa-compile clamav-daemon unzip bzip2 arj nomarch lzop gnupg2 cabextract p7zip p7zip-full unrar-free lrzip apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl libdbd-mysql-perl postgrey; \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY ./build/etc/clamav/clamd.conf /etc/clamav/clamd.conf
RUN (crontab -l; printf "@daily    /usr/bin/freshclam\n") | sort - | uniq - | crontab -; \
    freshclam; \
    sa-update 2>&1; \
    sa-compile --quiet 2>&1; \
# --- 10 Install Apache Web Server and PHP
    if [ ${BUILD_MYSQL_HOST} = "localhost" ]; then service mariadb restart; fi; \
    apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install apache2 apache2-doc apache2-utils libapache2-mod-php php-yaml php-cgi libapache2-mod-fcgid apache2-suexec-pristine php-pear mcrypt imagemagick libruby libapache2-mod-python memcached libapache2-mod-passenger php php-common php-gd php-mysql php-imap php-cli php-cgi php-curl php-intl php-pspell php-sqlite3 php-tidy php-imagick php-xmlrpc php-xsl php-zip php-mbstring php-soap php-fpm php-opcache php-json php-readline php-xml curl; \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    /usr/sbin/a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi headers actions proxy_fcgi alias
COPY ./build/etc/apache2/httpoxy.conf /etc/apache2/conf-available/
RUN apt-get -qq -o Dpkg::Use-Pty=0 update; \
    printf "ServerName %s\n" "${BUILD_HOSTNAME}" > /etc/apache2/conf-available/fqdn.conf; \
	/usr/sbin/a2enconf fqdn; \
    /usr/sbin/a2enconf httpoxy; \
# --- 11 Free SSL RUN mkdir /opt/certbot
    if [ ${BUILD_CERTBOT} = "yes" ]; then apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install certbot; fi; \
# --- PHP-FPM
    /usr/sbin/a2enmod actions proxy_fcgi alias setenvif; \
    /usr/sbin/a2enconf php-fpm; \
    service apache2 restart; \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY ./build/etc/aliases /etc/aliases
RUN newaliases; \
    service postfix restart; \
# --- 13 Install PureFTPd
    apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install pure-ftpd-common pure-ftpd-mysql; \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    openssl dhparam -out /etc/ssl/private/pure-ftpd-dhparams.pem 2048 2>&1; \
    groupadd ftpgroup; \
    useradd -g ftpgroup -d /dev/null -s /etc ftpuser
COPY ./build/etc/default/pure-ftpd-common /etc/default/pure-ftpd-common

# --- 14 Install BIND DNS Server
RUN apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install lsb-release unbound dnsutils haveged; \
    printf "do-ip6: no\n" > /etc/unbound/unbound.conf.d/no-ip6v.conf; \
    if [ $BUILD_REDIS = "yes" ]; then \
        apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install redis-server; \
        sed -i "s|daemonize yes|daemonize no|" /etc/redis/redis.conf; \
    fi; \
    wget -q -O- https://rspamd.com/apt-stable/gpg.key | apt-key add - 2>&1; \
    printf "deb [arch=amd64] http://rspamd.com/apt-stable/ %s main\n" "$(lsb_release -c -s)" > /etc/apt/sources.list.d/rspamd.list; \
    printf "deb-src [arch=amd64] http://rspamd.com/apt-stable/ %s main\n" "$(lsb_release -c -s)" >> /etc/apt/sources.list.d/rspamd.list; \
    apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install rspamd; \
    printf "servers = \"localhost\";\n" > /etc/rspamd/local.d/redis.conf; \
    printf "nrows = 2500;\n" > /etc/rspamd/local.d/history_redis.conf; \
    printf "compress = true;\n" >> /etc/rspamd/local.d/history_redis.conf; \
    printf "subject_privacy = false;\n" >> /etc/rspamd/local.d/history_redis.conf; \
    sed -i 's|-f /bin/systemctl|-d /run/systemd/system|' /etc/logrotate.d/rspamd; \
# --- 15 Install Webalizer and AWStats
    apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install webalizer awstats geoip-database libclass-dbi-mysql-perl libtimedate-perl; \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY ./build/etc/cron.d/awstats /etc/cron.d/

# --- 16 Install Jailkit
# install package building helpers
RUN apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install build-essential autoconf automake libtool flex bison debhelper binutils python-minimal; \
    wget "http://olivier.sessink.nl/jailkit/jailkit-$BUILD_JAILKIT_VERSION.tar.gz" -q -P /tmp; \
    tar xfz "/tmp/jailkit-${BUILD_JAILKIT_VERSION}.tar.gz" -C /tmp; \
    apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/jailkit-${BUILD_JAILKIT_VERSION}
RUN printf "5\n" > debian/compat; \
    make -s -f debian/rules binary 2>&1; \
    dpkg -i /tmp/jailkit_${BUILD_JAILKIT_VERSION}-1_*.deb; \
    rm -rf /tmp/jailkit-${BUILD_JAILKIT_VERSION}*; \
# --- 17 Install fail2ban and UFW Firewall
    touch /var/log/auth.log; \
    touch /var/log/mail.log; \
    touch /var/log/syslog; \
    apt-get -qq -o Dpkg::Use-Pty=0 update && apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install fail2ban ufw; \
    apt-get clean && rm -rf /var/lib/apt/lists/*;
COPY ./build/etc/fail2ban/jail.local /etc/fail2ban/jail.local
COPY ./build/etc/phpmyadmin/config.inc.php /tmp/phpmyadmin.config.inc.php
COPY ./build/etc/apache2/phpmyadmin.conf /etc/apache2/conf-available/phpmyadmin.conf
# --- 18 Install PHPMyAdmin Database Administration Tool
# https://www.linuxbabe.com/debian/install-phpmyadmin-apache-lamp-debian-10-buster
RUN service fail2ban restart; \
    apt-get -qq -o Dpkg::Use-Pty=0 update; \
    if [ ${BUILD_PHPMYADMIN} = "yes" ]; then \
        if [ ${BUILD_MYSQL_HOST} = "localhost" ]; then \
            wget "https://files.phpmyadmin.net/phpMyAdmin/${BUILD_PHPMYADMIN_VERSION}/phpMyAdmin-${BUILD_PHPMYADMIN_VERSION}-all-languages.zip" -q -O "/tmp/phpMyAdmin-${BUILD_PHPMYADMIN_VERSION}-all-languages.zip"; \
            unzip -q "/tmp/phpMyAdmin-${BUILD_PHPMYADMIN_VERSION}-all-languages.zip" -d /usr/share/; \
            mv "/usr/share/phpMyAdmin-${BUILD_PHPMYADMIN_VERSION}-all-languages" /usr/share/phpmyadmin; \
            chown -R www-data:www-data /usr/share/phpmyadmin; \
            service mariadb restart; \
            mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} -e "CREATE DATABASE phpmyadmin DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; \
            mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} -e "GRANT ALL ON phpmyadmin.* TO '${BUILD_PHPMYADMIN_USER}'@'localhost' IDENTIFIED BY '${BUILD_PHPMYADMIN_PW}';"; \
            /usr/sbin/a2enconf phpmyadmin.conf; \
            mv /tmp/phpmyadmin.config.inc.php /usr/share/phpmyadmin/config.inc.php; \
            sed -i "s|\['controlhost'\] = '';|\['controlhost'\] = '${BUILD_MYSQL_HOST}';|" /usr/share/phpmyadmin/config.inc.php; \
            sed -i "s|\['controluser'\] = '';|\['controluser'\] = '${BUILD_PHPMYADMIN_USER}';|" /usr/share/phpmyadmin/config.inc.php; \
            sed -i "s|\['controlpass'\] = '';|\['controlpass'\] = '${BUILD_PHPMYADMIN_PW}';|" /usr/share/phpmyadmin/config.inc.php; \
            mkdir -p /var/lib/phpmyadmin/tmp; \
            chown www-data:www-data /var/lib/phpmyadmin/tmp; \
            service apache2 restart; \
            service apache2 reload; \
        else \
            printf "\e[31m'BUILD_PHPMYADMIN' = 'yes', but 'BUILD_MYSQL_HOST' is not 'localhost' ('%s')\e[0m" "${BUILD_MYSQL_HOST}"; \
            printf "\e[31mCan't currently install phpMyAdmin with a remote server connection. Sorry!\e[0m"; \
        fi; \
    fi; \
    service apache2 restart; \
# --- 19 Install RoundCube Webmail
    mkdir "$BUILD_ROUNDCUBE_DIR"; \
    wget "https://github.com/roundcube/roundcubemail/releases/download/${BUILD_ROUNDCUBE_VERSION}/roundcubemail-${BUILD_ROUNDCUBE_VERSION}-complete.tar.gz" -q -P /tmp; \
    tar xfz "/tmp/roundcubemail-${BUILD_ROUNDCUBE_VERSION}-complete.tar.gz" --strip-components=1 -C "$BUILD_ROUNDCUBE_DIR"; \
    chown -R www-data:www-data "$BUILD_ROUNDCUBE_DIR"; \
    if [ ${BUILD_MYSQL_HOST} = "localhost" ]; then \
        service mariadb restart; \
        BUILD_MYSQL_REMOTE_ACCESS_HOST="localhost"; \
    fi; \
    if ! printf "USE %s;" "${BUILD_ROUNDCUBE_DB}" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}" 2> /dev/null; then \
        printf "CREATE DATABASE %s;" "${BUILD_ROUNDCUBE_DB}" | mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW}; \
        mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} ${BUILD_ROUNDCUBE_DB} < $BUILD_ROUNDCUBE_DIR/SQL/mysql.initial.sql; \
    fi; \
    mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} -e "\
        GRANT ALL PRIVILEGES ON ${BUILD_ROUNDCUBE_DB}.* TO ${BUILD_ROUNDCUBE_USER}@'${BUILD_MYSQL_REMOTE_ACCESS_HOST}' IDENTIFIED BY '${BUILD_ROUNDCUBE_PW}'; \
        FLUSH PRIVILEGES;"; \
	mv "$BUILD_ROUNDCUBE_DIR/config/config.inc.php.sample" "$BUILD_ROUNDCUBE_DIR/config/config.inc.php"; \
    sed -i "s|mysql://roundcube:pass@localhost/roundcubemail|mysql://${BUILD_ROUNDCUBE_USER}:${BUILD_ROUNDCUBE_PW}@${BUILD_MYSQL_HOST}/${BUILD_ROUNDCUBE_DB}|" $BUILD_ROUNDCUBE_DIR/config/config.inc.php; \
    sed -i "s|\$config\['default_host'\] = '';|\$config\['default_host'\] = 'localhost';|" $BUILD_ROUNDCUBE_DIR/config/config.inc.php; \
    sed -i "s|\$config\['smtp_server'\] = '';|\$config\['smtp_server'\] = 'localhost';|" $BUILD_ROUNDCUBE_DIR/config/config.inc.php; \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    find "${BUILD_ROUNDCUBE_DIR}" -name ".htaccess" -exec sed -i "s|mod_php5|mod_php7|" {} \; && \
    find "${BUILD_ROUNDCUBE_DIR}" -name ".htaccess" -exec sed -i "s|# php_value    error_log|php_value   date.timezone ${BUILD_TZ}\nphp_value   error_log|" {} \;
COPY ./build/etc/apache2/roundcube.conf /etc/apache2/conf-enabled/roundcube.conf

# --- 19 Install ispconfig plugins for roundcube
WORKDIR /tmp
RUN git clone https://github.com/w2c/ispconfig3_roundcube.git 2>&1; \
    mv /tmp/ispconfig3_roundcube/ispconfig3_* ${BUILD_ROUNDCUBE_DIR}/plugins; \
	rm -Rf /tmp/ispconfig3_roundcube; \
    printf "\n\$config['plugins'] = array_merge(\$config['plugins'], array(\"jqueryui\", \"ispconfig3_account\", \"ispconfig3_autoreply\", \"ispconfig3_pass\", \"ispconfig3_spam\", \"ispconfig3_fetchmail\", \"ispconfig3_filter\"));\n" >> ${BUILD_ROUNDCUBE_DIR}/config/config.inc.php; \
	mv ${BUILD_ROUNDCUBE_DIR}/plugins/ispconfig3_account/config/config.inc.php.dist ${BUILD_ROUNDCUBE_DIR}/plugins/ispconfig3_account/config/config.inc.php; \
	chown www-data:www-data ${BUILD_ROUNDCUBE_DIR}/plugins/ispconfig3_account/config/config.inc.php; \
    chown -R www-data:www-data ${BUILD_ROUNDCUBE_DIR}/plugins/ispconfig3_*; \
# --- 20 Install ISPConfig 3
	wget "https://ispconfig.org/downloads/ISPConfig-${BUILD_ISPCONFIG_VERSION}.tar.gz" -q; \
	tar xfz ISPConfig-${BUILD_ISPCONFIG_VERSION}.tar.gz
COPY ./build/autoinstall.ini /tmp/ispconfig3_install/install/autoinstall.ini
# hadolint ignore=SC2086
RUN touch "/etc/mailname"; \
    sed -i "s|mysql_hostname=localhost|mysql_hostname=${BUILD_MYSQL_HOST}|" "/tmp/ispconfig3_install/install/autoinstall.ini"; \
    sed -i "s/^ispconfig_port=8080$/ispconfig_port=${BUILD_ISPCONFIG_PORT}/g" "/tmp/ispconfig3_install/install/autoinstall.ini"; \
    sed -i "s|mysql_root_password=pass|mysql_root_password=${BUILD_MYSQL_PW}|" "/tmp/ispconfig3_install/install/autoinstall.ini"; \
    sed -i "s|mysql_database=dbispconfig|mysql_database=${BUILD_ISPCONFIG_MYSQL_DATABASE}|" "/tmp/ispconfig3_install/install/autoinstall.ini"; \
    sed -i "s/^hostname=server1.example.com$/hostname=${BUILD_HOSTNAME}/g" "/tmp/ispconfig3_install/install/autoinstall.ini"; \
    sed -i "s/^ssl_cert_common_name=server1.example.com$/ssl_cert_common_name=${BUILD_HOSTNAME}/g" "/tmp/ispconfig3_install/install/autoinstall.ini"; \
    sed -i "s/^ispconfig_use_ssl=y$/ispconfig_use_ssl=$(printf "%s" ${BUILD_ISPCONFIG_USE_SSL} | cut -c1)/g" "/tmp/ispconfig3_install/install/autoinstall.ini"; \
    if [ ${BUILD_MYSQL_HOST} = "localhost" ]; then service mariadb restart; fi; \
    if printf "USE %s;" "${BUILD_ISPCONFIG_MYSQL_DATABASE}" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}" 2> /dev/null; then \
        if [ ${BUILD_ISPCONFIG_DROP_EXISTING} = "yes" ]; then \
            printf "DROP DATABASE %s;" "${BUILD_ISPCONFIG_MYSQL_DATABASE}" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}"; \
        else \
            printf "\e[31mERROR: ISPConfig database '%s' already exists and build argument 'BUILD_ISPCONFIG_DROP_EXISTING' = 'no'. Move the existing database aside before continuing\e[0m" "${BUILD_ISPCONFIG_MYSQL_DATABASE}"; \
	exit 1; \
        fi; \
    fi; \
    USER_EXISTS=$(mysql --skip-column-names -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} --execute "SELECT EXISTS(SELECT * FROM user WHERE User = '${BUILD_ISPCONFIG_MYSQL_USER}')" || true); \
    if [ $USER_EXISTS = 1 ]; then \
        if [ ${BUILD_ISPCONFIG_DROP_EXISTING} = "yes" ]; then \
            printf "DELETE FROM user WHERE User = \"%s\"; FLUSH PRIVILEGES;" "${BUILD_ISPCONFIG_MYSQL_USER}" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}"; \
        else \
            printf "\e[31mERROR: ISPConfig user '%s' already exists and build argument 'BUILD_ISPCONFIG_DROP_EXISTING' = 'no'. Move the existing user aside before continuing\e[0m" "${BUILD_ISPCONFIG_MYSQL_USER}"; \
	exit 1; \
        fi; \
    fi; \
    php -q "/tmp/ispconfig3_install/install/install.php" --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini; \
    if [ ${BUILD_MYSQL_HOST} != "localhost" ]; then \
        ISP_ADMIN_PASS=$(grep "\$conf\['db_password'\] = '\(.*\)'" "/usr/local/ispconfig/interface/lib/config.inc.php" | sed "s|\$conf\['db_password'\] = '\(.*\)';|\1|"); \
        mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}" \
      -e "GRANT ALL PRIVILEGES ON dbispconfig.* TO 'ispconfig'@'${BUILD_MYSQL_REMOTE_ACCESS_HOST}' IDENTIFIED BY '$ISP_ADMIN_PASS';"; \
    fi; \
    sed -i "s|NameVirtualHost|#NameVirtualHost|" "/etc/apache2/sites-enabled/000-ispconfig.conf"; \
    sed -i "s|NameVirtualHost|#NameVirtualHost|" "/etc/apache2/sites-enabled/000-ispconfig.vhost"; \
################################################################################################
# the key and cert for pure-ftpd should be available :
    if [ -f "/usr/local/ispconfig/interface/ssl/ispserver.key" ] && [ -f "/usr/local/ispconfig/interface/ssl/ispserver.crt" ]; then \
        mkdir -p "/etc/ssl/private/"; \
        cat "/usr/local/ispconfig/interface/ssl/ispserver.key" "/usr/local/ispconfig/interface/ssl/ispserver.crt" > "/usr/local/ispconfig/interface/ssl/ispserver.chain" || exit; \
        ln -sf "/usr/local/ispconfig/interface/ssl/ispserver.chain" "/etc/ssl/private/pure-ftpd.pem"; \
        printf "1\n" > "/etc/pure-ftpd/conf/TLS"; \
    fi; \
# --- 23 Install printing stuff
    if [ $BUILD_PRINTING = "yes" ]; then \
        apt-get -qq -o Dpkg::Use-Pty=0 update; \
        apt-get -qq -o Dpkg::Use-Pty=0 --no-install-recommends install --fix-missing -y libdmtx-utils dblatex latex-make cups-client lpr; \
        apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi; \
#
# docker-extensions
#
    mkdir -p /usr/local/bin
COPY ./build/bin/* /usr/local/bin/
RUN chmod a+x /usr/local/bin/*

#
# establish supervisord
#
COPY ./build/supervisor /etc/supervisor
COPY ./build/etc/init.d /etc/init.d

# link old /etc/init.d/ startup scripts to supervisor
RUN ln -sf /etc/supervisor/systemctl /bin/systemctl; \
    chmod a+x /etc/supervisor/* /etc/supervisor/*.d/*
COPY ./build/supervisor/invoke-rc.d /usr/sbin/invoke-rc.d
#
# create directory for service volume
#
RUN mkdir -p /service ; chmod a+rwx /service
COPY ./build/track.gitignore /.gitignore

#
# Create bootstrap archives
#
RUN cp -v /etc/passwd /etc/passwd.bootstrap; \
    cp -v /etc/shadow /etc/shadow.bootstrap; \
    cp -v /etc/group  /etc/group.bootstrap; \
    mkdir -p /bootstrap; \
    mkdir -p /var/vmail; \
    tar -C /var/vmail -czf /bootstrap/vmail.tgz .; \
    tar -C /var/www -czf /bootstrap/www.tgz  .
ENV TERM xterm

RUN printf "export TERM=xterm\n" >> /root/.bashrc; \
#
# Tidy up
    apt-get update; \
    apt-get upgrade -y; \
    apt-get autoremove; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /tmp/*

EXPOSE 20 21 22 53/udp 53/tcp 80 443 953 8080 30000 30001 30002 30003 30004 30005 30006 30007 30008 30009 3306

HEALTHCHECK --start-period=2m --timeout=3s --retries=1 \
  CMD sh -c '! supervisorctl status all | grep -E "STARTING|FATAL"'

#
# startup script
#
COPY ./build/start.sh /start.sh
RUN chmod 755 /start.sh
CMD ["/start.sh"]
