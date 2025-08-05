#!/bin/bash

# Ensure to kill xinetd in the container which is only relevant for the internal checkmk agent in the container
# The service does not work on debian 13
# The service creates issues on debian 12
pkill -f '/usr/sbin/xinetd'
