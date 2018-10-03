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
# https://www.howtoforge.com/tutorial/perfect-server-debian-9-stretch-apache-bind-dovecot-ispconfig-3-1/
#
FROM debian:stretch-slim

LABEL maintainer="jon.crooke@gmail.com"
LABEL description="ISPConfig 3.1 on Debian Stretch, with Roundcube mail, phpMyAdmin and more"

# All arguments
ARG BUILD_CERTBOT="yes"
ARG BUILD_HOSTNAME="myhost.test.com"
ARG BUILD_ISPCONFIG="3-stable"
ARG BUILD_ISPCONFIG_DROP_EXISTING="no"
ARG BUILD_ISPCONFIG_MYSQL_DATABASE="dbispconfig"
ARG BUILD_ISPCONFIG_PORT="8080"
ARG BUILD_MYSQL_HOST="localhost"
ARG BUILD_MYSQL_PW="pass"
ARG BUILD_MYSQL_REMOTE_ACCESS_HOST="172.%.%.%"
ARG BUILD_PHPMYADMIN="yes"
ARG BUILD_PHPMYADMIN_PW="phpmyadmin"
ARG BUILD_PHPMYADMIN_USER="phpmyadmin"
ARG BUILD_PRINTING="no"
ARG BUILD_ROUNDCUBE="1.3.7"
ARG BUILD_ROUNDCUBE_DB="roundcube"
ARG BUILD_ROUNDCUBE_DIR="/opt/roundcube"
ARG BUILD_ROUNDCUBE_PW="secretpassword"
ARG BUILD_ROUNDCUBE_USER="roundcube"
ARG BUILD_TZ="Europe/Berlin"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# --- set timezone
RUN ln -fs /usr/share/zoneinfo/${BUILD_TZ} /etc/localtime; \
    dpkg-reconfigure -f noninteractive tzdata

# --- 1 Preliminary
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install rsyslog rsyslog-relp logrotate supervisor git sendemail rsnapshot heirloom-mailx
RUN touch /var/log/cron.log
# Create the log file to be able to run tail
RUN touch /var/log/auth.log

# --- 2 Install the SSH server
RUN apt-get -y install ssh openssh-server rsync

# --- 3 Install a shell text editor
RUN apt-get -y install nano vim-nox

# --- 5 Update Your Debian Installation
ADD ./build/etc/apt/sources.list /etc/apt/sources.list
RUN apt-get -y update && apt-get -y upgrade

# --- 6 Change The Default Shell
RUN echo "dash  dash/sh boolean no" | debconf-set-selections
RUN dpkg-reconfigure dash

# --- 7 Synchronize the System Clock
RUN apt-get -y install ntp ntpdate

# --- 8 Install MySQL (optional)
RUN apt-get -y install mariadb-client 
RUN \
    if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then \
        echo "mariadb-server mariadb-server/root_password password ${BUILD_MYSQL_PW}"       | debconf-set-selections; \
        echo "mariadb-server mariadb-server/root_password_again password ${BUILD_MYSQL_PW}" | debconf-set-selections; \
        apt-get -y install mariadb-server; \
    fi
ADD ./build/etc/mysql/debian.cnf /etc/mysql
ADD ./build/etc/mysql/50-server.cnf /etc/mysql/mariadb.conf.d/
RUN \
    if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then \
        sed -i "s|password =|password = ${BUILD_MYSQL_PW}|" /etc/mysql/debian.cnf; \
        echo "mysql soft nofile 65535\nmysql hard nofile 65535\n" >> /etc/security/limits.conf; \
        mkdir -p /etc/systemd/system/mysql.service.d/; \
        echo "[Service]\nLimitNOFILE=infinity\n" >> /etc/systemd/system/mysql.service.d/limits.conf; \
    fi
RUN if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then \
        service mysql restart; \
        echo "UPDATE mysql.user SET plugin = 'mysql_native_password', Password = PASSWORD('${BUILD_MYSQL_PW}') WHERE User = 'root';" | mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW}; \
    elif ! mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW}; then \
        echo "\e[31mConnection to mysql host \"${BUILD_MYSQL_HOST}\" failed!\e[0m"; \
        exit 1; \
    fi

# --- 8 Install Postfix, Dovecot, phpMyAdmin, rkhunter, binutils
RUN apt-get -y install postfix postfix-mysql postfix-doc openssl getmail4 rkhunter binutils dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd sudo
ADD ./build/etc/postfix/master.cf /etc/postfix/master.cf

RUN service postfix restart
RUN if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then service mysql restart; fi

