# ispconfig-docker
Attempt to dockerize ispconfig 

         !!! alpha  -  try it, but not use it !!!

## Preface
ISPConfig is a great framework!

Changes in the ispconfig panel will be stored in a mysql database and the config files of the appropriate daemons (postfix, dovecot, ...) will be written.

Clear, simple and clean.

But this architecture do not really fit to the docker concept.
  * multipe daemons
  * config will be done in/etc/ /var/log/ispconfig /etc/oasswd /etc/group /usr/local/ispconfig.

## History/Todo's
  * initially forked from jerobs repository:  https://github.com/jerob/docker-ispconfig - thanks for the excellent work.
  * implement build/run/start/stop management with docker-compose
  * create a wrapper script to control ispconfig (./do)
  * modfiy supervisord: proper shutdown, supervisorctl (./do supervisor) link /etc/init.d/<services> to suprvisor, proxy scripts for postfix, ... 
  * enable/disable ispconfig services
  * tracking possibility of ispconfig file modifications (./do track)
  * install config files on every start up (certs, ssh-keys, main.cf, ..) from a service share (./do ovw) 
  * configure ispconfig from host: set server_name, passwords ... (./do ispc config)
  * TBD: migration (./do ispc mig)
  * TBD: volumes (keep /etc, /usr, /var/lib/mysql in the container)

## Requirements
 * docker-engine version >= 1.10.0 
 * system user with sudo access
 * system user belongs to "docker" group

## Installation

```
DDIR=./ispc
git clone https://github.com/unimock/ispconfig-docker.git $DDIR
cd $DDIR
```

## Build image
Customize docker-compose.yml to your needs and create an image. 

```
cp docker-compose.yml-template docker-compose.yml
# edit
  vi docker-compose.yml
  docker-compose build
# or
  sed -i -e "s/myhost/<HOSTNAME>/g" docker-compose.yml
  sed -i -e "s/test.com/<DOMAIN>/g" docker-compose.yml
./do build
```

## Create and run a container from the image.
```
docker-compose up -d ; docker-compose logs -f   # type Ctrl-c for detach
```

## Post install configuration:
```
./do track init                                # initialize tracking for  /etc and /usr/local/ispconfig
./do ispc config mysql_root_pw pass test       # change mysql root password from pass to test
./do ispc config panal_admin_pw  test          # set panel admin password to test
./do ispc config server_name  hname.test.com   # set server name in ispconfig database
./do restart                                   # restart ispconfig
./do log                                       # show start up console
./do track show                                # show ispconfig file modifications
```
### Test installation
```
FQDN=hname.test.com
firefox https://${FQDN}:8080 &
firefox https://${FQDN}:8080/phpmyadmin &
firefox https://${FQDN}:8080/webmail &
```



## Recreate and run a container

```
TBD
```

## Manage ispconfig 

### 
```
./do                     # help
./do start|stop|restart  # start/stop the container
./do console             # attach to the console
./do supervisor          # start/stop/restart daemons in the container
```

### Other useful commands (examples)
```
./do run bash
./do run freshclam
./do run postqueue -p
./do run /usr/local/ispconfig/server/server.sh
./do run /usr/local/ispconfig/server/cron_daily.sh
./do run mysql_upgrade
```

