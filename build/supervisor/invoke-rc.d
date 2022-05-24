#!/bin/bash

while [[ $1 = -* ]]; do shift; done

"/etc/init.d/${1}" "${2}"