# --- 9 Install Amavisd-new, SpamAssassin And Clamav
RUN apt-get -y install amavisd-new spamassassin clamav clamav-daemon zoo unzip bzip2 arj nomarch lzop cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl libdbd-mysql-perl postgrey
ADD ./build/etc/clamav/clamd.conf /etc/clamav/clamd.conf
RUN freshclam
RUN service spamassassin stop
RUN systemctl disable spamassassin

# --- 10 Install Apache2, PHP5, FCGI, suExec, Pear, And mcrypt
RUN if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then service mysql restart; fi; \
    apt-get -y install apache2 apache2-doc apache2-utils libapache2-mod-php php7.0 php7.0-common php7.0-gd php7.0-mysql php7.0-imap php7.0-cli php7.0-cgi libapache2-mod-fcgid apache2-suexec-pristine php-pear php7.0-mcrypt mcrypt imagemagick libruby libapache2-mod-python php7.0-curl php7.0-intl php7.0-pspell php7.0-recode php7.0-sqlite3 php7.0-tidy php7.0-xmlrpc php7.0-xsl memcached php-memcache php-imagick php-gettext php7.0-zip php7.0-mbstring memcached libapache2-mod-passenger php7.0-soap
RUN a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi headers
ADD ./build/etc/apache2/httpoxy.conf /etc/apache2/conf-available/
RUN echo "ServerName ${BUILD_HOSTNAME}" | tee /etc/apache2/conf-available/fqdn.conf && a2enconf fqdn
RUN a2enconf httpoxy

# --- 10.1 Install phpMyAdmin (optional)
# TODO change phpmyadmin password with debconf?
ADD ./build/etc/phpmyadmin/config.inc.php /var/lib/phpmyadmin
RUN \
    if [ "${BUILD_PHPMYADMIN}" = "yes" ]; then \
        if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then \
            service mysql restart; \
            echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections; \
            echo "phpmyadmin phpmyadmin/mysql/admin-pass password ${BUILD_MYSQL_PW}" | debconf-set-selections; \
            echo "phpmyadmin phpmyadmin/db/app-user string ${BUILD_PHPMYADMIN_USER}" | debconf-set-selections; \
            echo "phpmyadmin phpmyadmin/mysql/app-pass password ${BUILD_PHPMYADMIN_PW}" | debconf-set-selections; \
            echo "phpmyadmin phpmyadmin/app-password-confirm password ${BUILD_PHPMYADMIN_PW}" | debconf-set-selections; \
            echo "phpmyadmin phpmyadmin/password-confirm password ${BUILD_PHPMYADMIN_PW}" | debconf-set-selections; \
            echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections; \
            apt-get -y install phpmyadmin; \
            mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} -e "SET PASSWORD FOR '${BUILD_PHPMYADMIN_USER}'@'localhost' = PASSWORD('${BUILD_PHPMYADMIN_PW}');"; \
            sed -i "s|['controlhost'] = '';|['controlhost'] = '${BUILD_MYSQL_HOST}';|" /var/lib/phpmyadmin/config.inc.php; \
            sed -i "s|['controluser'] = '';|['controluser'] = '${BUILD_PHPMYADMIN_USER}';|" /var/lib/phpmyadmin/config.inc.php; \
            sed -i "s|['controlpass'] = '';|['controlpass'] = '${BUILD_PHPMYADMIN_PW}';|" /var/lib/phpmyadmin/config.inc.php; \
            sed -i "s|\$dbuser='.*';|\$dbuser='${BUILD_PHPMYADMIN_USER}';|" /etc/phpmyadmin/config-db.php; \
            sed -i "s|\$dbpass='.*';|\$dbpass='${BUILD_PHPMYADMIN_PW}';|" /etc/phpmyadmin/config-db.php; \
        else \
            echo "\e[31m'BUILD_PHPMYADMIN' = 'yes', but 'BUILD_MYSQL_HOST' is not 'localhost' ('${BUILD_MYSQL_HOST}')\e[0m"; \
            echo "\e[31mCan't currently install phpMyAdmin with a remote server connection. Sorry!\e[0m"; \
        fi; \
    fi

RUN service apache2 restart

# --- 11 Free SSL RUN mkdir /opt/certbot
RUN if [ "${BUILD_CERTBOT}" = "yes" ]; then apt-get -y install certbot; fi

# --- 12 PHP-FPM
RUN apt-get -y install php7.0-fpm
RUN a2enmod actions proxy_fcgi alias; service apache2 restart
# --- 12.2 Opcode Cache
RUN apt-get -y install php7.0-opcache php-apcu; service apache2 restart

