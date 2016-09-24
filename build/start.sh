#!/bin/bash

# DOCKERPASS=$(openssl rand -base64 32)
# echo "ROOT password : $DOCKERPASS"
# echo "root:pass"|chpasswd
# sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config


###############################################################################################
_bootstrap()
{
 if [ ! -f /etc/bootstrapped ]; then
   echo "Bootstrapping"
   cd /
   tar xfz /bootstrap.tgz
 fi
 touch /etc/bootstrapped
}
###############################################################################################
_oldvolumes()
{
  echo "#######################"
  echo "# Consolidate persistent #"
  echo "#######################"
  voldir=/volume/data
  mkdir -p $voldir ; chmod a+rwx $voldir
  if [ -d $voldir ]; then
  echo "Consolidating all state on $voldir"
  list=`cat /start-data-volumes.dat`
  for d in $list ; do
    NA=`echo $d | sed -e  's/\//-/g' -e 's/^-//g' `  # /var/lib -> var-lib 
    dest=$voldir/$NA
    if [ -e $dest ]; then
    echo "  Destination $dest exists, linking $d to it"
    rm -rf $d
    ln -s $dest $d
    elif [ -e $d ]; then
    echo "  Moving contents of $d to $dest" 
    mv $d $dest
    ln -s $dest $d
    else
    echo "  Linking $d to $dest"
    mkdir -p $dest
    ln -s $dest $d
    fi
  done
  fi
  echo "############################################"
  echo "# install inotify managed files"
  echo "############################################"
  if [ ! -d /volume/data/inotify ] ; then
    mkdir -p /volume/data/inotify
  fi 
  list=`cat /start-data-inotify.dat`
  for i in $list ; do
    NA=`echo $d | sed -e  's/\//-/g' -e 's/^-//g' `  # /var/lib -> var-lib 
    if [ ! -f /volume/data/inotify/$NA ] ; then
      cp -av $i /volume/data/inotify/$NA
    else
      cp -av /volume/data/inotify/$NA $i
    fi
  done
}
###############################################################################################
_sync_service_volume()
{
  echo "####################################"
  echo "# check and apply overwrites (ovw) #"
  echo "####################################"
  if [ ! -e  /service/ovw ] ; then
    mkdir -p /service/ovw
  fi
  if [ ! -e  /service/mig ] ; then
    mkdir -p /service/mig
  fi
  rsync -av /service/ovw/ /
}
###############################################################################################
# magic main
###############################################################################################

_bootstrap
_sync_service_volume

if [ ! -z "$DEFAULT_EMAIL_HOST" ]; then
  sed -i "s/^\(DEFAULT_EMAIL_HOST\) = .*$/\1 = '$MAILMAN_EMAIL_HOST'/g" /etc/mailman/mm_cfg.py
  newlist -q mailman $(MAILMAN_EMAIL) $(MAILMAN_PASS)
  newaliases
fi
if [ ! -z "$LANGUAGE" ]; then
  sed -i "s/^language=en$/language=$LANGUAGE/g"                  /tmp/ispconfig3_install/install/autoinstall.ini
fi
if [ ! -z "$COUNTRY" ]; then
  sed -i "s/^ssl_cert_country=AU$/ssl_cert_country=$COUNTRY/g"   /tmp/ispconfig3_install/install/autoinstall.ini
fi
if [ ! -z "$HOSTNAME" ]; then
  sed -i "s/^hostname=server1.example.com$/hostname=$HOSTNAME/g" /tmp/ispconfig3_install/install/autoinstall.ini
fi
##########################################################
# do initial stuff, which is normaly done in the system start scripts
# remove sock and pid, ...
#
# global
find /var/run/ -name "*.pid" -o -name "*.sock" | xargs -r rm -f
find /var/cache/ -name "*.pid" -o -name "*.sock" | xargs -r rm -f
# clamav
mkdir -p /var/run/clamav/ && chown clamav:clamav /var/run/clamav
mkdir -p /var/lib/clamav/
chown -R clamav:clamav /var/lib/clamav/
sed -i "s/^Foreground false/Foreground true/g"   /etc/clamav/clamd.conf
# sshd
mkdir -p /var/run/sshd
#

echo "############################################"
echo "# check for disabled services              #"
echo "############################################"

SVF=/etc/supervisor/supervisord.conf
cp $SVF-template $SVF

if [ ! -e /etc/supervisor/disabled ] ; then
  echo "$DISABLED_SERVICES" > /etc/supervisor/disabled_services
fi
list=`cat /etc/supervisor/disabled_services`
for task in $list ; do
  echo "disable : $task"
  sed  -i "/program:$task/a autostart=false"  $SVF
done

echo "############################################"
echo "# start services                           #"
echo "############################################"

trap 'kill -TERM $PID; wait $PID' TERM
/usr/bin/supervisord -c $SVF &
PID=$!
wait $PID

#############################################################
# ????
#
if [ ! -f /usr/local/ispconfig/interface/lib/config.inc.php ]; then
  php -q /tmp/ispconfig3_install/install/install.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini
  killall apache2
fi

