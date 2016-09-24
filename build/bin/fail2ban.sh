#!/bin/bash
# call "fail2ban stop" when exiting
trap "{ echo Stopping fail2ban ; fail2ban-client stop; exit 0; }" EXIT

# start fail2ban

/usr/bin/python /usr/bin/fail2ban-server -b -s /var/run/fail2ban/fail2ban.sock

# avoid exiting

sleep infinity