# --- 13 Install Mailman
# Doesn't really work (yet)
RUN echo 'mailman mailman/default_server_language select en' | debconf-set-selections
RUN apt-get -y install mailman
# RUN ["/usr/lib/mailman/bin/newlist", "-q", "mailman", "mail@mail.com", "pass"]
ADD ./build/etc/aliases /etc/aliases
RUN newaliases
RUN service postfix restart
RUN ln -s /etc/mailman/apache.conf /etc/apache2/conf-enabled/mailman.conf

# --- 14 Install PureFTPd And Quota
# install package building helpers
RUN apt-get -y install pure-ftpd-common pure-ftpd-mysql quota quotatool
RUN groupadd ftpgroup
RUN useradd -g ftpgroup -d /dev/null -s /etc ftpuser
ADD ./build/etc/default/pure-ftpd-common /etc/default/pure-ftpd-common

# --- 15 Install BIND DNS Server, haveged
RUN apt-get -y install bind9 dnsutils haveged

# --- 16 Install Vlogger, Webalizer, And AWStats
RUN apt-get -y install webalizer awstats geoip-database libclass-dbi-mysql-perl libtimedate-perl
ADD ./build/etc/cron.d/awstats /etc/cron.d/

# --- 17 Install Jailkit
RUN apt-get -y install build-essential autoconf automake libtool flex bison debhelper binutils
RUN cd /tmp; wget http://olivier.sessink.nl/jailkit/jailkit-2.19.tar.gz; tar xvfz jailkit-2.19.tar.gz; cd jailkit-2.19; echo 5 > debian/compat; ./debian/rules binary; cd ..; dpkg -i jailkit_2.19-1_*.deb; rm -rf jailkit-2.19*

# --- 18 Install fail2ban
RUN apt-get -y install fail2ban
ADD ./build/etc/fail2ban/jail.local /etc/fail2ban/jail.local
ADD ./build/etc/fail2ban/filter.d/pureftpd.conf /etc/fail2ban/filter.d/pureftpd.conf
ADD ./build/etc/fail2ban/filter.d/dovecot-pop3imap.conf /etc/fail2ban/filter.d/dovecot-pop3imap.conf
RUN echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf
RUN service fail2ban restart

