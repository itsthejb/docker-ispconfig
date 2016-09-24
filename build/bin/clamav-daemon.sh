#!/bin/bash

mkdir -p /var/run/clamav/ && chown clamav:clamav /var/run/clamav
mkdir -p /var/lib/clamav/
chown -R clamav:clamav /var/lib/clamav/

/usr/sbin/clamd -c /etc/clamav/clamd.conf

