# ispconfig-docker
Attempt to dockerize ispconfig 

## Preface
ISPConfig is a great framework!

Changes in the ispconfig panel will be stored in a mysql database and the config files for the appropriate services (postfix, dovecot, ...) will be written. Clean, simple and clear. But this architecture do not really fit to the docker concept.
  * multipe daemons
  * config will be done in/etc/ /var/log/ispconfig /etc/oasswd /etc/group /usr/local/ispconfig.

## History/Todo's
  * Initially Dockerfile from jerob : https://github.com/jerob/docker-ispconfig - thanks for the excellent work.
  * Start new repro: ispconfig-docker (cleanups for my purposes). 
  * Implement build/login/start/stop management with docker-compose
  * Wrapper script [./do] to build image, manage container and control ispconfig.
  * modified supervisord (proper shutdown, supervisorctl, linking /etc/init.d/<services>, proxy scripts for postfix
  * enable/disable ispconfig services
  * tracking possibility of ispconfig file modifications (./do track)
  * install config files on every start up (certs, ssh-keys, main.cf, ..) from a service share (./do ovw) 
  * configure ispconfig from host: set server_name, passwords ... (./do config)
  * volumes (keep /etc, /usr, /var/lib/mysql,.. in the container)
  * migration (./do migrate)
  * bootstrap directories only if the target is a emptydir. remove /etc/bootsp...
  * cleanup supervisord start scripts
  * TBD: docu for ovw:  examples: certs, disabe/enable services

## Requirements
 * docker-engine version >= 1.10.0 
 * user with sudo access
 * user belongs to "docker" group

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
./do up
./do log
```

## Post install configuration:
```
./do track init                                     # initialize tracking for  /etc and /usr/local/ispconfig
./do config mysql_root_pw  test                     # change mysql root password to test
./do config panal_admin_pw  test                    # set panel admin password to test
./do config server_name  hname.test.com             # set server name in ispconfig database
./do restart                                        # restart ispconfig
./do log                                            # show start up console
./do track show                                     # show ispconfig file modifications
```
### Test installation
```
FQDN=127.0.0.1
firefox https://${FQDN}:8080 &
firefox https://${FQDN}:8080/phpmyadmin &
firefox https://${FQDN}:8080/webmail &
```
## Recreate a customized ispconfig
 This is needed afer modification in the RUN section in docker-compose.yml.

```
./do migrate export                                 # export configuration to ./volumes/service/mig/
find ./volumes/service/mig                          # check
./do stop                                           # stop ispconfig
./do rm                                             # remove the container
./do up                                             # create a new container
./do log                                            # show start up console
./do migrate import                                 # import configuration from ./volumes/service/mig/
./do restart                                        # restart ispconfig
./do log                                            # show start up console
./do syslog
./do maillog
```
## Create a new image
 This is needed after changes in the BUILD section in docker-compose.yml. or for updates.
 
```
./do migrate export                                 # export configuration to ./volumes/service/mig/
./do stop                                           # stop ispconfig
./do rm                                             # remove the container
git pull                                            # update ispconfig-docker
diff docker-compose.yml-template docker-compose.yml # check for new options docker-compose.yml
./do build
./do up                                             # create a new container
./do log                                            # show start up console
./do migrate import                                 # import configuration from ./volume/service/mig/
./do restart                                        # restart ispconfig
./do log                                            # show start up console
```

## useful commands (examples):

```
./do                                                # help
./do start|stop|restart                             # start/stop the container
./do console                                        # attach to the console
./do supervisor                                     # attach to supervisord to start/stop/restart daemons in the container
./do login bash                                     # login and run commands in the container
./do login freshclam
./do login postqueue -p
./do login /usr/local/ispconfig/server/server.sh
./do login /usr/local/ispconfig/server/cron_daily.sh
./do login mysql_upgrade
```