# --- 19 Install roundcube
RUN mkdir ${BUILD_ROUNDCUBE_DIR} && cd ${BUILD_ROUNDCUBE_DIR} && \
    wget https://github.com/roundcube/roundcubemail/releases/download/${BUILD_ROUNDCUBE}/roundcubemail-${BUILD_ROUNDCUBE}.tar.gz && \
    tar xfz roundcubemail-${BUILD_ROUNDCUBE}.tar.gz && mv roundcubemail-${BUILD_ROUNDCUBE}/* . && \
    mv roundcubemail-${BUILD_ROUNDCUBE}/.htaccess . && \
    rm roundcubemail-${BUILD_ROUNDCUBE}/.travis.yml && \
    rmdir roundcubemail-${BUILD_ROUNDCUBE} && rm roundcubemail-${BUILD_ROUNDCUBE}.tar.gz && \
    chown -R www-data:www-data ${BUILD_ROUNDCUBE_DIR}
RUN \
    if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then \
        service mysql restart; \
        BUILD_MYSQL_REMOTE_ACCESS_HOST="localhost"; \
    fi; \
    if ! echo "USE ${BUILD_ROUNDCUBE_DB};" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}" 2> /dev/null; then \
        echo "CREATE DATABASE ${BUILD_ROUNDCUBE_DB};" | mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW}; \
        mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} ${BUILD_ROUNDCUBE_DB} < ${BUILD_ROUNDCUBE_DIR}/SQL/mysql.initial.sql; \
    fi; \
    mysql -h ${BUILD_MYSQL_HOST} -uroot -p${BUILD_MYSQL_PW} -e "\
    GRANT ALL PRIVILEGES ON ${BUILD_ROUNDCUBE_DB}.* TO ${BUILD_ROUNDCUBE_USER}@'${BUILD_MYSQL_REMOTE_ACCESS_HOST}' IDENTIFIED BY '${BUILD_ROUNDCUBE_PW}'; \
    FLUSH PRIVILEGES;"
RUN cd ${BUILD_ROUNDCUBE_DIR}/config && cp -pf config.inc.php.sample config.inc.php
RUN sed -i "s|mysql://roundcube:pass@localhost/roundcubemail|mysql://${BUILD_ROUNDCUBE_USER}:${BUILD_ROUNDCUBE_PW}@${BUILD_MYSQL_HOST}/${BUILD_ROUNDCUBE_DB}|" ${BUILD_ROUNDCUBE_DIR}/config/config.inc.php
RUN sed -i "s|\$config\['default_host'\] = '';|\$config\['default_host'\] = 'localhost';|" ${BUILD_ROUNDCUBE_DIR}/config/config.inc.php
RUN sed -i "s|\$config\['smtp_server'\] = '';|\$config\['smtp_server'\] = 'localhost';|" ${BUILD_ROUNDCUBE_DIR}/config/config.inc.php
ADD ./build/etc/apache2/roundcube.conf /etc/apache2/conf-enabled/roundcube.conf

# --- 19 Install ispconfig plugins for roundcube
RUN git clone https://github.com/w2c/ispconfig3_roundcube.git /tmp/ispconfig3_roundcube/ && mv /tmp/ispconfig3_roundcube/ispconfig3_* ${BUILD_ROUNDCUBE_DIR}/plugins && rm -Rvf /tmp/ispconfig3_roundcube
RUN echo "\$rcmail_config['plugins'] = array(\"jqueryui\", \"ispconfig3_account\", \"ispconfig3_autoreply\", \"ispconfig3_pass\", \"ispconfig3_spam\", \"ispconfig3_fetchmail\", \"ispconfig3_filter\");" >> ${BUILD_ROUNDCUBE_DIR}/config.inc.php
RUN cd ${BUILD_ROUNDCUBE_DIR}/plugins && mv ispconfig3_account/config/config.inc.php.dist ispconfig3_account/config/config.inc.php

# --- 20 Install ISPConfig 3
RUN cd /tmp && cd . && wget https://ispconfig.org/downloads/ISPConfig-${BUILD_ISPCONFIG}.tar.gz
RUN cd /tmp && tar xfz ISPConfig-${BUILD_ISPCONFIG}.tar.gz
ADD ./build/autoinstall.ini /tmp/ispconfig3_install/install/autoinstall.ini
RUN \
    sed -i "s|mysql_hostname=localhost|mysql_hostname=${BUILD_MYSQL_HOST}|" /tmp/ispconfig3_install/install/autoinstall.ini && \
    sed -i "s/^ispconfig_port=8080$/ispconfig_port=${BUILD_ISPCONFIG_PORT}/g" /tmp/ispconfig3_install/install/autoinstall.ini && \
    sed -i "s|mysql_root_password=pass|mysql_root_password=${BUILD_MYSQL_PW}|" /tmp/ispconfig3_install/install/autoinstall.ini && \
    sed -i "s|mysql_database=dbispconfig|mysql_database=${BUILD_ISPCONFIG_MYSQL_DATABASE}|" /tmp/ispconfig3_install/install/autoinstall.ini && \
    sed -i "s/^hostname=server1.example.com$/hostname=localhost/g" /tmp/ispconfig3_install/install/autoinstall.ini && \
    sed -i "s/^ssl_cert_common_name=server1.example.com$/ssl_cert_common_name=${BUILD_HOSTNAME}/g" /tmp/ispconfig3_install/install/autoinstall.ini
RUN \
    if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then service mysql restart; fi; \
    if echo "USE ${BUILD_ISPCONFIG_MYSQL_DATABASE};" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}" 2> /dev/null; then \
        if [ "${BUILD_ISPCONFIG_DROP_EXISTING}" = "yes" ]; then \
            echo "DROP DATABASE ${BUILD_ISPCONFIG_MYSQL_DATABASE};" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}"; \
        else \
            echo "\e[31mERROR: ISPConfig database '${BUILD_ISPCONFIG_MYSQL_DATABASE}' already exists and build argument 'BUILD_ISPCONFIG_DROP_EXISTING' = 'no'. Move the existing database aside before continuing\e[0m" && exit 1; \
        fi; \
    fi; \
    if [ $(echo "SELECT EXISTS(SELECT * FROM mysql.user WHERE User = '${BUILD_ISPCONFIG_MYSQL_USER}')" | mysql --skip-column-names -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}" || true) = 1 ]; then \
        if [ "${BUILD_ISPCONFIG_DROP_EXISTING}" = "yes" ]; then \
            echo "DELETE FROM mysql.user WHERE User = \"${BUILD_ISPCONFIG_MYSQL_USER}\"; FLUSH PRIVILEGES;" | mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}"; \
        else \
            echo "\e[31mERROR: ISPConfig user '${BUILD_ISPCONFIG_MYSQL_USER}' already exists and build argument 'BUILD_ISPCONFIG_DROP_EXISTING' = 'no'. Move the existing user aside before continuing\e[0m" && exit 1; \
        fi; \
    fi
RUN if [ "${BUILD_MYSQL_HOST}" = "localhost" ]; then service mysql restart; fi; \
    php -q /tmp/ispconfig3_install/install/install.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini
RUN if [ "${BUILD_MYSQL_HOST}" != "localhost" ]; then \
    ISP_ADMIN_PASS=$(grep "\$conf\['db_password'\] = '\(.*\)'" /usr/local/ispconfig/interface/lib/config.inc.php | \
      sed "s|\$conf\['db_password'\] = '\(.*\)';|\1|"); \
    mysql -h "${BUILD_MYSQL_HOST}" -uroot -p"${BUILD_MYSQL_PW}" \
      -e "GRANT ALL PRIVILEGES ON dbispconfig.* TO 'ispconfig'@'${BUILD_MYSQL_REMOTE_ACCESS_HOST}' IDENTIFIED BY '$ISP_ADMIN_PASS';"; \
    fi
RUN sed -i "s|NameVirtualHost|#NameVirtualHost|" /etc/apache2/sites-enabled/000-ispconfig.conf
RUN sed -i "s|NameVirtualHost|#NameVirtualHost|" /etc/apache2/sites-enabled/000-ispconfig.vhost
################################################################################################
# the key and cert for pure-ftpd should be available :
RUN mkdir -p /etc/ssl/private/
RUN cd /usr/local/ispconfig/interface/ssl; cat ispserver.key ispserver.crt > ispserver.chain
RUN ln -sf /usr/local/ispconfig/interface/ssl/ispserver.chain /etc/ssl/private/pure-ftpd.pem
RUN echo 1 > /etc/pure-ftpd/conf/TLS

# --- 23 Install printing stuff
RUN if [ "$BUILD_PRINTING" = "yes" ] ; then  apt-get -y install --fix-missing  -y libdmtx-utils dblatex latex-make cups-client lpr ; fi ;

# --- DKIM key
RUN \
    mkdir -p /var/dkim; \
    DKIM_KEY="/var/dkim/${BUILD_HOSTNAME}.key.pem"; \
    amavisd-new genrsa "${DKIM_KEY}" ;\
    sed -i "s|@dkim_signature_options_bysender_maps|dkim_key('${BUILD_HOSTNAME}', '${BUILD_HOSTNAME}', '${DKIM_KEY}');\n@dkim_signature_options_bysender_maps|" /etc/amavis/conf.d/50-user; \
    echo "\e[31mGenerated DKIM key follows:\e[0m"; \
    echo "\e[31m===========================\e[0m"; \
    amavisd-new showkeys; \
    echo "\e[31m===========================\e[0m"; \
    echo "\e[31m^^^^^^^^^ DKIM KEY ^^^^^^^^\e[0m";

#
# docker-extensions
#
RUN mkdir -p /usr/local/bin
COPY ./build/bin/*             /usr/local/bin/
RUN chmod a+x /usr/local/bin/*

#
# establish supervisord
#
ADD ./build/supervisor /etc/supervisor
# link old /etc/init.d/ startup scripts to supervisor
RUN ls -m1    /etc/supervisor/services.d | while read i; do mv /etc/init.d/$i /etc/init.d/$i-orig ;  ln -sf /etc/supervisor/super-init.sh /etc/init.d/$i ; done
RUN ln -sf    /etc/supervisor/systemctl /bin/systemctl
RUN chmod a+x /etc/supervisor/* /etc/supervisor/*.d/*
COPY ./build/supervisor/invoke-rc.d /usr/sbin/invoke-rc.d
#
# create directory for service volume
#
RUN mkdir -p /service ; chmod a+rwx /service
ADD ./build/track.gitignore /.gitignore

#
# Create bootstrap archives
#
RUN cp -v /etc/passwd /etc/passwd.bootstrap
RUN cp -v /etc/shadow /etc/shadow.bootstrap
RUN cp -v /etc/group  /etc/group.bootstrap
RUN mkdir -p /bootstrap ;  tar -C /var/vmail -czf /bootstrap/vmail.tgz .
RUN mkdir -p /bootstrap ;  tar -C /var/www   -czf /bootstrap/www.tgz  .
ENV TERM xterm

RUN echo "export TERM=xterm" >> /root/.bashrc

#
# Tidy up
RUN rm -rf /tmp/*

EXPOSE 20 21 22 53/udp 53/tcp 80 443 953 8080 30000 30001 30002 30003 30004 30005 30006 30007 30008 30009 3306

#
# startup script
#
ADD ./build/start.sh /start.sh
RUN chmod 755 /start.sh
CMD ["/start.sh"]
