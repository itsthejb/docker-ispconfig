
**Archived!** I've now moved to [Proxmox](https://www.proxmox.com/en/), meaning I'm using ISPConfig in a VM with a standard install. This now makes this project redundant

---

# ispconfig-docker

This is a fork of [Unimock](https://github.com/unimock)'s excellent work on implementing a containerized version of the [ISPConfig](https://www.ispconfig.org) web-hosting suite.

## Caveats

* This project is suitable for single-site usage, only! Chiefly, this is because of the lack of support for the [quota tool](https://git.ispconfig.org/ispconfig/ispconfig3/issues/2986)
* Installation requires considerable user input, and is not recommended for anyone not comfortable with Linux
* _Getting this running will probably be challenging! However, once up and running it functions excellently_
* **_This project is unsupported!_**
  * That said, contributions towards making this project more user-friendly are welcomed! [Issues](https://github.com/itsthejb/ispconfig-docker/issues), [Pull Requests](https://github.com/itsthejb/ispconfig-docker/pulls)
  * Improvements to this document are particularly welcomed!

## Changes from the base project

* Updated to Debian 11 (Bullseye)
* Support for a non-local MYSQL server
* Out-of-the-box support for a custom SSL certificate
* Integration tests running on [Docker Cloud](https://cloud.docker.com/repository/docker/itsthejb/ispconfig-docker)
* More build options, such as optional install of PHPMyAdmin
* Some improvements to email security
* Extra Apache options such as enabling modules and including supplementary vhosts
* (Hopefully) numerous bug fixes and tweaks
* This version currently makes no changes to Unimock's helper [`do`](./old/do) script. In this version it's currently out-of-use; this may change in the future however!

## How to install (rough guide)

* Fork this repository
* Customize the build options in your [`docker-compose.yml`](https://github.com/itsthejb/docker-ispconfig/blob/master/docker-compose.yml)
* Or, rename the file to something like `docker-compose.build.yml`, and then create a separate `docker-compose.yml`, using the `extends` functionality to create your configuration:

```yaml
version: '3.9'

services:

  ispconfig:
    extends:
      file: docker-compose.build.yml
      service: ispconfig
    build:
      args:
        BUILD_CERTBOT: "no"
        BUILD_HOSTNAME: "ispconfig"
        BUILD_ISPCONFIG_USE_SSL: "no"
        ... etc
```

* Run the build
  * `docker compose build .`
  * If using `extends`: `docker compose -f docker-compose.build.yml build`
* Start the container: `docker compose up -d`
* Initally test the build by connecting to the ispconfig control panel: `http://<localhost>:8080`
* Do addition verification!
* Ideally, push your image to Docker Cloud
* Mount persistant volumes and judiciously copy configuration files from the container (see below)

## Persistent data

* Unlike Unimock's original, I've taken a more standard approach based around normal volume mounting. With some careful and judicious use of mounts, you can hopefully get a simpler setup. Here is an example of my full list of mounts:

```yaml
volumes:
  - /docker/appdata/ispconfig/etc:/etc
  - /docker/appdata/ispconfig/ftp:/var/ftp
  - /docker/appdata/ispconfig/lib:/var/lib
  - /docker/appdata/ispconfig/log:/var/log
  - /docker/appdata/ispconfig/log/roundcube:/opt/roundcube/logs
  - /docker/appdata/ispconfig/mail:/var/mail
  - /docker/appdata/ispconfig/spool:/var/spool
  - /docker/appdata/ispconfig/supplementary:/etc/apache2/supplementary:ro
  - /docker/appdata/ispconfig/vmail:/var/vmail
  - /docker/appdata/ispconfig/www:/var/www
  # Roundcube
  - /docker/appdata/ispconfig/roundcube/config.inc.php:/opt/roundcube/config/config.inc.php
  - /docker/appdata/ispconfig/roundcube/plugins:/opt/roundcube/plugins
  # Overlays
  - /docker/services/ISPConfig/build/supervisor:/etc/supervisor
  - /docker/appdata/ispconfig/config/database.config.inc.php:/usr/local/ispconfig/server/lib/mysql_clientdb.conf
  - /docker/appdata/ispconfig/config/interface.config.inc.php:/usr/local/ispconfig/interface/lib/config.inc.php
  - /docker/appdata/ispconfig/config/server.config.inc.php:/usr/local/ispconfig/server/lib/config.inc.php
  # System
  - /etc/letsencrypt:/etc/letsencrypt:ro
  - /etc/localtime:/etc/localtime:ro
```

## Build Options

### The following are particular important for your customization

| Argument                         | Default           | Comments |
|----------------------------------|-------------------|----------|
| `BUILD_HOSTNAME`                 | `myhost.test.com` | The hostname to use for the build, including ISPConfig
| `BUILD_ISPCONFIG_USE_SSL`        | `yes`             | Should ISPConfig use SSL? Note: this will be a self-signed certificate. See Reverse Proxy section
| `BUILD_PHPMYADMIN`               | `yes`             | Include PHPMyAdmin
| `BUILD_CERTBOT`                  | `yes`             | Include/exclude [Let's Encrypt](https://letsencrypt.org/)
| `BUILD_REDIS` | `yes` | Install Redis? Required for Rspamd, but can be configured to another host with `REDIS_HOST` environmental variable
| `BUILD_TZ`                       | `Europe/London`   | Timezone for the container
| `BUILD_LOCALE` | `en_GB` | POSIX (ISO 15897) locale code for the container. UTF-8 is required and will automatically be appended

### Less-essential options

| Argument                         | Default           | Comments |
|----------------------------------|-------------------|----------|
| `BUILD_ROUNDCUBE_DB`             | `roundcube`       | Roundcube database name
| `BUILD_ROUNDCUBE_USER`           | `roundcube`       | Roundcube database username
| `BUILD_ROUNDCUBE_PW`             | `secretpassword`  | Roundcube database password
| `BUILD_PHPMYADMIN_USER`          | `phpmyadmin`      | PHPMyAdmin database username
| `BUILD_PHPMYADMIN_PW`            | `phpmyadmin`      | PHPMyAdmin database password
| `BUILD_PHPMYADMIN_VERSION` | `4.9.0.1` | Version of PHPMyAdmin to install
| `BUILD_MYSQL_PW`                 | `pass`            | Root password for MariaDB local server, if installed
| `BUILD_ISPCONFIG_MYSQL_DATABASE` | `dbispconfig`     | ISPConfig database name
| `BUILD_ISPCONFIG_PORT`           | `8080`            | ISPConfig web app port number (control panel, PHPMyAdmin, Roundcube)

### Using a remote SQL server

It is possible to connect to a remote SQL server during the build. This would require using the compose file [extra_hosts](https://docs.docker.com/compose/compose-file/#extra_hosts) option. However, this is problematic; in particular ISPConfig expects its database not to exist at installation. For myself, I followed the following manual strategy:

* Build the container with the Mariadb server
  * `BUILD_MYSQL_HOST="localhost"`
* Dump databases and users from the container
* Import into shared SQL server
* Use the `MYSQL_HOST` environmental var to repoint the container to your shared server at runtime
* Disable the container's MariaDB server using the `DISABLED_SERVICES` environmental variable

| Argument                         | Default           | Comments |
|----------------------------------|-------------------|----------|
| `BUILD_MYSQL_HOST`               | `localhost`       | Hostname of the SQL server. When `localhost`, this will build MariaDB Server
| `BUILD_MYSQL_REMOTE_ACCESS_HOST` | `172.%.%.%`       | When `BUILD_MYSQL_HOST` != `localhost`, this will configure database users to allow connections from this host pattern.
| `BUILD_ISPCONFIG_DROP_EXISTING`  | `no`              | **DANGER**: If existing ISPConfig tables are found in the database, they will be dropped before installation! Without this, the installation fails. _Of course data will be lost!_

### Options not recommended for individual customization

| Argument                         | Default           | Comments |
|----------------------------------|-------------------|----------|
| `BUILD_ISPCONFIG_VERSION`        | [Dockerfile](https://github.com/itsthejb/ispconfig-docker/blob/master/Dockerfile#L28)      | Version of ISPConfig to install
| `BUILD_ROUNDCUBE_VERSION`                | [Dockerfile](https://github.com/itsthejb/ispconfig-docker/blob/master/Dockerfile#L40)           | Version of [Roundcube to install](https://roundcube.net/download/)
| `BUILD_ROUNDCUBE_DIR`            | `/opt/roundcube`  | Path where Roundcube will be installed. **Don't change!**

### Currently non-functional

| Argument                         | Default           | Comments |
|----------------------------------|-------------------|----------|
| `BUILD_PRINTING`                 | `no`              | Install print support

## Environmental Variables (runtime options)

| Argument                         | Default / Example           | Comments |
|----------------------------------|-------------------|----------|
| `SSL_CERT` | _none_ | Path to a custom SSL certificate (must be mounted to the container)
| `SSL_CHAIN` | _none_ | Path to a custom SSL certificate chain (must be mounted to the container)
| `SSL_KEY` | _none_ | Path to a custom SSL private key (must be mounted to the container)
| `APACHE_SUPPLEMENTARY_VHOSTS` | `/etc/apache2/supplementary/*.vhost` | Adds an `include` statement to the Apache config to add supplementary [vhosts](https://httpd.apache.org/docs/2.4/vhosts/examples.html)
| `APACHE_ENABLE_MODS` | `macro,proxy_balancer,proxy_http` | Apache standard modules to enable. Note this won't _install_ any non-standard mods
| `MYSQL_HOST` | `host` | Reconfigure services to point to this SQL server
| `HOSTNAME` | `myhost.test.com` | Runtime hostname
| `HOSTNAME_EMAIL` | `mail.myhost.test.com` | Runtime hostname for email
| `DISABLED_SERVICES` | `unbound` | Space-separated list of installed services to disable at runtime. Complete list in the [Dockerfile](./Dockerfile)
| `POSTGREY_DELAY` | `300` | [Postgrey delay time](https://wiki.centos.org/HowTos/postgrey)
| `POSTGREY_MAX_AGE` | `35` | [Postgrey maximum age](https://wiki.centos.org/HowTos/postgrey)
| `POSTGREY_TEXT` | `"Delayed by postgrey"` | [Postgrey delay message](https://wiki.centos.org/HowTos/postgrey)
| `REDIS_HOST` | `localhost` | Hostname for Redis. If `localhost`, requires `BUILD_REDIS = "yes"`
| `APACHE_DISABLE_DEFAULT_SITE` | `no` | If `yes`, disables Apache's default site

### Non-functional

| Argument                         | Default           | Comments |
|----------------------------------|-------------------|----------|
| `MAILMAN_EMAIL_HOST` | `test.com` | [Mailman host](http://www.list.org/)
| `MAILMAN_EMAIL` | `email@test.com` | [Mailman address](http://www.list.org/)
| `MAILMAN_PASS` | `pass` | [Mailman password](http://www.list.org/)
| `LANGUAGE` | `en` | [Mailman language](http://www.list.org/)

## Recommendations

### Use installed Apache as a reverse proxy

Disable SSL for ISPConfig and use Apache as a reverse proxy to access ISPConfig and associated installed apps (Roundcube, PHPMyAdmin)

* `BUILD_ISPCONFIG_USE_SSL=no`
* `APACHE_SUPPLEMENTARY_VHOSTS=/etc/apache2/supplementary/*.vhost` (pointing to a mounted volume with the vhosts)

```apache
<Macro Subdomain $host $target>
  <VirtualHost *:443>
    ServerName $host.myhostname.blah
    ProxyPass "/" "$target"
    ProxyPassReverse "/" "$target"
  </VirtualHost>
</Macro>

Use Subdomain ispconfig https://localhost:8080/
Use Subdomain webmail http://localhost:8080/webmail/
Use Subdomain phpmyadmin http://localhost:8080/phpmyadmin/

UndefMacro Subdomain
```

---
